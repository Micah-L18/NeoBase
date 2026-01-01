# SQL Database Setup Scripts

Programmatic scripts to build and configure SQL databases on Linux servers. Supports both PostgreSQL and MySQL/MariaDB with full CRUD operations.

## Features

- ✅ Automated database installation (if not already installed)
- ✅ Database and user creation
- ✅ Proper privilege configuration
- ✅ Schema creation and management
- ✅ Database reading and querying
- ✅ Support for PostgreSQL and MySQL/MariaDB
- ✅ Environment variable configuration
- ✅ Both Bash and Python implementations

## 📁 Available Scripts

| Script | Purpose | Dependencies |
|--------|---------|--------------|
| `setup_database.sh` | Setup database system | `sudo`, `apt-get` |
| `setup_database.py` | Setup database (Python) | Python 3.6+ |
| `create_schema.sh` | Create table schemas | `psql` or `mysql` client |
| `create_schema.py` | Create schemas (Python) | `psycopg2-binary` or `mysql-connector-python` |
| `read_database.sh` | Query and read data | `psql` or `mysql` client |
| `read_database.py` | Query data (Python) | `psycopg2-binary` or `mysql-connector-python` |

---

## 🐘 PostgreSQL Complete Guide

### Step 1: Install PostgreSQL on Linux

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib

# Start and enable service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify installation
psql --version
```

### Step 2: Setup Database with Scripts

```bash
# Clone or download these scripts
cd /path/to/NeoBase

# Make scripts executable
chmod +x *.sh *.py

# Setup PostgreSQL database (automated)
./setup_database.sh postgres

# Or with custom credentials
DB_NAME=myappdb DB_USER=myuser DB_PASSWORD=SecurePass123 ./setup_database.sh postgres
```

**Output Example:**
```
[INFO] SQL Database Setup Script
[INFO] ==========================
[INFO] Database Type: postgres
[INFO] Database Name: myapp_db
[INFO] Database User: myapp_user

[INFO] PostgreSQL setup complete!
[INFO] Connection string: postgresql://myapp_user:changeme123@localhost:5432/myapp_db
```

### Step 3: Create Database Schema

**Option A - Use Example Schemas:**
```bash
# Create all example tables (users, posts, comments)
./create_schema.sh postgres --example users,posts,comments

# Or create just one table
./create_schema.sh postgres --example users
```

**Option B - Use Custom SQL File:**
```bash
# Create your own schema file
cat > my_schema.sql << 'EOF'
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

# Apply the schema
./create_schema.sh postgres --schema my_schema.sql
```

**Option C - Generate Template:**
```bash
# Generate example schema to customize
./create_schema.sh postgres --generate-example > my_custom_schema.sql

# Edit the file, then apply it
./create_schema.sh postgres --schema my_custom_schema.sql
```

### Step 4: Read and Query Database

**List Tables:**
```bash
./read_database.sh postgres --list-tables
```

**Describe Table Structure:**
```bash
./read_database.sh postgres --describe users
```

**Execute Queries:**
```bash
# Simple SELECT
./read_database.sh postgres --query "SELECT * FROM users LIMIT 10"

# Complex query with JOIN
./read_database.sh postgres --query "
SELECT u.username, COUNT(p.id) as post_count 
FROM users u 
LEFT JOIN posts p ON u.id = p.user_id 
GROUP BY u.username
"

# Export to CSV
./read_database.sh postgres --query "SELECT * FROM users" --format csv > users.csv
```

### Step 5: Insert Sample Data

```bash
# Insert data directly
./read_database.sh postgres --query "
INSERT INTO users (username, email, password_hash, first_name, last_name) 
VALUES ('johndoe', 'john@example.com', 'hashed_password', 'John', 'Doe')
"

# Insert multiple rows
./read_database.sh postgres --query "
INSERT INTO users (username, email, password_hash, first_name, last_name) 
VALUES 
  ('janedoe', 'jane@example.com', 'hashed_pass', 'Jane', 'Doe'),
  ('bobsmith', 'bob@example.com', 'hashed_pass', 'Bob', 'Smith')
"

# Verify insertion
./read_database.sh postgres --query "SELECT * FROM users"
```

### PostgreSQL Manual Commands

If you prefer direct PostgreSQL access:

```bash
# Connect as postgres user
sudo -u postgres psql

# Connect to specific database
psql -U myapp_user -d myapp_db -h localhost

# List databases
psql -U postgres -c "\l"

# List tables in a database
psql -U myapp_user -d myapp_db -c "\dt"

# Backup database
pg_dump -U myapp_user myapp_db > backup.sql

