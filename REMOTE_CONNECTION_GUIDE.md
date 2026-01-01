# Connecting to Remote PostgreSQL Database from Mac

This guide shows how to connect to your PostgreSQL database running on a Linux server from your Mac.

---

## Step 1: Configure PostgreSQL on Linux Server to Accept Remote Connections

SSH into your Linux server and configure PostgreSQL:

### A. Edit PostgreSQL Configuration

```bash
# SSH into your Linux server first
ssh user@your-server-ip

# Find PostgreSQL config file location
sudo -u postgres psql -c "SHOW config_file;"

# Edit postgresql.conf (adjust path based on output above)
sudo nano /etc/postgresql/*/main/postgresql.conf

# Find and change this line:
# FROM:
#listen_addresses = 'localhost'

# TO:
listen_addresses = '*'

# Save and exit (Ctrl+X, then Y, then Enter)
```

### B. Configure Client Authentication

```bash
# Edit pg_hba.conf
sudo nano /etc/postgresql/*/main/pg_hba.conf

# Add this line at the end (allows connections from any IP with password)
host    all             all             0.0.0.0/0               md5

# For more security, replace 0.0.0.0/0 with your Mac's IP or network
# Example for specific IP:
host    all             all             192.168.1.100/32        md5

# Example for subnet:
host    all             all             192.168.1.0/24          md5

# Save and exit (Ctrl+X, then Y, then Enter)
```

### C. Restart PostgreSQL

```bash
sudo systemctl restart postgresql

# Or on macOS-style systems:
sudo brew services restart postgresql
```

### D. Open Firewall Port

```bash
# Ubuntu/Debian with UFW
sudo ufw allow 5432/tcp
sudo ufw status

# CentOS/RHEL with firewalld
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --reload

# Check if port is listening
sudo netstat -plnt | grep 5432
# Should show: tcp 0.0.0.0:5432
```

---

## Step 2: Get Connection Details

You need these details from your Linux server:

```bash
# On your Linux server, get the server's IP address
ip addr show | grep "inet " | grep -v 127.0.0.1

# Or use:
hostname -I

# Your connection details:
# - Server IP: (from command above)
# - Port: 5432 (default)
# - Database: myapp_db (or your DB_NAME)
# - Username: myapp_user (or your DB_USER)
# - Password: changeme123 (or your DB_PASSWORD)
```

**Example:**
- Server IP: `192.168.1.50`
- Database: `myapp_db`
- Username: `myapp_user`
- Password: `changeme123`

---

## Step 3: Connect from Your Mac

### Method 1: Command Line (psql)

#### Install PostgreSQL Client on Mac

```bash
# Using Homebrew
brew install postgresql@15

# Add to PATH if needed
echo 'export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
psql --version
```

#### Connect to Remote Database

```bash
# Basic connection
psql -h 192.168.1.50 -p 5432 -U myapp_user -d myapp_db

# With password in environment variable (more secure)
export PGPASSWORD='changeme123'
psql -h 192.168.1.50 -p 5432 -U myapp_user -d myapp_db

# Using connection string
psql "postgresql://myapp_user:changeme123@192.168.1.50:5432/myapp_db"
```

#### Create Alias for Easy Access

```bash
# Add to ~/.zshrc
echo 'alias remote-db="psql -h 192.168.1.50 -p 5432 -U myapp_user -d myapp_db"' >> ~/.zshrc
source ~/.zshrc

# Now just type:
remote-db
```

---

### Method 2: GUI Database Tools

#### A. Postico (Recommended for Mac)

1. Download: https://eggerapps.at/postico/
2. Open Postico
3. Click "New Favorite"
4. Enter details:
   - **Host:** 192.168.1.50
   - **Port:** 5432
   - **User:** myapp_user
   - **Password:** changeme123
   - **Database:** myapp_db
5. Click "Connect"

#### B. DBeaver (Free, Cross-platform)

