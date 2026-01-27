#!/bin/bash

source /tmp/remote_config.sh

# Exit on any error
set -e

BACKUP_FILE="/tmp/prod_backup.dump"

echo "Setting up SSH tunnel..."
# Kill any existing tunnels on port 5433
pgrep -f "ssh.*5433:.*:5432" && pkill -f "ssh.*5433:.*:5432" || true

# Create SSH tunnel
ssh -f -N -L 5433:"$PROD_DB_HOST":"$PROD_DB_PORT" \
    -i "$SSH_KEY_PATH" \
    -p "$SSH_PORT" \
    "$SSH_USER@$SSH_HOST" \
    sleep 10

# Wait for tunnel to establish
sleep 2

echo "Starting database backup..."
PGPASSWORD="$PROD_DB_PASSWORD" pg_dump \
    -h localhost \
    -p 5433 \
    -U "$PROD_DB_USER" \
    -d "$PROD_DB_NAME" \
    -Fc \
    -v \
    -n public \
    --exclude-table-data=printer_server_errors \
    > "$BACKUP_FILE"

# Clean up SSH tunnel
pgrep -f "ssh.*5433:.*:5432" && pkill -f "ssh.*5433:.*:5432"

echo "Backup completed: $BACKUP_FILE"