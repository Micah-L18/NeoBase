# PostgreSQL Quick Reference Guide

## Installation & Setup

### Install PostgreSQL on Linux
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib

# CentOS/RHEL
sudo yum install -y postgresql-server postgresql-contrib
sudo postgresql-setup initdb

# Start service
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Using These Scripts
```bash
# 1. Setup database
./setup_database.sh postgres

# With custom credentials
DB_NAME=myapp DB_USER=appuser DB_PASSWORD=SecurePass123 ./setup_database.sh postgres

# 2. Create schema
./create_schema.sh postgres --example users,posts,comments

# 3. Query database
./read_database.sh postgres --list-tables
./read_database.sh postgres --describe users
./read_database.sh postgres --query "SELECT * FROM users"
```

## Environment Variables

```bash
export DB_NAME=myapp_db
export DB_USER=myapp_user
export DB_PASSWORD=changeme123
export DB_HOST=localhost
export DB_PORT=5432
```

## Common PostgreSQL Commands

### Connection
```bash
# Connect as postgres superuser
sudo -u postgres psql

# Connect to specific database
psql -U myapp_user -d myapp_db -h localhost

# Connect with password prompt
psql -U myapp_user -d myapp_db -h localhost -W

# Using connection string
psql "postgresql://myapp_user:password@localhost:5432/myapp_db"
```

### Database Operations
```sql
-- List all databases
\l

-- Connect to database
\c myapp_db

-- List all tables
\dt

-- Describe table
\d users

-- List all schemas
\dn

-- Show table with indexes
\d+ users

-- Quit
\q
```

### User Management
```sql
-- Create user
CREATE USER myuser WITH PASSWORD 'mypassword';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE myapp_db TO myuser;

-- Grant table access
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO myuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO myuser;

-- List users
\du

-- Change password
ALTER USER myuser WITH PASSWORD 'newpassword';

-- Delete user
DROP USER myuser;
```

### Database Management
```sql
-- Create database
CREATE DATABASE myapp_db;

-- Create database with owner
CREATE DATABASE myapp_db OWNER myuser;

-- Delete database
DROP DATABASE myapp_db;

-- Rename database
ALTER DATABASE old_name RENAME TO new_name;
```

### Table Operations
```sql
-- Create table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add column
ALTER TABLE users ADD COLUMN age INTEGER;

-- Drop column
ALTER TABLE users DROP COLUMN age;

-- Rename column
ALTER TABLE users RENAME COLUMN email TO email_address;

-- Add index
CREATE INDEX idx_users_email ON users(email);

-- Drop table
DROP TABLE users;
```

### Data Operations
```sql
-- Insert single row
INSERT INTO users (username, email) VALUES ('john', 'john@example.com');

-- Insert multiple rows
INSERT INTO users (username, email) VALUES 
    ('jane', 'jane@example.com'),
    ('bob', 'bob@example.com');

-- Update
UPDATE users SET email = 'newemail@example.com' WHERE username = 'john';

-- Delete
DELETE FROM users WHERE id = 1;

-- Select
SELECT * FROM users;
SELECT username, email FROM users WHERE created_at > '2025-01-01';

-- Join
SELECT u.username, COUNT(p.id) as post_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.username;
```

## Backup & Restore

### Backup
```bash
# Backup single database
pg_dump -U myapp_user myapp_db > backup.sql

# Backup with custom format (compressed)
pg_dump -U myapp_user -Fc myapp_db > backup.dump

# Backup all databases
pg_dumpall -U postgres > all_databases.sql

# Backup only schema
pg_dump -U myapp_user --schema-only myapp_db > schema.sql

# Backup only data
pg_dump -U myapp_user --data-only myapp_db > data.sql
```

### Restore
```bash
# Restore from SQL file
psql -U myapp_user myapp_db < backup.sql

# Restore from custom format
pg_restore -U myapp_user -d myapp_db backup.dump

# Restore all databases
psql -U postgres < all_databases.sql
```

