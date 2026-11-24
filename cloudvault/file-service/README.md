# file-service

Spring Boot service handling chunked upload/download and S3 (MinIO) storage.

Planned endpoints:
- POST /files/upload/init
- PUT  /files/upload/{uploadId}/chunk/{chunkNumber}
- POST /files/upload/{uploadId}/complete
- GET  /files/{fileId}/download

Owns: no database directly — writes final records via metadata-service.
Uses: Redis for in-progress upload session state, MinIO/S3 for object storage.
