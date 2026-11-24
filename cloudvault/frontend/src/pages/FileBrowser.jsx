import React, { useEffect, useState, useCallback } from 'react';
import axiosClient from '../api/axiosClient';
import { uploadFileInChunks } from '../api/uploadFile';
import FileList from '../components/FileList.jsx';
import UploadProgress from '../components/UploadProgress.jsx';
import ShareModal from '../components/ShareModal.jsx';
import ProfileBadge from '../components/ProfileBadge.jsx';
import { useAuth } from '../context/AuthContext.jsx';

export default function FileBrowser() {
  const [files, setFiles] = useState([]);
  const [uploads, setUploads] = useState([]);
  const [loading, setLoading] = useState(true);
  const [shareTarget, setShareTarget] = useState(null); // the file being shared, or null
  const { user, logout } = useAuth();

  const loadFiles = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await axiosClient.get('/metadata/files');
      setFiles(data);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadFiles();
  }, [loadFiles]);

  async function handleFileSelect(e) {
    const selected = Array.from(e.target.files);
    e.target.value = '';

    for (const file of selected) {
      const uploadEntryId = crypto.randomUUID();
      setUploads((prev) => [...prev, { id: uploadEntryId, fileName: file.name, percent: 0, status: 'uploading' }]);

      try {
        await uploadFileInChunks(file, null, (percent) => {
          setUploads((prev) => prev.map((u) => (u.id === uploadEntryId ? { ...u, percent } : u)));
        });
        setUploads((prev) => prev.map((u) => (u.id === uploadEntryId ? { ...u, percent: 100, status: 'done' } : u)));
        loadFiles();
      } catch (err) {
        setUploads((prev) => prev.map((u) => (u.id === uploadEntryId ? { ...u, status: 'error' } : u)));
      }
    }
  }

  async function handleDelete(file) {
    if (!confirm(`Delete "${file.name}"?`)) return;
    await axiosClient.delete(`/metadata/files/${file.id}`);
    loadFiles();
  }

  async function submitShare(targetUserId, level) {
    await axiosClient.post(`/metadata/files/${shareTarget.id}/share`, { targetUserId, level });
  }

  async function handleDownload(file) {
    try {
      const { data } = await axiosClient.get('/files/download', { params: { fileId: file.id } });
      window.open(data.url, '_blank');
    } catch (err) {
      if (err.response?.status === 403) {
        alert("You don't have access to this file.");
      } else {
        alert('Download failed: ' + (err.response?.data?.message || err.message));
      }
    }
  }
  return (
    <div className="cv-app-shell">
      <header className="cv-topbar">
        <div className="cv-brand">
          <span className="cv-brand-mark">CV</span>
          CloudVault
        </div>
        <div className="cv-user-chip">
          <ProfileBadge user={user} />
          <span>{user?.email}</span>
          <button className="cv-btn cv-btn-ghost" onClick={logout}>
            Log out
          </button>
        </div>
      </header>

      <main className="cv-main">
        <label className="cv-scanner">
          <input type="file" multiple onChange={handleFileSelect} style={{ display: 'none' }} />
          <div className="cv-scanner-label">Drop files to upload, or click to browse</div>
          <div className="cv-scanner-sub">chunked · resumable · up to 5GB per file</div>
        </label>

        {uploads.length > 0 && (
          <div style={{ marginBottom: 28 }}>
            {uploads.map((u) => (
              <UploadProgress key={u.id} fileName={u.fileName} percent={u.percent} status={u.status} />
            ))}
          </div>
        )}

        <div className="cv-section-header">
          <span className="cv-section-title">Your files</span>
          {!loading && <span className="cv-section-count">{files.length} item{files.length === 1 ? '' : 's'}</span>}
        </div>

        {loading ? (
          <div className="cv-empty-state">Loading…</div>
        ) : (
          <FileList files={files} onDelete={handleDelete} onShare={setShareTarget} onDownload={handleDownload} />
        )}
      </main>

      <ShareModal file={shareTarget} onClose={() => setShareTarget(null)} onSubmit={submitShare} />
    </div>
  );
}