import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

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

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
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

      // Store token and user info
      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify(data.user));
      navigate('/');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

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

            <button className="btn-submit" type="submit" disabled={loading}>
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
