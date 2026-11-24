# metadata-service

Spring Boot service owning file/folder records and permissions (ACLs).

Planned endpoints:
- GET    /metadata/files
- POST   /metadata/files
- PATCH  /metadata/files/{id}
- DELETE /metadata/files/{id}
- POST   /metadata/files/{id}/share

Owns: `metadata_db` (Postgres) — file records, folders, permissions.
