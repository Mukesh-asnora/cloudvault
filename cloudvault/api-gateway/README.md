# api-gateway

Spring Cloud Gateway. Single entry point for the frontend.

Responsibilities:
- Validate JWT on every request except /auth/login and /auth/register
- Route /auth/** -> auth-service, /files/** -> file-service, /metadata/** -> metadata-service
- Rate limiting (Redis-backed)
