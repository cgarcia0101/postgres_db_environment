include .env

up:
	@docker compose up -d

down:
	@docker compose down -v

backup:
	@echo "Dumping remote database..."
	@docker compose exec db bash -c "PGPASSWORD=${REMOTE_DB_PASS} pg_dump -Fc -d ${REMOTE_DB_DATABASE} -h ${REMOTE_DB_HOST} -U ${REMOTE_DB_USER} > /tmp/db_backup.gz"
	@echo "Finished database dump"
	
restore:
	@echo "Dropping local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/db_backup.gz"
	@echo "Finished restoring local database"

local_backup:
	@echo "Dumping local database..."
	@docker compose exec db bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_dump -Fc -d ${LOCAL_DB_DATABASE} -U ${LOCAL_DB_USER} > /tmp/local_db_backup.gz"
	@echo "Finished local database dump"

local_restore:
	@echo "Dropping local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database with local database backup"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/local_db_backup.gz"
	@echo "Finished restoring local database"
	
refresh: backup restore

.PHONY: up down backup restore refresh
