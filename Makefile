include .env

up:
	@docker compose up -d

down:
	@docker compose down -v

# Backup dev database
dev_backup:
	@echo "Dumping remote database..."
	@time docker compose exec db_dev bash -c "PGPASSWORD=${REMOTE_DB_PASS} pg_dump -Fc -v -d ${REMOTE_DB_DATABASE} -h ${REMOTE_DB_HOST} -U ${REMOTE_DB_USER} > /tmp/db_backup.gz"
	@echo "Finished database dump from dev"

# restore local data from dev database backup
dev_restore:
	@echo "Dropping local database"
	@docker compose exec db_dev  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db_dev  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@time docker compose exec db_dev  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/db_backup.gz"
	@echo "Finished restoring local database from dev backup"

dev_refresh: dev_backup dev_restore

# Backup QA database
qa_backup:
	@echo "Dumping remote QA database..."
	@time docker compose exec db_qa bash -c "PGPASSWORD=${QA_DB_PASS} pg_dump -Fc -v -d ${QA_DB_DATABASE} -h ${QA_DB_HOST} -U ${QA_DB_USER} --exclude-table-data=printer_server_errors > /tmp/qa_db_backup.gz"
	@echo "Finished remote QA database dump"

# Restore local data from QA backup
qa_restore:
	@echo "Dropping local database"
	@docker compose exec db_qa  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db_qa  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@time docker compose exec db_qa  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/qa_db_backup.gz"
	@echo "Finished restoring local database from QA backup"

qa_refresh: qa_backup qa_restore

# Backup Prod database
prod_backup:
	@echo "Starting production database backup..."
	@chmod +x ./prod_backup.sh
	@time docker compose exec db_prod bash -c "/tmp/prod_backup.sh"
	@echo "Production database backup completed"

# Restore local data from prod backup
prod_restore:
	@echo "Dropping local database"
	@docker compose exec db_prod  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db_prod  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@time docker compose exec db_prod  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/prod_backup.dump"
	@echo "Finished restoring local database from prod backup"

prod_refresh: prod_backup prod_restore

activate_dev:
	@echo "Activating dev database"
	@sed -i '' 's/default_backend \([a-zA-Z-]*\)/default_backend dev-db/' ./haproxy/haproxy.cfg
	@docker compose restart db-proxy
	@echo "Dev database activated"

activate_qa:
	@echo "Activating QA database"
	@sed -i '' 's/default_backend \([a-zA-Z-]*\)/default_backend qa-db/' ./haproxy/haproxy.cfg
	@docker compose restart db-proxy
	@echo "QA database activated"

activate_prod:
	@echo "Activating prod database"
	@sed -i '' 's/default_backend \([a-zA-Z-]*\)/default_backend prod-db/' ./haproxy/haproxy.cfg
	@docker compose restart db-proxy
	@echo "Prod database activated"

show_active_env:
	@echo "Current environment is: "
	@docker compose exec db-proxy sh -c "/tmp/get_current_env.sh"


.PHONY: up down backup restore refresh qa_backup qa_refresh qa_restore prod_backup prod_restore prod_refresh activate_dev activate_qa activate_prod show_active_env