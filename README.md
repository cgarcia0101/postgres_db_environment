# Database Backup and Restore Tools

This project provides a set of tools for managing PostgreSQL database backups and restores across different environments (Development, QA, and Production).

## Prerequisites

- Docker and Docker Compose
- SSH access (for production database backups)
- PostgreSQL client tools (installed in the Docker container)

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
- Set the remote database credentials (`REMOTE_DB_*`)
- Set the local database credentials (`LOCAL_DB_*`)
- Set the QA database credentials (`QA_DB_*`)

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
```

## Architecture

This project provides a multi-environment PostgreSQL setup with the following components:

### Database Services
- **db_dev**: Development database (port 5432 via proxy)
- **db_qa**: QA database (internal network only)
- **db_prod**: Production database (internal network only)

### HAProxy Load Balancer
- **db-proxy**: HAProxy service that routes connections to different database environments
- Default backend: Development database
- Available backends: dev-db, qa-db, prod-db
- Configuration: `haproxy/haproxy.cfg`

### Network Configuration
- All services run on the `tt-database-network` Docker network
- HAProxy listens on port 5432 and routes to appropriate backend
- Database services are only accessible through the proxy

## Available Commands

### Environment Management
- `make up` - Start all Docker containers (databases + HAProxy proxy)
- `make down` - Stop and remove all Docker containers

### Environment Selection
- `make activate_dev` - Switch HAProxy to development database
- `make activate_qa` - Switch HAProxy to QA database
- `make activate_prod` - Switch HAProxy to production database

### Development Database
- `make dev_backup` - Create a backup of the development database
- `make dev_restore` - Restore the development database backup to local
- `make dev_refresh` - Run backup and restore in sequence

### QA Database
- `make qa_backup` - Create a backup of the QA database
- `make qa_restore` - Restore the QA database backup to local
- `make qa_refresh` - Run QA backup and restore in sequence

### Production Database
- `make prod_backup` - Create a backup of the production database
- `make prod_restore` - Restore the production backup to local
- `make prod_refresh` - Run production backup and restore in sequence

### Show Active Environment
- `make show_active_env` - Display the current active database environment by running the `get_current_env.sh` script inside the `db-proxy` container.

## Timing Information

All backup and restore operations include timing information, showing:
- Real elapsed time
- CPU time in user mode
- CPU time in kernel mode

## File Locations

- Database backups are stored in `/tmp/` within the Docker container:
  - Development: `/tmp/db_backup.gz`
  - QA: `/tmp/qa_db_backup.gz`
  - Production: `/tmp/prod_backup.dump`
  - Local: `/tmp/local_db_backup.gz`

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