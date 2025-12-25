# NeoBase Database Infrastructure

PostgreSQL container deployment system for NeoBase platform. Each user gets an isolated PostgreSQL database running in a Docker container with dedicated resources.

## 📋 Overview

- **Container-based**: Each database runs in an isolated Docker container
- **Resource limits**: 1 CPU core and 1GB RAM per container
- **Automatic backups**: Built-in backup and restore functionality
- **Port management**: Automatic port allocation (5432-6432)
- **Ubuntu optimized**: Designed for deployment on Ubuntu servers

## 🚀 Quick Start

### Prerequisites
- Ubuntu 20.04 or later
- Root or sudo access
- At least 4GB RAM and 2 CPU cores available

### Installation

1. **Run the setup script on your Ubuntu server:**
```bash
sudo ./scripts/setup.sh
```

This will:
- Install Docker and Docker Compose
- Create the NeoBase network
- Set up storage directories
- Configure firewall rules

2. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your settings
```

3. **Create your first database:**
```bash
./scripts/create-db.sh user123 myapp_db
```

## 📖 Usage

### Create a Database

```bash
./scripts/create-db.sh <user_id> <database_name> [username]
```

**Example:**
```bash
./scripts/create-db.sh user123 myapp_db
```

**Output:**
- Secure random password generated
- Available port automatically assigned
- Connection details saved to `.connections/<user_id>.json`

### List All Databases

```bash
./scripts/list-db.sh
```

Shows all active databases with their status, ports, and container names.

### Backup a Database

**Single database:**
```bash
./scripts/backup.sh user123
```

**All databases:**
```bash
./scripts/backup.sh all
```

**With custom label:**
```bash
./scripts/backup.sh user123 daily_backup
```

Backups are stored in `/var/backups/neobase/<user_id>/` and automatically cleaned after 30 days.

### Delete a Database

**Without backup:**
```bash
./scripts/delete-db.sh user123
```

**With final backup:**
```bash
./scripts/delete-db.sh user123 --keep-backup
```

⚠️ **Warning:** This permanently deletes the database and all data!

## 📁 Directory Structure

```
infrastructure/database/
├── docker-compose.template.yml   # Docker Compose template
├── init.sql                      # PostgreSQL initialization script
├── .env.example                  # Configuration template
├── .env                          # Your configuration (create this)
├── scripts/
│   ├── setup.sh                  # Ubuntu server setup
│   ├── create-db.sh              # Create new database
│   ├── delete-db.sh              # Remove database
│   ├── backup.sh                 # Backup databases
│   └── list-db.sh                # List all databases
├── .connections/                 # Connection details (auto-generated)
└── .db_*.env                     # Individual DB configs (auto-generated)
```

## 🔧 Configuration

### Environment Variables (`.env`)

```bash
# Resource Limits
DB_CPU_LIMIT=1.0
DB_MEMORY_LIMIT=1G
DB_MEMORY_RESERVATION=512M

# Port Range
PORT_RANGE_START=5432
PORT_RANGE_END=6432

# Backup Settings
BACKUP_DIR=/var/backups/neobase
BACKUP_RETENTION_DAYS=30
```

### PostgreSQL Features

The `init.sql` script automatically enables:
- `uuid-ossp` - UUID generation
- `pg_trgm` - Fuzzy text search
- `btree_gin` / `btree_gist` - Advanced indexing

Performance tuning is pre-configured for 1GB containers.

## 🔌 Connecting to Databases

After creating a database, connection details are saved in `.connections/<user_id>.json`:

```json
{
  "user_id": "user123",
  "database": "myapp_db",
  "username": "user123",
  "password": "...",
  "host": "localhost",
  "port": 5432,
  "connection_string": "postgresql://user123:password@localhost:5432/myapp_db"
}
```

**Connection examples:**

```bash
# psql
psql postgresql://user123:password@localhost:5432/myapp_db

# Node.js
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://user123:password@localhost:5432/myapp_db'
});

# Python
import psycopg2
conn = psycopg2.connect('postgresql://user123:password@localhost:5432/myapp_db')
```

## 🔒 Security Considerations

1. **Firewall**: Setup script configures UFW to allow PostgreSQL port range
2. **Passwords**: Automatically generated 32-character passwords
3. **File permissions**: Connection files are `chmod 600` (owner only)
4. **Network isolation**: All containers on isolated Docker network
5. **Resource limits**: Prevents resource exhaustion attacks

### Recommended Additional Security

```bash
# Restrict SSH access
ufw allow from <your-ip> to any port 22

# Use fail2ban for brute force protection
apt-get install fail2ban

# Enable Docker content trust
export DOCKER_CONTENT_TRUST=1

# Regular security updates
apt-get update && apt-get upgrade -y
```

## 📊 Monitoring

### Check Container Status

```bash
docker ps --filter "name=neobase_user_"
```

### View Container Logs

```bash
docker logs neobase_user_<user_id>_db
```

### Container Resource Usage

```bash
docker stats --filter "name=neobase_user_"
```

## 🔄 Backup & Recovery

### Automated Backups

Set up a cron job for automatic daily backups:

```bash
sudo crontab -e
```

Add:
```cron
0 2 * * * /path/to/infrastructure/database/scripts/backup.sh all
```

### Restore from Backup

```bash
# Find backup file
ls /var/backups/neobase/user123/

# Restore (unzip and pipe to psql)
gunzip -c /var/backups/neobase/user123/backup_20231222_020000.sql.gz | \
  docker exec -i neobase_user_user123_db psql -U user123 -d myapp_db
```

## 🐛 Troubleshooting

### Container won't start

```bash
# Check logs
docker logs neobase_user_<user_id>_db

# Check if port is already in use
netstat -tuln | grep <port>
```

### Out of disk space

```bash
# Check Docker disk usage
docker system df

# Clean up unused resources
docker system prune -a --volumes
```

### Connection refused

```bash
# Verify container is running
docker ps | grep neobase_user_<user_id>_db

# Test connection from host
nc -zv localhost <port>

# Check firewall rules
sudo ufw status
```

## 🚦 Performance Tuning

For high-traffic databases, adjust resources in `.env`:

```bash
# Increase limits for specific users
# Edit docker-compose.template.yml or create custom compose files
DB_CPU_LIMIT=2.0
DB_MEMORY_LIMIT=2G
```

Then recreate the container:
```bash
./scripts/delete-db.sh user123 --keep-backup
./scripts/create-db.sh user123 myapp_db
# Restore from backup
```

## 📝 TODO / Future Enhancements

- [ ] API service for programmatic database management
- [ ] Prometheus metrics exporter
- [ ] Kubernetes migration support
- [ ] Database connection pooling (PgBouncer)
- [ ] Automated scaling based on usage
- [ ] Multi-region replication
- [ ] Web UI for management

## 📄 License

Part of the NeoBase project.

## 🤝 Contributing

When modifying scripts:
1. Test on a clean Ubuntu VM
2. Ensure backward compatibility
3. Update this README with changes
4. Add error handling for edge cases

---

**Need help?** Check the logs first, then review container status with `docker ps` and `docker logs`.