## Performance & Monitoring

### Check Database Size
```sql
-- All databases
SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname))
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;

-- Current database
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Active Connections
```sql
-- Show active connections
SELECT pid, usename, application_name, client_addr, state, query
FROM pg_stat_activity
WHERE state = 'active';

-- Kill connection
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = 12345;
```

### Query Performance
```sql
-- Enable timing
\timing on

-- Explain query
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';

-- Explain analyze (actually runs query)
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';

-- Show slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

## Configuration

### PostgreSQL Configuration File Locations
```bash
# Find config file
sudo -u postgres psql -c "SHOW config_file;"

# Common locations
/etc/postgresql/*/main/postgresql.conf
/var/lib/pgsql/data/postgresql.conf

# Client authentication
/etc/postgresql/*/main/pg_hba.conf
```

### Important Settings
```bash
# Edit postgresql.conf
sudo nano /etc/postgresql/*/main/postgresql.conf

# Allow remote connections
listen_addresses = '*'

# Max connections
max_connections = 100

# Memory settings
shared_buffers = 256MB
effective_cache_size = 1GB
```

### Allow Remote Access
```bash
# Edit pg_hba.conf
sudo nano /etc/postgresql/*/main/pg_hba.conf

# Add line (replace with your IP/network)
host    all             all             0.0.0.0/0               md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

## Connection Strings

### Formats
```bash
# Standard format
postgresql://username:password@host:port/database

# With SSL
postgresql://username:password@host:port/database?sslmode=require

# Multiple hosts (for failover)
postgresql://host1,host2,host3/database
```

### Programming Languages

**Python (psycopg2):**
```python
import psycopg2
conn = psycopg2.connect(
    dbname="myapp_db",
    user="myapp_user",
    password="changeme123",
    host="localhost",
    port="5432"
)
```

**Node.js (pg):**
```javascript
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: 'postgresql://myapp_user:changeme123@localhost:5432/myapp_db'
});
```

**Go (pgx):**
```go
conn, err := pgx.Connect(context.Background(), 
    "postgresql://myapp_user:changeme123@localhost:5432/myapp_db")
```

**Ruby (pg gem):**
```ruby
require 'pg'
conn = PG.connect(
  host: 'localhost',
  port: 5432,
  dbname: 'myapp_db',
  user: 'myapp_user',
  password: 'changeme123'
)
```

## Troubleshooting

### Check PostgreSQL Status
```bash
sudo systemctl status postgresql
sudo journalctl -u postgresql -n 50
```

### Reset Password
```bash
# Edit pg_hba.conf to trust local connections temporarily
sudo nano /etc/postgresql/*/main/pg_hba.conf
# Change: local all postgres peer
# To:     local all postgres trust

sudo systemctl restart postgresql
psql -U postgres -c "ALTER USER postgres PASSWORD 'newpassword';"
# Change back to peer/md5 and restart
```

### Common Errors

**"peer authentication failed"**
- Edit pg_hba.conf, change `peer` to `md5` for the connection type

**"role does not exist"**
```bash
sudo -u postgres createuser myapp_user
```

**"database does not exist"**
```bash
sudo -u postgres createdb myapp_db -O myapp_user
```

**"too many connections"**
- Increase `max_connections` in postgresql.conf or close unused connections

## Useful Scripts

### Create Development Database
```bash
#!/bin/bash
DB_NAME="dev_db"
DB_USER="dev_user"
DB_PASS="dev_pass"

sudo -u postgres psql <<EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF
```

### Drop and Recreate Database
```bash
#!/bin/bash
DB_NAME="myapp_db"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
```

### List All Tables with Row Counts
```sql
SELECT schemaname, tablename, n_live_tup as row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
```

## Resources

- Official Documentation: https://www.postgresql.org/docs/
- PostgreSQL Tutorial: https://www.postgresqltutorial.com/
- SQL Practice: https://pgexercises.com/
