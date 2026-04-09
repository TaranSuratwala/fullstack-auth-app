const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const pool = require('../config/db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
const googleClient = new OAuth2Client();

const createJwtToken = (user) => jwt.sign(
  { id: user.id, email: user.email },
  process.env.JWT_SECRET,
  { expiresIn: '24h' }
);

const formatUser = (user) => ({
  id: user.id,
  username: user.username,
  email: user.email,
  createdAt: user.created_at,
});

const baseUsername = (name, email) => {
  const fromName = String(name || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '')
    .slice(0, 24);

  if (fromName.length >= 3) {
    return fromName;
  }

  const fromEmail = String(email || '')
    .split('@')[0]
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '')
    .slice(0, 24);

  if (fromEmail.length >= 3) {
    return fromEmail;
  }

  return `user${crypto.randomInt(100000, 999999)}`;
};

const findAvailableUsername = async (seed) => {
  let attempt = 0;

  while (attempt < 20) {
    const candidate = attempt === 0 ? seed : `${seed}${attempt}`;
    const check = await pool.query('SELECT id FROM users WHERE username = $1', [candidate]);

    if (check.rows.length === 0) {
      return candidate;
    }

    attempt += 1;
  }

  return `${seed}${crypto.randomInt(1000, 9999)}`;
};

// ─── GOOGLE OAUTH CONFIG ───────────────────────────────────
// GET /api/auth/google/config
router.get('/google/config', (req, res) => {
  const clientId = process.env.GOOGLE_CLIENT_ID;

  if (!clientId) {
    return res.status(200).json({ enabled: false });
  }

  return res.status(200).json({
    enabled: true,
    clientId,
  });
});

// ─── GOOGLE OAUTH LOGIN ────────────────────────────────────
// POST /api/auth/google
router.post('/google', async (req, res) => {
  const googleClientId = process.env.GOOGLE_CLIENT_ID;
  const { credential } = req.body;

  if (!googleClientId) {
    return res.status(503).json({ message: 'Google OAuth is not configured on the server.' });
  }

  if (!credential) {
    return res.status(400).json({ message: 'Missing Google credential token.' });
  }

  let payload;

  try {
    const ticket = await googleClient.verifyIdToken({
      idToken: credential,
      audience: googleClientId,
    });
    payload = ticket.getPayload();
  } catch (err) {
    console.error('Google token verification failed:', err.message);
    return res.status(401).json({ message: 'Google authentication failed.' });
  }

  if (!payload || !payload.sub || !payload.email || !payload.email_verified) {
    return res.status(401).json({ message: 'Google account is missing verified email.' });
  }

  const googleId = payload.sub;
  const email = payload.email;
  const name = payload.name;

  try {
    const existingByGoogleId = await pool.query(
      'SELECT id, username, email, created_at, google_id FROM users WHERE google_id = $1',
      [googleId]
    );

    if (existingByGoogleId.rows.length > 0) {
      const user = existingByGoogleId.rows[0];
      return res.status(200).json({
        message: 'Google login successful.',
        token: createJwtToken(user),
        user: formatUser(user),
      });
    }

    const existingByEmail = await pool.query(
      'SELECT id, username, email, created_at, google_id FROM users WHERE email = $1',
      [email]
    );

    let user;

    if (existingByEmail.rows.length > 0) {
      user = existingByEmail.rows[0];

      if (user.google_id && user.google_id !== googleId) {
        return res.status(409).json({
          message: 'This email is already linked to another Google account.',
        });
      }

      const updated = await pool.query(
        'UPDATE users SET google_id = $1 WHERE id = $2 RETURNING id, username, email, created_at, google_id',
        [googleId, user.id]
      );
      user = updated.rows[0];
    } else {
      const usernameSeed = baseUsername(name, email);
      const username = await findAvailableUsername(usernameSeed);
      const randomPassword = crypto.randomBytes(32).toString('hex');
      const salt = await bcrypt.genSalt(12);
      const hashedPassword = await bcrypt.hash(randomPassword, salt);

      const inserted = await pool.query(
        `INSERT INTO users (username, email, password, google_id)
         VALUES ($1, $2, $3, $4)
         RETURNING id, username, email, created_at, google_id`,
        [username, email, hashedPassword, googleId]
      );
      user = inserted.rows[0];
    }

    return res.status(200).json({
      message: 'Google login successful.',
      token: createJwtToken(user),
      user: formatUser(user),
    });
  } catch (err) {
    console.error('Google login database error:', err);
    return res.status(500).json({ message: 'Internal server error.' });
  }
});

// ─── REGISTER ────────────────────────────────────────────────
// POST /api/auth/register
router.post('/register', async (req, res) => {
  const { username, email, password } = req.body;

  // Validation
  if (!username || !email || !password) {
    return res.status(400).json({ message: 'All fields are required.' });
  }

  if (password.length < 6) {
    return res.status(400).json({ message: 'Password must be at least 6 characters.' });
  }

  try {
    // Check if email already exists
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE email = $1',
      [email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({ message: 'A user with this email already exists.' });
    }

    // Check if username already exists
    const existingUsername = await pool.query(
      'SELECT id FROM users WHERE username = $1',
      [username]
    );

    if (existingUsername.rows.length > 0) {
      return res.status(409).json({ message: 'This username is already taken.' });
    }

    // Hash password
    const salt = await bcrypt.genSalt(12);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Insert user
    const result = await pool.query(
      'INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING id, username, email, created_at',
      [username, email, hashedPassword]
    );

    const user = result.rows[0];

    // Generate JWT
    const token = createJwtToken(user);

    return res.status(201).json({
      message: 'User registered successfully.',
      token,
      user: formatUser(user),
    });
  } catch (err) {
    console.error('Registration error:', err);
    return res.status(500).json({ message: 'Internal server error.' });
  }
});

// ─── LOGIN ───────────────────────────────────────────────────
// POST /api/auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  // Validation
  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required.' });
  }

  try {
    // Find user by email
    const result = await pool.query(
      'SELECT id, username, email, password, created_at FROM users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ message: 'Invalid email or password.' });
    }

    const user = result.rows[0];

    // Compare passwords
    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid email or password.' });
    }

    // Generate JWT
    const token = createJwtToken(user);

    return res.status(200).json({
      message: 'Login successful.',
      token,
      user: formatUser(user),
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ message: 'Internal server error.' });
  }
});

// ─── GET PROFILE (Protected) ────────────────────────────────
// GET /api/auth/profile
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, username, email, created_at FROM users WHERE id = $1',
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'User not found.' });
    }

    const user = result.rows[0];

    return res.status(200).json({
      user: formatUser(user),
    });
  } catch (err) {
    console.error('Profile fetch error:', err);
    return res.status(500).json({ message: 'Internal server error.' });
  }
});

module.exports = router;