# Restore database
psql -U myapp_user myapp_db < backup.sql
```

### PostgreSQL Connection Examples

**Python with psycopg2:**
```python
import psycopg2

conn = psycopg2.connect(
    dbname="myapp_db",
    user="myapp_user",
    password="changeme123",
    host="localhost",
    port="5432"
)
cursor = conn.cursor()
cursor.execute("SELECT * FROM users")
rows = cursor.fetchall()
```

**Node.js with pg:**
```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  database: 'myapp_db',
  user: 'myapp_user',
  password: 'changeme123'
});

await client.connect();
const res = await client.query('SELECT * FROM users');
```

**Connection URL Format:**
```
postgresql://myapp_user:changeme123@localhost:5432/myapp_db
```

---

## Quick Start (All Databases)

### Bash Script

```bash
# Make executable
chmod +x setup_database.sh

# Setup PostgreSQL (default)
./setup_database.sh postgres

# Setup MySQL
./setup_database.sh mysql

# With custom environment variables
DB_NAME=mydb DB_USER=admin DB_PASSWORD=secret123 ./setup_database.sh postgres
```

### Python Script

```bash
# Setup PostgreSQL (default)
python3 setup_database.py --type postgres

# Setup MySQL with custom parameters
python3 setup_database.py --type mysql --name mydb --user admin --password secret123

# Using environment variables
export DB_NAME=mydb
export DB_USER=admin
export DB_PASSWORD=secret123
python3 setup_database.py --type postgres
```

## Configuration

Both scripts support configuration via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_NAME` | `myapp_db` | Database name |
| `DB_USER` | `myapp_user` | Database user |
| `DB_PASSWORD` | `changeme123` | Database password |
| `DB_HOST` | `localhost` | Database host |
| `DB_PORT` | `5432` (postgres) / `3306` (mysql) | Database port |

## Requirements

### System Requirements
- Linux server (Ubuntu/Debian recommended)
- `sudo` access
- Internet connection (for package installation)

### PostgreSQL
- The script will automatically install PostgreSQL if not present
- Requires `apt-get` package manager

### MySQL/MariaDB
- The script will automatically install MySQL if not present
- Requires `apt-get` package manager

### Python (for Python script)
- Python 3.6 or higher

## What the Scripts Do

1. **Check Installation**: Verify if the database system is installed
2. **Install if Needed**: Automatically install the database system using apt-get
3. **Start Service**: Ensure the database service is running and enabled
4. **Create Database**: Create the specified database if it doesn't exist
5. **Create User**: Create a database user with the specified credentials
6. **Grant Privileges**: Configure appropriate permissions for the user
7. **Output Connection String**: Display the connection string for your application

## Usage Examples

### PostgreSQL Example

```bash
# Basic setup
./setup_database.sh postgres

# Custom configuration
DB_NAME=production_db \
DB_USER=prod_user \
DB_PASSWORD=SecurePass123! \
./setup_database.sh postgres

# Output:
# Connection string: postgresql://prod_user:SecurePass123!@localhost:5432/production_db
```

### MySQL Example

```bash
# Basic setup
./setup_database.sh mysql

# With Python script
python3 setup_database.py --type mysql --name webapp --user webuser --password WebPass456
```

## Connection Strings

After successful setup, you'll receive a connection string:

**PostgreSQL:**
```
postgresql://myapp_user:changeme123@localhost:5432/myapp_db
```

**MySQL:**
```
mysql://myapp_user:changeme123@localhost:3306/myapp_db
```

Use these connection strings in your applications to connect to the database.

## Security Notes

⚠️ **Important Security Considerations:**

1. **Change Default Passwords**: Always use strong, unique passwords in production
2. **Restrict Access**: Configure firewall rules to restrict database access
3. **Use SSL/TLS**: Enable encrypted connections for production databases
4. **Environment Variables**: Store sensitive credentials in environment variables or secret management systems
5. **User Privileges**: Follow the principle of least privilege - grant only necessary permissions

## Troubleshooting

### Permission Denied
```bash
# Ensure scripts are executable
chmod +x *.sh *.py
```

### PostgreSQL Connection Issues
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log

# Check if port is listening
sudo netstat -plnt | grep 5432

# Test connection
psql -U myapp_user -d myapp_db -h localhost -c "SELECT version();"

# Reset postgres user password if needed
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'newpassword';"
```

### MySQL Connection Issues
```bash
# Check if MySQL is running
sudo systemctl status mysql

# Check MySQL logs
sudo tail -f /var/log/mysql/error.log

# Check if port is listening
sudo netstat -plnt | grep 3306

# Reset MySQL root password if needed
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpassword';"
```

### Python Dependencies Issues
```bash
# Install PostgreSQL Python driver
pip install psycopg2-binary

