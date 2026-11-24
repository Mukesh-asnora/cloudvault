.PHONY: up down logs ps clean reset status

## Start all infra (postgres, redis, minio) in the background
up:
	docker compose up -d

## Stop all containers (keeps data volumes)
down:
	docker compose down

## Tail logs from every running container
logs:
	docker compose logs -f

## List running containers with health status
ps:
	docker compose ps

## Stop containers AND delete all data volumes (fresh start)
reset:
	docker compose down -v

## Quick check that infra is actually reachable, not just "started"
status:
	@echo "--- Postgres ---"
	@docker exec cloudvault-postgres pg_isready -U cloudvault || echo "NOT READY"
	@echo "--- Redis ---"
	@docker exec cloudvault-redis redis-cli ping || echo "NOT READY"
	@echo "--- MinIO ---"
	@curl -sf http://localhost:9000/minio/health/live > /dev/null && echo "OK" || echo "NOT READY"