1. Download: https://dbeaver.io/download/
2. Install and open DBeaver
3. Click "Database" → "New Database Connection"
4. Select "PostgreSQL"
5. Enter details:
   - **Host:** 192.168.1.50
   - **Port:** 5432
   - **Database:** myapp_db
   - **Username:** myapp_user
   - **Password:** changeme123
6. Click "Test Connection" then "Finish"

#### C. TablePlus

1. Download: https://tableplus.com/
2. Open TablePlus
3. Click "Create a new connection"
4. Select "PostgreSQL"
5. Enter details and connect

#### D. pgAdmin (Official PostgreSQL Tool)

1. Download: https://www.pgadmin.org/download/
2. Install and open pgAdmin
3. Right-click "Servers" → "Register" → "Server"
4. General tab: Name = "My Remote DB"
5. Connection tab:
   - **Host:** 192.168.1.50
   - **Port:** 5432
   - **Database:** myapp_db
   - **Username:** myapp_user
   - **Password:** changeme123
6. Click "Save"

---

### Method 3: Programming from Mac

#### Python

```python
# Install: pip install psycopg2-binary
import psycopg2

conn = psycopg2.connect(
    host="192.168.1.50",
    port=5432,
    database="myapp_db",
    user="myapp_user",
    password="changeme123"
)

cursor = conn.cursor()
cursor.execute("SELECT * FROM users LIMIT 10")
rows = cursor.fetchall()

for row in rows:
    print(row)

conn.close()
```

#### Node.js

```javascript
// Install: npm install pg
const { Client } = require('pg');

const client = new Client({
  host: '192.168.1.50',
  port: 5432,
  database: 'myapp_db',
  user: 'myapp_user',
  password: 'changeme123'
});

async function query() {
  await client.connect();
  const res = await client.query('SELECT * FROM users LIMIT 10');
  console.log(res.rows);
  await client.end();
}

query();
```

#### Go

```go
// Install: go get github.com/lib/pq
package main

import (
    "database/sql"
    "fmt"
    _ "github.com/lib/pq"
)

func main() {
    connStr := "host=192.168.1.50 port=5432 user=myapp_user password=changeme123 dbname=myapp_db sslmode=disable"
    db, err := sql.Open("postgres", connStr)
    if err != nil {
        panic(err)
    }
    defer db.Close()

    rows, err := db.Query("SELECT * FROM users LIMIT 10")
    if err != nil {
        panic(err)
    }
    defer rows.Close()
}
```

---

## Step 4: Test Connection

### Quick Connection Test from Mac

```bash
# Test if port is open
nc -zv 192.168.1.50 5432
# Should output: Connection to 192.168.1.50 port 5432 [tcp/postgresql] succeeded!

# Test with psql
psql -h 192.168.1.50 -p 5432 -U myapp_user -d myapp_db -c "SELECT version();"
```

---

## Using the Scripts from Mac

You can also use the scripts remotely by setting environment variables:

```bash
# Set remote connection details
export DB_HOST=192.168.1.50
export DB_NAME=myapp_db
export DB_USER=myapp_user
export DB_PASSWORD=changeme123

# Now use the scripts
./read_database.sh postgres --list-tables
./read_database.sh postgres --query "SELECT * FROM users"
./create_schema.sh postgres --example users
```

Or specify directly:

```bash
DB_HOST=192.168.1.50 DB_NAME=myapp_db DB_USER=myapp_user DB_PASSWORD=changeme123 \
  ./read_database.sh postgres --list-tables
```

---

## Security Best Practices

### 1. Use SSH Tunnel (Most Secure)

Instead of exposing PostgreSQL to the internet, use SSH tunneling:

```bash
# On your Mac, create SSH tunnel
ssh -L 5432:localhost:5432 user@192.168.1.50

# Now connect to localhost (which tunnels to remote)
psql -h localhost -p 5432 -U myapp_user -d myapp_db
```

**Advantages:**
- PostgreSQL doesn't need to accept remote connections
- Encrypted through SSH
- No need to open firewall port 5432

