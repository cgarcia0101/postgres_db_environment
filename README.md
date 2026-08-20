# Database Backup and Restore Tools

This project provides a set of tools for managing PostgreSQL database backups and restores across different environments (dev, QA, snap, and production).

## Prerequisites

- Docker and Docker Compose
- SSH access (for production database backups and the `redis-dev` tunnel)
- PostgreSQL client tools (installed in the Docker container)
- Enough free disk for the dumps — a full production dump runs to several GB

## Setup

1. Clone this repository: 
```bash 
 git clone <repository-url> cd <repository-name>
 ```
2. Create an environment file: 
```bash
cp .env.example .env
```

3. Edit the `.env` file with your database credentials:
- Set the remote (dev) database credentials (`REMOTE_DB_*`)
- Set the local database credentials (`LOCAL_DB_*`)
- Set the QA database credentials (`QA_DB_*`)
- Set the snap database credentials (`SNAP_DB_*`)
- Optional, only for the `redis-dev` tunnel: `BASTION_URL`, `REDIS_DEV_USER`, `REDIS_DEV_URL`,
  and `REDIS_DEV_SSH_KEY_PATH` (must be a path *relative to the project root*, e.g. `ssh/id_rsa`,
  because Docker `COPY` cannot reach outside the build context)

Production credentials do not live in `.env` — see the next step.

4. For production backups, create a `remote_config.sh` file with the following variables:
```bash 
PROD_DB_HOST="your-prod-db-host"
PROD_DB_PORT="5432" 
PROD_DB_USER="your-prod-db-user"
PROD_DB_PASSWORD="your-prod-db-password"
PROD_DB_NAME="your-prod-db-name"
SSH_KEY_PATH="/path/to/your/ssh/key"
SSH_PORT="22"
SSH_USER="your-ssh-user"
SSH_HOST="your-ssh-host"
```

5. Start the Docker container:
```bash 
make up
# On Windows:
.\Make.ps1 up
```

## Architecture

This project provides a multi-environment PostgreSQL setup with the following components:

### Database Services
Four independent local PostgreSQL containers, one per source environment. Each holds its own
restored copy of that environment's data in its own named volume, and none of them publishes a port
directly — all client access goes through the proxy on `localhost:5432`.

- **db_dev**: local copy of the development database (volume `dev_data`)
- **db_qa**: local copy of the QA database (volume `qa_data`)
- **db_snap**: local copy of the snap database (volume `snap_data`)
- **db_prod**: local copy of the production database (volume `prod_data`)

### Redis Services
- **redis**: local Redis 7.2 with AOF persistence, on `localhost:6379`
- **redis-dev**: SSH tunnel to the remote dev Redis through a bastion host, on `localhost:6380`.
  Built from `redis-dev/Dockerfile`, which copies the SSH key named by `REDIS_DEV_SSH_KEY_PATH`
  in at build time — change the key and you must rebuild (`docker compose build redis-dev`).
- **redis-insight**: RedisInsight web UI on http://localhost:5540, waits for `redis` to be healthy

### HAProxy Load Balancer
- **db-proxy**: HAProxy service that routes connections to one database environment at a time
- Listens on `localhost:5432`; exactly one backend is active, selected by the `activate_*` commands
- Available backends: dev-db, qa-db, snap-db, prod-db
- Backend definitions: `haproxy/haproxy.cfg` (tracked in git, do not edit to switch environments)
- Active selection: `haproxy/haproxy-frontend.cfg` (gitignored). The `activate_*` commands
  overwrite this file and restart the proxy; `make up` seeds it from
  `haproxy/haproxy-frontend.cfg.example` if it is missing.

### Network Configuration
- All services run on the `tt-database-network` Docker network
- HAProxy listens on port 5432 and routes to appropriate backend
- Database services are only accessible through the proxy

## Available Commands

On **Linux/macOS**, use `make <command>`. On **Windows**, use `.\Make.ps1 <command>` in PowerShell.

### Environment Management
- `up` - Start all Docker containers (databases, Redis services, HAProxy proxy). Also creates
  `haproxy/haproxy-frontend.cfg` from the example file if it does not exist yet.
