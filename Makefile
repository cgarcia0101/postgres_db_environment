include .env

RESTORE_LOG := restore.log

# Ensure gitignored frontend config exists so db-proxy can start
up:
	@test -f ./haproxy/haproxy-frontend.cfg || cp ./haproxy/haproxy-frontend.cfg.example ./haproxy/haproxy-frontend.cfg
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

dev_refresh: dev_backup dev_restore
	@echo "$$(date '+%Y-%m-%d %H:%M:%S') dev_refresh" >> $(RESTORE_LOG)

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

qa_refresh: qa_backup qa_restore
	@echo "$$(date '+%Y-%m-%d %H:%M:%S') qa_refresh" >> $(RESTORE_LOG)

# Backup Snap database
snap_backup:
	@echo "Dumping remote Snap database..."
	@time docker compose exec db_snap bash -c "PGPASSWORD=${SNAP_DB_PASS} pg_dump -Fc -v -d ${SNAP_DB_DATABASE} -h ${SNAP_DB_HOST} -U ${SNAP_DB_USER} -n public --exclude-table-data=printer_server_errors > /tmp/snap_db_backup.gz"
	@echo "Finished remote Snap database dump"

# Restore local data from Snap backup
snap_restore:
	@echo "Restarting database container to ensure no active connections..."
	@docker compose restart db_snap
	@echo "Dropping local database"
	@docker compose exec db_snap  bash -c "PGPASSWORD=${LOCAL_DB_PASS} dropdb --if-exists -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Creating local database"
	@docker compose exec db_snap  bash -c "PGPASSWORD=${LOCAL_DB_PASS} createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_DATABASE}"
	@echo "Restoring local database"
	@time docker compose exec db_snap  bash -c "PGPASSWORD=${LOCAL_DB_PASS} pg_restore --clean --if-exists -Fc -U ${LOCAL_DB_USER} -d ${LOCAL_DB_DATABASE} /tmp/snap_db_backup.gz"
	@echo "Finished restoring local database from Snap backup"

snap_refresh: snap_backup snap_restore
	@echo "$$(date '+%Y-%m-%d %H:%M:%S') snap_refresh" >> $(RESTORE_LOG)

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

prod_refresh: prod_backup prod_restore
	@echo "$$(date '+%Y-%m-%d %H:%M:%S') prod_refresh" >> $(RESTORE_LOG)

# SSH tunnel to production database (connect to localhost:5433)
# Requires: remote_config.sh and ssh/ key. Ctrl+C to close.
prod_tunnel:
	@echo "Starting SSH tunnel to production DB (localhost:5433 -> prod)..."
	@echo "Connect with: psql -h localhost -p 5433 -U postgres -d postgres"
	@echo "Press Ctrl+C to close the tunnel."
	docker compose run --rm -p 5433:5433 db_prod bash -c 'source /tmp/remote_config.sh && ssh -N -L 5433:"$$PROD_DB_HOST":"$$PROD_DB_PORT" -i "$$SSH_KEY_PATH" -p "$$SSH_PORT" "$$SSH_USER@$$SSH_HOST"'

# Write only the gitignored frontend file so haproxy.cfg stays clean in git
activate_dev:
	@echo "Activating dev database"
	@printf 'frontend pg-frontend\n    bind *:5432\n    default_backend dev-db\n' > ./haproxy/haproxy-frontend.cfg
	@docker compose restart db-proxy
	@echo "Dev database activated"

activate_qa:
	@echo "Activating QA database"
	@printf 'frontend pg-frontend\n    bind *:5432\n    default_backend qa-db\n' > ./haproxy/haproxy-frontend.cfg
	@docker compose restart db-proxy
	@echo "QA database activated"

activate_snap:
	@echo "Activating Snap database"
	@printf 'frontend pg-frontend\n    bind *:5432\n    default_backend snap-db\n' > ./haproxy/haproxy-frontend.cfg
	@docker compose restart db-proxy
	@echo "Snap database activated"

activate_prod:
	@echo "Activating prod database"
	@printf 'frontend pg-frontend\n    bind *:5432\n    default_backend prod-db\n' > ./haproxy/haproxy-frontend.cfg
	@docker compose restart db-proxy
	@echo "Prod database activated"

show_active_env:
	@echo "Current environment is: $$(grep -E '^\s*default_backend' ./haproxy/haproxy-frontend.cfg 2>/dev/null | awk '{print $$2}' | cut -d'-' -f1 || echo 'unknown')"

# Show last restore time for each database
show_restore_log:
	@if [ -f $(RESTORE_LOG) ]; then \
		echo ""; \
		echo "Last Refresh Times"; \
		echo ""; \
		printf "  %-8s %-19s %s\n" "Env" "Elapsed" "Date"; \
		printf "  %-8s %-19s %s\n" "---" "-------" "-------------------"; \
		for db in dev_refresh qa_refresh snap_refresh prod_refresh; do \
			env_name=$$(echo "$$db" | sed 's/_refresh//'); \
			last=$$(grep " $$db$$" $(RESTORE_LOG) | tail -1); \
			if [ -n "$$last" ]; then \
				ts=$$(echo "$$last" | awk '{print $$1 " " $$2}'); \
				ts_fmt=$$(echo "$$ts" | tr '-' '/'); \
				epoch_ts=$$(date -j -f "%Y-%m-%d %H:%M:%S" "$$ts" "+%s" 2>/dev/null); \
				epoch_now=$$(date "+%s"); \
				diff_sec=$$((epoch_now - epoch_ts)); \
				if [ $$diff_sec -lt 60 ]; then \
					elapsed="$$diff_sec seconds ago"; \
				elif [ $$diff_sec -lt 3600 ]; then \
					elapsed="$$((diff_sec / 60)) minutes ago"; \
				elif [ $$diff_sec -lt 86400 ]; then \
					elapsed="$$((diff_sec / 3600)) hours ago"; \
				else \
					elapsed="$$((diff_sec / 86400)) days ago"; \
				fi; \
			else \
				elapsed="never"; \
				ts_fmt="—"; \
			fi; \
			printf "  %-8s %-19s %s\n" "$$env_name" "$$elapsed" "$$ts_fmt"; \
		done; \
		echo ""; \
	else \
		echo "No restores logged yet ($(RESTORE_LOG) not found)."; \
	fi

.PHONY: up down backup restore refresh qa_backup qa_refresh qa_restore snap_backup snap_restore snap_refresh prod_backup prod_restore prod_refresh prod_tunnel activate_dev activate_qa activate_snap activate_prod show_active_env show_restore_log