import axiosClient from './axiosClient';

const CHUNK_SIZE = 8 * 1024 * 1024; // 8MB - matches file-service's recommendation
const MAX_RETRIES_PER_CHUNK = 3;

/**
 * Splits a file into chunks and uploads them independently, retrying only
 * the chunk that failed rather than restarting the whole transfer. This is
 * the client-side half of the resumable upload design in file-service.
 *
 * onProgress(percent) is called as chunks complete so the UI can show a
 * live progress bar even for multi-GB files.
 */
export async function uploadFileInChunks(file, parentFolderId, onProgress) {
  const totalChunks = Math.ceil(file.size / CHUNK_SIZE);

  const { data: initData } = await axiosClient.post('/files/upload/init', {
    fileName: file.name,
    totalSizeBytes: file.size,
    totalChunks,
    contentType: file.type || 'application/octet-stream',
    parentFolderId: parentFolderId || null
  });

  const { uploadId } = initData;
  let completedChunks = 0;

  for (let chunkNumber = 1; chunkNumber <= totalChunks; chunkNumber++) {
    const start = (chunkNumber - 1) * CHUNK_SIZE;
    const end = Math.min(start + CHUNK_SIZE, file.size);
    const chunkBlob = file.slice(start, end);

    await uploadChunkWithRetry(uploadId, chunkNumber, chunkBlob);

    completedChunks++;
    onProgress(Math.round((completedChunks / totalChunks) * 100));
  }

  await axiosClient.post(
    `/files/upload/${uploadId}/complete`,
    null,
    {
      params: {
        fileName: file.name,
        sizeBytes: file.size,
        contentType: file.type || 'application/octet-stream',
        parentFolderId: parentFolderId || undefined
      }
    }
  );

  return uploadId;
}

async function uploadChunkWithRetry(uploadId, chunkNumber, chunkBlob, attempt = 1) {
  const formData = new FormData();
  formData.append('file', chunkBlob);

  try {
    await axiosClient.put(
      `/files/upload/${uploadId}/chunk/${chunkNumber}`,
      formData,
      { headers: { 'Content-Type': 'multipart/form-data' } }
    );
  } catch (err) {
    if (attempt >= MAX_RETRIES_PER_CHUNK) {
      throw new Error(`Chunk ${chunkNumber} failed after ${MAX_RETRIES_PER_CHUNK} attempts: ${err.message}`);
    }
    // Exponential backoff: 1s, 2s, 4s - gives a flaky connection time to recover
    // instead of hammering it immediately.
    await new Promise((r) => setTimeout(r, 2 ** (attempt - 1) * 1000));
    return uploadChunkWithRetry(uploadId, chunkNumber, chunkBlob, attempt + 1);
  }
}