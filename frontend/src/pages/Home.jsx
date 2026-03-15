import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';

export default function Home() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchProfile = async () => {
      const token = localStorage.getItem('token');

      if (!token) {
        navigate('/login');
        return;
      }

      try {
        const res = await fetch('/api/auth/profile', {
          headers: { Authorization: `Bearer ${token}` },
        });

        if (!res.ok) {
          throw new Error('Session expired');
        }

        const data = await res.json();
        setUser(data.user);
      } catch {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        navigate('/login');
      } finally {
        setLoading(false);
      }
    };

    fetchProfile();
  }, [navigate]);

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    navigate('/login');
  };

  if (loading) {
    return (
      <div className="auth-container">
        <div className="spinner" style={{ width: 40, height: 40, borderWidth: 3 }}></div>
      </div>
    );
  }

  if (!user) return null;

  const memberSince = new Date(user.createdAt).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return (
    <div className="dashboard-container">
      {/* Navigation Bar */}
      <nav className="dashboard-nav">
        <div className="nav-brand">
          <div className="nav-logo">🔐</div>
          <h2>AuthVault</h2>
        </div>
        <button className="btn-logout" onClick={handleLogout}>
          Sign Out
        </button>
      </nav>

      {/* Main Content */}
      <main className="dashboard-content">
        <section className="welcome-section">
          <span className="welcome-emoji">👋</span>
          <h1>
            Welcome, <span className="gradient-text">{user.username}</span>!
          </h1>
          <p>You're successfully authenticated. Here's your account overview.</p>
        </section>

        <div className="info-cards">
          <div className="info-card">
            <span className="info-card-icon">👤</span>
            <div className="info-card-label">Username</div>
            <div className="info-card-value">{user.username}</div>
          </div>

          <div className="info-card">
            <span className="info-card-icon">📧</span>
            <div className="info-card-label">Email</div>
            <div className="info-card-value">{user.email}</div>
          </div>

          <div className="info-card">
            <span className="info-card-icon">📅</span>
            <div className="info-card-label">Member Since</div>
            <div className="info-card-value">{memberSince}</div>
          </div>
        </div>

        <div className="status-section">
          <div className="status-badge">
            <span className="status-dot"></span>
            Authenticated & Secure
          </div>
          <p>Your session is active. Token expires in 24 hours.</p>
        </div>
      </main>
    </div>
  );
}
