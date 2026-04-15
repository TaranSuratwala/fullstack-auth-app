import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import GoogleSignInButton from '../components/GoogleSignInButton';
import {
  getLocalSsoSession,
  getLocalSsoTrustedPreference,
  markLocalSsoSignIn,
  saveLocalSsoSession,
  setLocalSsoTrustedPreference,
} from '../utils/localSso';

const showcasePoints = [
  'JWT protected sessions',
  'Encrypted password storage',
  'Fast profile access after login',
];

export default function Login() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [localSsoSession, setLocalSsoSession] = useState(null);
  const [trustedDevice, setTrustedDevice] = useState(getLocalSsoTrustedPreference());

  useEffect(() => {
    setLocalSsoSession(getLocalSsoSession());
  }, []);

  const completeLogin = useCallback((data, persistLocalSso) => {
    localStorage.setItem('token', data.token);
    localStorage.setItem('user', JSON.stringify(data.user));
    saveLocalSsoSession({
      token: data.token,
      user: data.user,
      persist: persistLocalSso,
    });
    navigate('/');
  }, [navigate]);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
  };

  const handleTrustedDeviceChange = (e) => {
    const checked = e.target.checked;
    setTrustedDevice(checked);
    setLocalSsoTrustedPreference(checked);
  };

  const handleLocalSsoSignIn = () => {
    setError('');

    const session = getLocalSsoSession();

    if (!session) {
      setLocalSsoSession(null);
      setError('No active local SSO session found. Sign in again to create one.');
      return;
    }

    localStorage.setItem('token', session.token);
    localStorage.setItem('user', JSON.stringify(session.user));
    markLocalSsoSignIn();
    navigate('/');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.message || 'Login failed');
      }

      completeLogin(data, trustedDevice);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleCredential = useCallback(async (credential) => {
    setError('');
    setGoogleLoading(true);

    try {
      const res = await fetch('/api/auth/google', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ credential }),
      });

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.message || 'Google sign-in failed');
      }

      completeLogin(data, trustedDevice);
    } catch (err) {
      setError(err.message);
    } finally {
      setGoogleLoading(false);
    }
  }, [completeLogin, trustedDevice]);

  return (
    <div className="auth-screen auth-screen-login">
      <aside className="auth-showcase">
        <p className="showcase-kicker">Secure Access Suite</p>
        <h1>Welcome back to your control desk.</h1>
        <p>
          Sign in to review your account profile and continue with an active,
          secure session.
        </p>
        <ul className="showcase-points">
          {showcasePoints.map((point) => (
            <li key={point}>{point}</li>
          ))}
        </ul>
      </aside>

      <section className="auth-panel">
        <div className="auth-card">
          <div className="auth-header">
            <div className="auth-logo">AS</div>
            <h2>Sign in</h2>
            <p>Use your email and password to continue.</p>
          </div>

          {localSsoSession && (
            <div className="local-sso-card">
              <p className="local-sso-title">AuthVault SSO (no API call)</p>
              <p className="local-sso-subtitle">
                Continue with your saved browser session.
              </p>
              <button
                className="btn-local-sso"
                type="button"
                onClick={handleLocalSsoSignIn}
                disabled={loading || googleLoading}
              >
                Continue as {localSsoSession.user.username}
              </button>
            </div>
          )}

          <form className="auth-form" onSubmit={handleSubmit}>
            {error && <div className="error-message">{error}</div>}

            <div className="form-group">
              <label htmlFor="email">Email Address</label>
              <input
                id="email"
                className="form-input"
                type="email"
                name="email"
                placeholder="you@example.com"
                value={formData.email}
                onChange={handleChange}
                required
                autoComplete="email"
              />
            </div>

            <div className="form-group">
              <label htmlFor="password">Password</label>
              <input
                id="password"
                className="form-input"
                type="password"
                name="password"
                placeholder="Enter your password"
                value={formData.password}
                onChange={handleChange}
                required
                autoComplete="current-password"
              />
            </div>

            <label className="trust-toggle">
              <input
                type="checkbox"
                checked={trustedDevice}
                onChange={handleTrustedDeviceChange}
              />
              <span>Keep this device trusted for Local SSO</span>
            </label>

            <button className="btn-submit" type="submit" disabled={loading || googleLoading}>
              {loading ? (
                <span className="btn-loading">
                  <span className="spinner"></span>
                  Signing in...
                </span>
              ) : (
                'Sign In'
              )}
            </button>
          </form>

          <div className="auth-divider">
            <span>or continue with</span>
          </div>

          <GoogleSignInButton
            onCredential={handleGoogleCredential}
            disabled={loading || googleLoading}
          />

          {googleLoading && <p className="oauth-note">Signing in with Google...</p>}

          <div className="auth-footer">
            <p>
              Need an account?{' '}
              <Link className="auth-link" to="/register">
                Create one
              </Link>
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
