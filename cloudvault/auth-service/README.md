# auth-service

Spring Boot service handling registration, login, JWT issuance, and RBAC.

Planned endpoints:
- POST /auth/register
- POST /auth/login
- POST /auth/refresh

Owns: `auth_db` (Postgres) — users, roles.
