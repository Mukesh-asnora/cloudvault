import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login(email, password);
      navigate('/');
    } catch (err) {
      setError(err.response?.data?.message || 'Invalid email or password');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="cv-auth-screen">
      <VaultRing />
      <div className="cv-auth-card">
        <span className="cv-auth-eyebrow">Secure access</span>
        <h1 className="cv-auth-title">Sign in to CloudVault</h1>
        <form onSubmit={handleSubmit}>
          <input
            className="cv-field"
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoFocus
          />
          <input
            className="cv-field"
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          {error && <div className="cv-error-banner">{error}</div>}
          <button type="submit" className="cv-btn cv-btn-primary cv-btn-block" disabled={loading}>
            {loading ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
        <p className="cv-auth-footer">
          No account? <Link to="/register">Create one</Link>
        </p>
      </div>
    </div>
  );
}

function VaultRing() {
  return (
    <svg className="cv-vault-ring" viewBox="0 0 620 620" aria-hidden="true">
      <circle cx="310" cy="310" r="180" strokeWidth="1" />
      <circle cx="310" cy="310" r="230" strokeWidth="1" />
      <circle className="ring-accent" cx="310" cy="310" r="280" strokeWidth="1.5" />
    </svg>
  );
}