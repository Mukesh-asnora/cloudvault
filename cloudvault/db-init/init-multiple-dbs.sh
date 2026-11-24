#!/bin/bash
# Runs automatically on first Postgres container startup (via docker-entrypoint-initdb.d).
# Creates one database per microservice so each service owns its own schema —
# this is what lets you later split them onto separate Postgres instances with
# zero application code changes.
set -e

create_database() {
	local database=$1
	echo "Creating database: $database"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	    SELECT 'CREATE DATABASE $database'
	    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
	EOSQL
}

if [ -n "$AUTH_DB_NAME" ]; then
	create_database "$AUTH_DB_NAME"
fi

if [ -n "$METADATA_DB_NAME" ]; then
	create_database "$METADATA_DB_NAME"
fi

echo "Database initialization complete."
