#!/bin/bash

################################################################################
# Database Schema Creator Script (Shell version)
# Creates table schemas in PostgreSQL or MySQL databases
# Usage: ./create_schema.sh [postgres|mysql] [options]
################################################################################

set -e  # Exit on error

# Configuration
DB_TYPE="${1:-postgres}"
shift || true  # Remove first argument, continue if no more args

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
BLUE='\033[0;34m'
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

log_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
}

# Show usage
show_usage() {
    cat << EOF
Database Schema Creator Script (Shell version)

Usage: ./create_schema.sh [postgres|mysql] [options]

Options:
    --schema FILE           Create schema from SQL file
    --example TABLES        Create example tables (comma-separated: users,posts,comments)
    --generate-example      Generate example schema SQL to stdout
    --help                  Show this help message

Examples:
    # Create schema from file
    ./create_schema.sh postgres --schema example_schema.sql
    
    # Create example tables
    ./create_schema.sh postgres --example users,posts,comments
    
    # Generate example schema
    ./create_schema.sh mysql --generate-example > my_schema.sql
    
    # Single example table
    ./create_schema.sh postgres --example users

Environment Variables:
    DB_NAME      Database name (default: myapp_db)
    DB_USER      Database user (default: myapp_user)
    DB_PASSWORD  Database password (default: changeme123)
    DB_HOST      Database host (default: localhost)
    DB_PORT_POSTGRES  PostgreSQL port (default: 5432)
    DB_PORT_MYSQL     MySQL port (default: 3306)

EOF
}

# Generate PostgreSQL example schemas
generate_postgres_users() {
    cat << 'EOF'
-- Users table (PostgreSQL)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
EOF
}

generate_postgres_posts() {
    cat << 'EOF'
-- Posts table (PostgreSQL)
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    status VARCHAR(20) DEFAULT 'draft',
    published_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_published_at ON posts(published_at);
EOF
}

generate_postgres_comments() {
    cat << 'EOF'
-- Comments table (PostgreSQL)
CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    parent_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON comments(parent_id);
EOF
}

# Generate MySQL example schemas
generate_mysql_users() {
    cat << 'EOF'
-- Users table (MySQL)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_email (email),
    INDEX idx_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF
}

generate_mysql_posts() {
    cat << 'EOF'
-- Posts table (MySQL)
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    status VARCHAR(20) DEFAULT 'draft',
    published_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_posts_user_id (user_id),
    INDEX idx_posts_status (status),
    INDEX idx_posts_published_at (published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF
}

generate_mysql_comments() {
    cat << 'EOF'
-- Comments table (MySQL)
CREATE TABLE IF NOT EXISTS comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    parent_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE,
    INDEX idx_comments_post_id (post_id),
    INDEX idx_comments_user_id (user_id),
    INDEX idx_comments_parent_id (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF
}

# Execute SQL for PostgreSQL
postgres_execute_sql() {
    local sql="$1"
    log_info "Executing SQL on PostgreSQL database '$DB_NAME'..."
    echo "$sql" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT_POSTGRES" -U "$DB_USER" -d "$DB_NAME"
    
    if [ $? -eq 0 ]; then
        log_success "Schema created successfully!"
    else
        log_error "Failed to create schema"
        exit 1
    fi
}

# Execute SQL for MySQL
mysql_execute_sql() {
    local sql="$1"
    log_info "Executing SQL on MySQL database '$DB_NAME'..."
    echo "$sql" | mysql -h "$DB_HOST" -P "$DB_PORT_MYSQL" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
    
    if [ $? -eq 0 ]; then
        log_success "Schema created successfully!"
    else
        log_error "Failed to create schema"
        exit 1
    fi
}

# Check if database tools are installed
check_dependencies() {
    if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "postgresql" ]; then
        if ! command -v psql &> /dev/null; then
            log_error "psql is not installed. Please install PostgreSQL client."
            exit 1
        fi
    elif [ "$DB_TYPE" = "mysql" ] || [ "$DB_TYPE" = "mariadb" ]; then
        if ! command -v mysql &> /dev/null; then
            log_error "mysql is not installed. Please install MySQL client."
            exit 1
        fi
    else
        log_error "Unknown database type: $DB_TYPE"
        log_error "Supported types: postgres, mysql"
        exit 1
    fi
}

# Generate example schema
generate_example() {
    echo "-- Example Database Schema for ${DB_TYPE^^}"
    echo "-- Generated on $(date)"
    echo ""
    
    if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "postgresql" ]; then
        generate_postgres_users
        echo ""
        generate_postgres_posts
        echo ""
        generate_postgres_comments
    else
        generate_mysql_users
        echo ""
        generate_mysql_posts
        echo ""
        generate_mysql_comments
    fi
}

# Create example tables
create_example_tables() {
    local tables="$1"
    IFS=',' read -ra TABLE_ARRAY <<< "$tables"
    
    for table in "${TABLE_ARRAY[@]}"; do
        table=$(echo "$table" | xargs)  # Trim whitespace
        
        log_info "Creating example table: $table"
        
        local sql=""
        if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "postgresql" ]; then
            case "$table" in
                users)
                    sql=$(generate_postgres_users)
                    ;;
                posts)
                    sql=$(generate_postgres_posts)
                    ;;
                comments)
                    sql=$(generate_postgres_comments)
                    ;;
                *)
                    log_warn "Unknown table: $table (supported: users, posts, comments)"
                    continue
                    ;;
            esac
            postgres_execute_sql "$sql"
        else
            case "$table" in
                users)
                    sql=$(generate_mysql_users)
                    ;;
                posts)
                    sql=$(generate_mysql_posts)
                    ;;
                comments)
                    sql=$(generate_mysql_comments)
                    ;;
                *)
                    log_warn "Unknown table: $table (supported: users, posts, comments)"
                    continue
                    ;;
            esac
            mysql_execute_sql "$sql"
        fi
    done
}

# Parse arguments
parse_args() {
    ACTION=""
    SCHEMA_FILE=""
    EXAMPLE_TABLES=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --schema)
                ACTION="schema"
                SCHEMA_FILE="$2"
                shift 2
                ;;
            --example)
                ACTION="example"
                EXAMPLE_TABLES="$2"
                shift 2
                ;;
            --generate-example)
                ACTION="generate"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [ -z "$ACTION" ]; then
        log_error "No action specified"
        show_usage
        exit 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    # Handle generate without checking dependencies or connection
    if [ "$ACTION" = "generate" ]; then
        generate_example
        exit 0
    fi
    
    check_dependencies
    
    log_info "Database Schema Creator"
    log_info "======================="
    log_info "Database Type: $DB_TYPE"
    log_info "Database Name: $DB_NAME"
    log_info ""
    
    case "$ACTION" in
        schema)
            if [ ! -f "$SCHEMA_FILE" ]; then
                log_error "Schema file not found: $SCHEMA_FILE"
                exit 1
            fi
            
            log_info "Creating schema from file: $SCHEMA_FILE"
            local sql=$(cat "$SCHEMA_FILE")
            
            if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "postgresql" ]; then
                postgres_execute_sql "$sql"
            else
                mysql_execute_sql "$sql"
            fi
            ;;
        example)
            create_example_tables "$EXAMPLE_TABLES"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
