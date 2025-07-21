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

qa_backup:
	@echo "Dumping remote QA database..."
	@docker compose exec db bash -c "PGPASSWORD=${QA_DB_PASS} pg_dump -Fc -d ${QA_DB_DATABASE} -h ${QA_DB_HOST} -U ${QA_DB_USER} > /tmp/qa_db_backup.gz"
	@echo "Finished database dump"

qa_restore:
	@echo "Dropping local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/qa_db_backup.gz"
	@echo "Finished restoring local database"

qa_refresh: qa_backup qa_restore

local_drop:
	@echo "Dropping local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"

local_create:
	@echo "Creating local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"


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
local_recreate: local_drop local_create

prod_backup:
	@echo "Starting production database backup..."
	@chmod +x ./prod_backup.sh
	@docker compose exec db bash -c "/tmp/prod_backup.sh"
	@echo "Production database backup completed"

prod_restore:
	@echo "Dropping local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/prod_backup.dump"
	@echo "Finished restoring local database"

prod_refresh: prod_backup prod_restore

.PHONY: up down backup restore refresh qa_backup qa_refresh qa_restore prod_backup prod_restore prod_refresh