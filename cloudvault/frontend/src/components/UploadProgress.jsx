import React from 'react';

export default function UploadProgress({ fileName, percent, status }) {
  const isError = status === 'error';
  return (
    <div className="cv-upload-row">
      <div className="cv-upload-row-head">
        <span className="cv-upload-name">{fileName}</span>
        <span className={`cv-upload-pct${isError ? ' error' : ''}`}>
          {isError ? 'Failed — retrying' : `${percent}%`}
        </span>
      </div>
      <div className="cv-progress-track">
        <div className={`cv-progress-fill${isError ? ' error' : ''}`} style={{ width: `${percent}%` }} />
      </div>
    </div>
  );
}