**Make it permanent with ~/.ssh/config:**

```bash
# Add to ~/.ssh/config
Host db-server
    HostName 192.168.1.50
    User your-linux-username
    LocalForward 5432 localhost:5432

# Now just type:
ssh db-server

# In another terminal:
psql -h localhost -U myapp_user -d myapp_db
```

### 2. Use SSL/TLS

Enable SSL on PostgreSQL server:

```bash
# On Linux server
sudo nano /etc/postgresql/*/main/postgresql.conf

# Enable SSL
ssl = on
ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'

# Restart
sudo systemctl restart postgresql
```

Connect with SSL from Mac:

```bash
psql "postgresql://myapp_user:changeme123@192.168.1.50:5432/myapp_db?sslmode=require"
```

### 3. Restrict IP Addresses

In `pg_hba.conf`, only allow specific IPs:

```bash
# Only allow your Mac's IP
host    all    all    203.0.113.42/32    md5

# Or your office network
host    all    all    192.168.1.0/24     md5
```

### 4. Use Strong Passwords

```bash
# On Linux server, change password
sudo -u postgres psql -d myapp_db -c "ALTER USER myapp_user WITH PASSWORD 'VeryStr0ng!Pass#2026';"
```

### 5. Disable Root Remote Access

In `pg_hba.conf`:

```bash
# Never allow postgres superuser remotely
local   all    postgres    peer
```

---

## Troubleshooting

### Connection Refused

```bash
# Check if PostgreSQL is running on Linux server
sudo systemctl status postgresql

# Check if listening on correct interface
sudo netstat -plnt | grep 5432
# Should show: 0.0.0.0:5432 (not 127.0.0.1:5432)

# Check firewall
sudo ufw status
sudo iptables -L -n | grep 5432
```

### Connection Timeout

- Check if firewall is blocking port 5432
- Check if cloud provider security groups allow port 5432
- Verify server IP is correct

### Authentication Failed

```bash
# Check user exists on Linux server
sudo -u postgres psql -c "\du"

# Reset password
sudo -u postgres psql -c "ALTER USER myapp_user WITH PASSWORD 'newpassword';"

# Check pg_hba.conf has correct auth method (md5 or scram-sha-256)
```

### SSL Error

```bash
# Connect without SSL requirement
psql "postgresql://myapp_user:changeme123@192.168.1.50:5432/myapp_db?sslmode=disable"
```

---

## Quick Reference

### Connection String Format

```
postgresql://[user]:[password]@[host]:[port]/[database]?[params]
```

**Examples:**

```bash
# Basic
postgresql://myapp_user:changeme123@192.168.1.50:5432/myapp_db

# With SSL
postgresql://myapp_user:changeme123@192.168.1.50:5432/myapp_db?sslmode=require

# Through SSH tunnel
postgresql://myapp_user:changeme123@localhost:5432/myapp_db
```

### Environment Variables

```bash
export PGHOST=192.168.1.50
export PGPORT=5432
export PGDATABASE=myapp_db
export PGUSER=myapp_user
export PGPASSWORD=changeme123

# Now just use:
psql
```

### .pgpass File (Password-less Authentication)

```bash
# Create ~/.pgpass on your Mac
echo "192.168.1.50:5432:myapp_db:myapp_user:changeme123" >> ~/.pgpass
chmod 600 ~/.pgpass

# Now connect without password prompt
psql -h 192.168.1.50 -U myapp_user -d myapp_db
```

---

## Summary Checklist

- [ ] Configure PostgreSQL to listen on all interfaces (`listen_addresses = '*'`)
- [ ] Add remote host to `pg_hba.conf`
- [ ] Restart PostgreSQL service
- [ ] Open firewall port 5432
- [ ] Get server IP address
- [ ] Install psql client on Mac (or GUI tool)
- [ ] Test connection
- [ ] Set up SSH tunnel (optional but recommended)
- [ ] Configure SSL (optional but recommended)

**Recommended Approach:** Use SSH tunnel for maximum security!