- `down` - Stop and remove all Docker containers. **This runs `docker compose down -v`, which also
  deletes the named volumes** — every restored database is wiped and has to be refreshed again.

### Environment Selection
Exactly one environment answers on `localhost:5432` at a time. Switching restarts `db-proxy`, so
existing connections drop.

- `activate_dev` - Switch HAProxy to development database
- `activate_qa` - Switch HAProxy to QA database
- `activate_snap` - Switch HAProxy to snap database
- `activate_prod` - Switch HAProxy to production database

### Development Database
- `dev_backup` - Create a backup of the development database
- `dev_restore` - Restore the development database backup to local
- `dev_refresh` - Run backup and restore in sequence

### QA Database
- `qa_backup` - Create a backup of the QA database
- `qa_restore` - Restore the QA database backup to local
- `qa_refresh` - Run QA backup and restore in sequence

### Snap Database
- `snap_backup` - Create a backup of the snap database
- `snap_restore` - Restore the snap backup to local
- `snap_refresh` - Run snap backup and restore in sequence

### Production Database
- `prod_backup` - Create a backup of the production database
- `prod_restore` - Restore the production backup to local
- `prod_refresh` - Run production backup and restore in sequence
- `prod_tunnel` - Start an SSH tunnel to the production database. Exposes prod DB on `localhost:5433`. Requires `remote_config.sh` and SSH key. Connect with `psql -h localhost -p 5433 -U postgres -d postgres`. Press Ctrl+C to close the tunnel. **macOS/Linux only** — there is no `prod_tunnel` in `Make.ps1`.

### Status & Logs
- `show_active_env` - Display the current active database environment (which backend HAProxy is routing to).
- `show_restore_log` - Show the last successful backup and the last successful restore for each environment (dev, QA, snap, prod) from `restore.log`, as relative time ("5 days ago") plus the timestamp. Displays "never" / "-" when an environment has no entry of that kind yet.

Every successful `*_backup` and `*_restore` appends a `YYYY-MM-DD HH:MM:SS <env>_<backup|restore>` line to `restore.log` (gitignored, local to your machine). A `*_refresh` writes both entries via its backup and restore steps. Older `<env>_refresh` lines are still read, counting as both a backup and a restore.

## Windows Usage Notes

If you encounter an execution policy error when running `.ps1` files, you may need to run this once in your PowerShell terminal:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

## Timing Information

Backup and restore operations are wrapped in `time` (Makefile) or `Measure-Command` (`Make.ps1`),
so each one reports how long it took:
- Real elapsed time
- CPU time in user mode
- CPU time in kernel mode

This duration is printed to the terminal only — `restore.log` stores just the timestamp of each
operation, not its duration.

## File Locations

The project root is bind-mounted at `/tmp` inside every database container (`.:/tmp` in
`docker-compose.yml`), so a dump written to `/tmp/<name>` inside the container *is* the file of the
same name in the project root on your machine. These files are large and gitignored.

- Dev: `/tmp/db_backup.gz`
- QA: `/tmp/qa_db_backup.gz`
- Snap: `/tmp/snap_db_backup.gz`
- Production: `/tmp/prod_backup.dump` (written by `prod_backup.sh`, which also runs from `/tmp`)

A `*_restore` reads the dump that the matching `*_backup` produced, so restoring without a prior
backup replays whatever dump is still sitting in the project root from last time.

## Security Notes

1. Never commit the `.env` file or `remote_config.sh` to version control
2. Keep SSH keys and database credentials secure
3. Ensure proper access controls are in place for production database access

## Troubleshooting

1. If the SSH tunnel fails during production backup:
   - Check SSH key permissions
   - Verify SSH connection details
   - Ensure no existing tunnel is running on port 5433

2. If database operations fail:
   - Verify database credentials in `.env`
   - Check database host accessibility
   - Ensure Docker containers are running (`docker compose ps`)

## Contributing

1. Create a feature branch
2. Make your changes
3. Submit a pull request

## License

This project is licensed under the GNU General Public License v3.0.

The GPL-3.0 license ensures that:
- The software is free to use, modify, and distribute
- Any modifications or derived works must also be open source
- The source code must be made available
- Changes made to the code must be documented