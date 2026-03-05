include .env

RESTORE_LOG := restore.log

up:
	@docker compose up -d

down:
	@docker compose down -v

# Backup dev database
dev_backup:
	@echo "Dumping remote database..."
	@time docker compose exec db_dev bash -c "PGPASSWORD=${REMOTE_DB_PASS} pg_dump -Fc -v -d ${REMOTE_DB_DATABASE} -h ${REMOTE_DB_HOST} -U ${REMOTE_DB_USER} -n public > /tmp/db_backup.gz"
	@echo "Finished database dump from dev"

# restore local data from dev database backup
dev_restore:
	@echo "Restarting database container to ensure no active connections..."
	@docker compose restart db_dev
	@echo "Dropping local database"
	@docker compose exec db_dev  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db_dev  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@time docker compose exec db_dev  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/db_backup.gz"
	@echo "Finished restoring local database from dev backup"
	@echo "$$(date '+%Y-%m-%d %H:%M:%S') dev_restore" >> $(RESTORE_LOG)

dev_refresh: dev_backup dev_restore

# Backup QA database
qa_backup:
	@echo "Dumping remote QA database..."
	@time docker compose exec db_qa bash -c "PGPASSWORD=${QA_DB_PASS} pg_dump -Fc -v -d ${QA_DB_DATABASE} -h ${QA_DB_HOST} -U ${QA_DB_USER} -n public --exclude-table-data=printer_server_errors > /tmp/qa_db_backup.gz"
	@echo "Finished remote QA database dump"

# Restore local data from QA backup
qa_restore:
	@echo "Restarting database container to ensure no active connections..."
	@docker compose restart db_qa
	@echo "Dropping local database"
	@docker compose exec db_qa  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db_qa  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@time docker compose exec db_qa  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/qa_db_backup.gz"
	@echo "Finished restoring local database from QA backup"
	@echo "$$(date '+%Y-%m-%d %H:%M:%S') qa_restore" >> $(RESTORE_LOG)

qa_refresh: qa_backup qa_restore

# Backup Prod database
prod_backup:
	@echo "Starting production database backup..."
	@chmod +x ./prod_backup.sh
	@time docker compose exec db_prod bash -c "/tmp/prod_backup.sh"
	@echo "Production database backup completed"

# Restore local data from prod backup
prod_restore:
	@echo "Restarting database container to ensure no active connections..."
	@docker compose restart db_prod
	@echo "Dropping local database"
	@docker compose exec db_prod  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db_prod  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@time docker compose exec db_prod  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/prod_backup.dump"
	@echo "Finished restoring local database from prod backup"
	@echo "$$(date '+%Y-%m-%d %H:%M:%S') prod_restore" >> $(RESTORE_LOG)

prod_refresh: prod_backup prod_restore

# SSH tunnel to production database (connect to localhost:5433)
# Requires: remote_config.sh and ssh/ key. Ctrl+C to close.
prod_tunnel:
	@echo "Starting SSH tunnel to production DB (localhost:5433 -> prod)..."
	@echo "Connect with: psql -h localhost -p 5433 -U postgres -d postgres"
	@echo "Press Ctrl+C to close the tunnel."
	docker compose run --rm -p 5433:5433 db_prod bash -c 'source /tmp/remote_config.sh && ssh -N -L 5433:"$$PROD_DB_HOST":"$$PROD_DB_PORT" -i "$$SSH_KEY_PATH" -p "$$SSH_PORT" "$$SSH_USER@$$SSH_HOST"'

activate_dev:
	@echo "Activating dev database"
	@sed -i.bak 's/default_backend \([a-zA-Z-]*\)/default_backend dev-db/' ./haproxy/haproxy.cfg && rm -f ./haproxy/haproxy.cfg.bak
	@docker compose restart db-proxy
	@echo "Dev database activated"

activate_qa:
	@echo "Activating QA database"
	@sed -i.bak 's/default_backend \([a-zA-Z-]*\)/default_backend qa-db/' ./haproxy/haproxy.cfg && rm -f ./haproxy/haproxy.cfg.bak
	@docker compose restart db-proxy
	@echo "QA database activated"

activate_prod:
	@echo "Activating prod database"
	@sed -i.bak 's/default_backend \([a-zA-Z-]*\)/default_backend prod-db/' ./haproxy/haproxy.cfg && rm -f ./haproxy/haproxy.cfg.bak
	@docker compose restart db-proxy
	@echo "Prod database activated"

show_active_env:
	@echo "Current environment is: "
	@docker compose exec db-proxy sh -c "/tmp/get_current_env.sh"

# Show last restore time for each database
show_restore_log:
	@if [ -f $(RESTORE_LOG) ]; then \
		echo "Last restore times:"; \
		for db in dev_restore qa_restore prod_restore; do \
			last=$$(grep " $$db$$" $(RESTORE_LOG) | tail -1); \
			[ -n "$$last" ] && echo "  $$last" || echo "  $$db: never"; \
		done; \
	else \
		echo "No restores logged yet ($(RESTORE_LOG) not found)."; \
	fi

.PHONY: up down backup restore refresh qa_backup qa_refresh qa_restore prod_backup prod_restore prod_refresh prod_tunnel activate_dev activate_qa activate_prod show_active_env show_restore_log