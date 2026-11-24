import React from 'react';

export default function FileList({ files, onDelete, onShare, onDownload }) {
  if (!files.length) {
    return <div className="cv-empty-state">No files yet — upload something above to get started.</div>;
  }

  return (
    <table className="cv-file-table">
      <thead>
        <tr>
          <th>Name</th>
          <th>Size</th>
          <th>Uploaded</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        {files.map((f) => (
          <tr key={f.id}>
            <td className="cv-file-name">
              {f.name}
              {!f.isOwner && <span className="cv-shared-badge">Shared · {f.permissionLevel}</span>}
            </td>
            <td className="cv-file-meta">{formatBytes(f.sizeBytes)}</td>
            <td className="cv-file-meta">{new Date(f.createdAt).toLocaleDateString()}</td>
            <td className="cv-file-actions">
              {!f.isFolder && (
                <button className="cv-btn cv-btn-ghost" onClick={() => onDownload(f)}>
                  Download
                </button>
              )}
              {f.isOwner && (
                <button className="cv-btn cv-btn-ghost" onClick={() => onShare(f)}>
                  Share
                </button>
              )}
              {f.isOwner && (
                <button className="cv-btn cv-btn-danger" onClick={() => onDelete(f)}>
                  Delete
                </button>
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function formatBytes(bytes) {
  if (!bytes) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${units[i]}`;
}