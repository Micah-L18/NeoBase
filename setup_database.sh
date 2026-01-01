#!/bin/bash

################################################################################
# SQL Database Setup Script
# Supports: PostgreSQL and MySQL/MariaDB
# Usage: ./setup_database.sh [postgres|mysql]
################################################################################

set -e  # Exit on error

# Configuration
DB_TYPE="${1:-postgres}"  # Default to PostgreSQL
DB_NAME="${DB_NAME:-myapp_db}"
DB_USER="${DB_USER:-myapp_user}"
DB_PASSWORD="${DB_PASSWORD:-changeme123}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT_POSTGRES="${DB_PORT_POSTGRES:-5432}"
DB_PORT_MYSQL="${DB_PORT_MYSQL:-3306}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# PostgreSQL Setup
setup_postgresql() {
    log_info "Setting up PostgreSQL database..."
    
    # Check if PostgreSQL is installed
    if ! command -v psql &> /dev/null; then
        log_error "PostgreSQL is not installed. Installing..."
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
    fi
    
    # Start PostgreSQL service
    log_info "Starting PostgreSQL service..."
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    # Create database and user
    log_info "Creating database '$DB_NAME' and user '$DB_USER'..."
    sudo -u postgres psql <<EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE $DB_NAME'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

\c $DB_NAME

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
EOF
    
    log_info "PostgreSQL setup complete!"
    log_info "Connection string: postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT_POSTGRES/$DB_NAME"
}

# MySQL/MariaDB Setup
setup_mysql() {
    log_info "Setting up MySQL/MariaDB database..."
    
    # Check if MySQL is installed
    if ! command -v mysql &> /dev/null; then
        log_error "MySQL is not installed. Installing..."
        sudo apt-get update
        sudo apt-get install -y mysql-server
    fi
    
    # Start MySQL service
    log_info "Starting MySQL service..."
    sudo systemctl start mysql
    sudo systemctl enable mysql
    
    # Create database and user
    log_info "Creating database '$DB_NAME' and user '$DB_USER'..."
    sudo mysql <<EOF
-- Create database if not exists
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user if not exists
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';

-- Grant privileges
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';

-- Apply changes
FLUSH PRIVILEGES;
EOF
    
    log_info "MySQL setup complete!"
    log_info "Connection string: mysql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT_MYSQL/$DB_NAME"
}

# Main execution
main() {
    log_info "SQL Database Setup Script"
    log_info "=========================="
    log_info "Database Type: $DB_TYPE"
    log_info "Database Name: $DB_NAME"
    log_info "Database User: $DB_USER"
    log_info ""
    
    case "$DB_TYPE" in
        postgres|postgresql)
            setup_postgresql
            ;;
        mysql|mariadb)
            setup_mysql
            ;;
        *)
            log_error "Unknown database type: $DB_TYPE"
            log_error "Supported types: postgres, mysql"
            exit 1
            ;;
    esac
    
    log_info ""
    log_info "Setup completed successfully!"
}

# Run main function
main
