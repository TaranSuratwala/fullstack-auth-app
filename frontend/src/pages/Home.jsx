import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { consumeLocalSsoSignIn } from '../utils/localSso';

export default function Home() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchProfile = async () => {
      const token = localStorage.getItem('token');
      const localUserRaw = localStorage.getItem('user');
      const usedLocalSso = consumeLocalSsoSignIn();

      if (!token) {
        navigate('/login');
        return;
      }

      if (usedLocalSso && localUserRaw) {
        try {
          const localUser = JSON.parse(localUserRaw);
          if (localUser && localUser.username && localUser.email) {
            setUser(localUser);
            setLoading(false);
            return;
          }
        } catch {
          // If local user payload is malformed, fallback to normal API profile fetch.
        }
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
      <div className="loading-screen">
        <div className="spinner spinner-large"></div>
        <p>Loading your dashboard...</p>
      </div>
    );
  }

  if (!user) return null;

  const memberSince = new Date(user.createdAt).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  const accountAgeDays = Math.max(
    1,
    Math.floor((Date.now() - new Date(user.createdAt).getTime()) / (1000 * 60 * 60 * 24))
  );

  return (
    <div className="dashboard-container">
      <nav className="dashboard-nav">
        <div className="nav-brand">
          <div className="nav-logo">AS</div>
          <div>
            <p className="nav-label">Auth Suite</p>
            <h2>Dashboard</h2>
          </div>
        </div>
        <button className="btn-logout" onClick={handleLogout}>
          Log Out
        </button>
      </nav>

      <main className="dashboard-content">
        <section className="welcome-section">
          <div>
            <p className="section-kicker">Account Overview</p>
            <h1>
              Good to see you, <span className="accent-text">{user.username}</span>.
            </h1>
            <p>
              Your session is active and your protected profile route is available.
            </p>
          </div>
          <div className="status-badge">
            <span className="status-dot"></span>
            Secure session active
          </div>
        </section>

        <div className="info-cards">
          <div className="info-card">
            <div className="info-card-label">Username</div>
            <div className="info-card-value">{user.username}</div>
          </div>

          <div className="info-card">
            <div className="info-card-label">Email</div>
            <div className="info-card-value">{user.email}</div>
          </div>

          <div className="info-card">
            <div className="info-card-label">Member Since</div>
            <div className="info-card-value">{memberSince}</div>
          </div>

          <div className="info-card">
            <div className="info-card-label">Account Age</div>
            <div className="info-card-value">{accountAgeDays} days</div>
          </div>
        </div>

        <div className="status-section">
          <h3>Security checklist</h3>
          <p>Your token expires in 24 hours. Keep your account protected with these basics:</p>
          <ul className="status-list">
            <li>Use a unique password and update it regularly.</li>
            <li>Log out when using a shared device.</li>
            <li>Never share your JWT token in public channels.</li>
          </ul>
        </div>
      </main>
    </div>
  );
}
