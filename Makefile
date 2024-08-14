include .env

backup:
	@echo "Dumping database..."
	@docker-compose exec db bash -c "PGPASSWORD=${REMOTE_DB_PASS} pg_dump -c --if-exists -d ${REMOTE_DB_DATABASE} -h ${REMOTE_DB_HOST} -U ${REMOTE_DB_USER} > /tmp/db_backup.sql"
	@echo "Finished database dump"
	
restore:
	@echo "Restoring database"
	@docker compose exec db  bash -c "psql -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} < /tmp/db_backup.sql"
	@echo "Finished restoring database"
	
refresh: backup restore
