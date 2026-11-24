import React, { useState, useRef, useEffect } from 'react';

export default function ProfileBadge({ user }) {
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    function handleClickOutside(e) {
      if (ref.current && !ref.current.contains(e.target)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  if (!user) return null;

  const initials = user.email ? user.email.slice(0, 2).toUpperCase() : '??';

  async function handleCopy() {
    await navigator.clipboard.writeText(user.id);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  return (
    <div className="cv-profile" ref={ref}>
      <button className="cv-avatar" onClick={() => setOpen((o) => !o)} aria-label="Your profile">
        {initials}
      </button>

      {open && (
        <div className="cv-popover">
          <div className="cv-popover-avatar">{initials}</div>
          <div className="cv-popover-email">{user.email}</div>
          <div className="cv-popover-label">Your share ID</div>
          <div className="cv-popover-id-row">
            <code className="cv-popover-id">{user.id}</code>
            <button className="cv-btn cv-btn-ghost cv-copy-btn" onClick={handleCopy}>
              {copied ? 'Copied' : 'Copy'}
            </button>
          </div>
          <p className="cv-popover-hint">
            Share this ID with anyone you want to give access to your files.
          </p>
        </div>
      )}
    </div>
  );
}