# If psycopg2-binary fails, install build dependencies
sudo apt-get install python3-dev libpq-dev
pip install psycopg2

# Install MySQL Python driver
pip install mysql-connector-python
```

### "psql: command not found" or "mysql: command not found"
```bash
# Install PostgreSQL client only (without server)
sudo apt-get install postgresql-client

# Install MySQL client only (without server)
sudo apt-get install mysql-client
```

### Installation Fails
```bash
# Update package lists
sudo apt-get update

# Install manually
sudo apt-get install postgresql  # or mysql-server

# Check available versions
apt-cache policy postgresql
```

### Database Already Exists Error
```bash
# This is usually safe to ignore - the script checks for existing databases
# To drop and recreate (WARNING: deletes all data):

# PostgreSQL
sudo -u postgres psql -c "DROP DATABASE myapp_db;"

# MySQL
sudo mysql -e "DROP DATABASE myapp_db;"

# Then run setup again
./setup_database.sh postgres
```

## Advanced Usage

### Creating Tables After Setup

Once the database is created, you can add tables using SQL migration files:

```bash
# PostgreSQL
psql -U myapp_user -d myapp_db -f schema.sql

# MySQL
mysql -u myapp_user -p myapp_db < schema.sql
```

### Remote Access

To enable remote access, you'll need to:

1. **PostgreSQL**: Edit `/etc/postgresql/*/main/postgresql.conf` and `pg_hba.conf`
2. **MySQL**: Edit `/etc/mysql/mysql.conf.d/mysqld.cnf` and grant remote user privileges

### Docker Alternative

If you prefer Docker:

```bash
# PostgreSQL
docker run --name postgres-db -e POSTGRES_PASSWORD=changeme123 -p 5432:5432 -d postgres

# MySQL
docker run --name mysql-db -e MYSQL_ROOT_PASSWORD=changeme123 -p 3306:3306 -d mysql
```

## Reading from the Database

### Shell Script Version (No Python Required)

Use [read_database.sh](read_database.sh) to query and read data:

```bash
# List all tables
./read_database.sh postgres --list-tables

# Describe a table structure
./read_database.sh postgres --describe users

# Execute custom query
./read_database.sh postgres --query "SELECT * FROM users LIMIT 10"

# CSV output
./read_database.sh mysql --query "SELECT * FROM posts" --format csv
```

### Python Version

Use [read_database.py](read_database.py) for more features:

```bash
# Install required dependencies first
pip install psycopg2-binary  # For PostgreSQL
pip install mysql-connector-python  # For MySQL

# List all tables
python3 read_database.py --type postgres --list-tables

# Describe a table structure
python3 read_database.py --type postgres --describe users

# Execute custom query with JSON output
python3 read_database.py --type postgres --query "SELECT * FROM users LIMIT 10" --format json
```

## Creating Table Schemas

### Shell Script Version (No Python Required)

Use [create_schema.sh](create_schema.sh) to create table schemas:

```bash
# Create schema from SQL file
./create_schema.sh postgres --schema example_schema.sql

# Create built-in example tables (users, posts, comments)
./create_schema.sh postgres --example users,posts,comments

# Generate example schema SQL
./create_schema.sh mysql --generate-example > my_schema.sql

# Single table
./create_schema.sh postgres --example users
```

### Python Version

Use [create_schema.py](create_schema.py) for the same functionality:

```bash
# Install dependencies first
pip install psycopg2-binary mysql-connector-python

# Create schema from SQL file
python3 create_schema.py --type postgres --schema example_schema.sql

# Create built-in example tables
python3 create_schema.py --type postgres --example users,posts,comments
```

The scripts include pre-built schemas for:
- **users** - User authentication and profiles
- **posts** - Blog posts or content
- **comments** - Threaded comments with parent references

## Complete Workflow Example

### Using Shell Scripts (Recommended - No Dependencies)

```bash
# 1. Setup database
./setup_database.sh postgres

# 2. Create tables
./create_schema.sh postgres --example users,posts,comments

# 3. List tables to verify
./read_database.sh postgres --list-tables

# 4. Describe table structure
./read_database.sh postgres --describe users

# 5. Query data
./read_database.sh postgres --query "SELECT * FROM users"
```

### Using Python Scripts

```bash
# 1. Setup database
./setup_database.sh postgres

# 2. Create tables
python3 create_schema.py --type postgres --example users,posts,comments

# 3. List tables to verify
python3 read_database.py --type postgres --list-tables

# 4. Describe table structure
python3 read_database.py --type postgres --describe users

# 5. Query data
python3 read_database.py --type postgres --query "SELECT * FROM users"
```

## License

MIT License - Feel free to use and modify for your needs.

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests.
