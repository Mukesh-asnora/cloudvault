# CloudVault — Phase 0 setup

This gets your local dev environment fully running: Postgres (with separate
databases per service), Redis, and a MinIO S3-compatible bucket — all
self-provisioning, zero AWS cost, zero manual console clicking.

---

## Step-by-step procedure

### 1. Install the toolchain

| Tool | Check installed | Install if missing |
|---|---|---|
| Java 17 (Temurin recommended) | `java -version` | https://adoptium.net |
| Maven | `mvn -version` | https://maven.apache.org/install.html (or use the Maven wrapper once services exist) |
| Docker Desktop (includes Docker Compose v2) | `docker compose version` | https://www.docker.com/products/docker-desktop |
| Node.js LTS (v20+) | `node -v` | https://nodejs.org |
| Git | `git --version` | https://git-scm.com |

You do **not** need to separately install PostgreSQL, Redis, or MinIO —
they run as containers via Docker Compose below. That's the point of this
setup: nothing but Docker, Java, and Node touch your actual machine.

### 2. Clone / place the project structure

```
cloudvault/
  auth-service/          (Spring Boot — empty for now, Phase 1)
  file-service/           (Spring Boot — empty for now, Phase 3)
  metadata-service/       (Spring Boot — empty for now, Phase 2)
  api-gateway/            (Spring Cloud Gateway — empty for now, Phase 4)
  frontend/               (React — empty for now, Phase 5)
  db-init/
    init-multiple-dbs.sh  (auto-creates auth_db + metadata_db on first boot)
  k8s/                    (Kubernetes manifests — Phase 7)
  docker-compose.yml
  .env.example
  .gitignore
  Makefile
```

### 3. Configure environment variables

```bash
cp .env.example .env
```

Open `.env` and at minimum generate a real JWT secret (don't ship the
placeholder):

```bash
openssl rand -base64 64
```

Paste the output as `JWT_SECRET` in `.env`. Everything else in `.env.example`
is safe to use as-is for local development.

### 4. Start the infrastructure

```bash
make up
# equivalent to: docker compose up -d
```

This starts, in dependency order:
1. **postgres** — boots, then `db-init/init-multiple-dbs.sh` runs automatically
   on first startup, creating `auth_db` and `metadata_db` as separate
   databases inside the one container.
2. **redis** — starts with append-only persistence enabled (survives restarts).
3. **minio** — starts the S3-compatible API on port 9000 and its web console
   on port 9001.
4. **minio-init** — a one-shot container that waits for MinIO to report
   healthy, then creates the `cloudvault-files` bucket automatically. It
   exits after running — that's expected, not a crash.

### 5. Verify everything is actually healthy (not just "started")

```bash
make status
```

Expected output:
```
--- Postgres ---
/var/run/postgresql:5432 - accepting connections
--- Redis ---
PONG
--- MinIO ---
OK
```

Or check container health directly:
```bash
make ps
```
All containers should show `(healthy)` next to postgres, redis, and minio.

### 6. Confirm the databases were created correctly

```bash
docker exec -it cloudvault-postgres psql -U cloudvault -l
```
You should see `auth_db` and `metadata_db` listed alongside the defaults.

### 7. Confirm the MinIO bucket exists

Open the MinIO console in a browser: **http://localhost:9001**
Log in with the `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from your `.env`.
You should see a `cloudvault-files` bucket already created — you never
touched the console to make it.

### 8. Day-to-day commands

```bash
make logs     # tail logs from everything
make down     # stop containers, keep data
make reset    # stop containers AND wipe volumes (fresh slate)
```

---

## Why this setup counts as "industry-ready" rather than a toy

- **Health checks, not sleep timers.** Every service in `docker-compose.yml`
  declares a real `healthcheck` (`pg_isready`, `redis-cli ping`, MinIO's
  `/minio/health/live`). Application services later `depends_on` these with
  `condition: service_healthy` — this eliminates the classic bug where an app
  container starts before its database is actually ready to accept
  connections, which is one of the most common causes of flaky local dev
  environments and CI pipelines.
- **Secrets never hit the repo.** `.env` is gitignored; `.env.example`
  documents every variable without real values. This is the same pattern
  used in production CI/CD (secrets injected at deploy time, never
  committed).
- **Data isolation per service, from day one.** Even though Postgres runs as
  one container locally, `auth_db` and `metadata_db` are fully separate
  databases. Each future service connects only to its own database — so
  splitting them onto separate Postgres instances later (a real production
  step) requires zero application code changes, only a connection string
  change.
- **Self-provisioning, not manual setup.** The MinIO bucket is created by the
  `minio-init` one-shot container automatically. A new developer (or a CI
  runner) runs one command and gets a fully working environment — nobody
  has to remember "oh, and click create-bucket in the console."
- **Named volumes for persistence.** Data survives `make down` and container
  restarts; `make reset` is the explicit, deliberate way to wipe it. You
  won't lose test data by accident.
- **Convenience commands, not memorized flags.** The `Makefile` mirrors what
  a real engineering team's onboarding doc looks like: `make up`, `make
  logs`, `make status` — a new contributor is productive in minutes.

## Next step

Phase 1: build `auth-service` — a Spring Boot app with Spring Security, JJWT,
and a `User` entity, connecting to `auth_db` using the connection string
already wired up (commented out) in `docker-compose.yml`.
