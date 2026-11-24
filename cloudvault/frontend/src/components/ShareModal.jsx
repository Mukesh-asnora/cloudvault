import React, { useState } from 'react';

export default function ShareModal({ file, onClose, onSubmit }) {
  const [targetUserId, setTargetUserId] = useState('');
  const [level, setLevel] = useState('VIEWER');
  const [status, setStatus] = useState('idle'); // idle | loading | success | error
  const [errorMessage, setErrorMessage] = useState('');

  if (!file) return null;

  async function handleSubmit(e) {
    e.preventDefault();
    setStatus('loading');
    setErrorMessage('');
    try {
      await onSubmit(targetUserId.trim(), level);
      setStatus('success');
      setTimeout(onClose, 1200);
    } catch (err) {
      setStatus('error');
      setErrorMessage(err.response?.data?.message || 'Could not share this file. Check the ID and try again.');
    }
  }

  return (
    <div className="cv-modal-overlay" onClick={onClose}>
      <div className="cv-modal" onClick={(e) => e.stopPropagation()}>
        <span className="cv-auth-eyebrow">Share file</span>
        <h2 className="cv-modal-title">{file.name}</h2>

        <form onSubmit={handleSubmit}>
          <label className="cv-modal-label">Recipient's share ID</label>
          <input
            className="cv-field"
            placeholder="Paste their share ID"
            value={targetUserId}
            onChange={(e) => setTargetUserId(e.target.value)}
            required
            autoFocus
          />

          <label className="cv-modal-label">Permission level</label>
          <select className="cv-field cv-select" value={level} onChange={(e) => setLevel(e.target.value)}>
            <option value="VIEWER">Viewer — can view and download</option>
            <option value="EDITOR">Editor — can view, download, and rename</option>
          </select>

          {status === 'error' && <div className="cv-error-banner">{errorMessage}</div>}
          {status === 'success' && <div className="cv-success-banner">Shared successfully.</div>}

          <div className="cv-modal-actions">
            <button type="button" className="cv-btn cv-btn-ghost" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="cv-btn cv-btn-primary" disabled={status === 'loading' || status === 'success'}>
              {status === 'loading' ? 'Sharing…' : 'Share'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}