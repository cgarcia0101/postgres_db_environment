include .env

up:
	@docker compose up -d

down:
	@docker compose down -v


backup:
	@echo "Dumping remote database..."
	@docker compose exec db bash -c "PGPASSWORD=${REMOTE_DB_PASS} pg_dump -Fc -d ${REMOTE_DB_DATABASE} -h ${REMOTE_DB_HOST} -U ${REMOTE_DB_USER} > /tmp/db_backup"
	@echo "Finished database dump"
	
restore:
	@echo "Dropping local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring database"
	@docker compose exec db  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/db_backup"
	@echo "Finished restoring database"
	
refresh: backup restore

.PHONY: up down backup restore refresh
