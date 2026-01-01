#!/bin/bash

################################################################################
# Remote Database Reader Script
# Connects to and reads from PostgreSQL or MySQL on a remote server
# Usage: ./read_remote_database.sh [IP] [postgres|mysql] [options]
################################################################################

set -e  # Exit on error

# Check if IP is provided
if [ -z "$1" ]; then
    echo "Usage: ./read_remote_database.sh [IP_ADDRESS] [postgres|mysql] [options]"
    echo ""
    echo "Examples:"
    echo "  ./read_remote_database.sh 192.168.1.50 postgres --list-tables"
    echo "  ./read_remote_database.sh 192.168.1.50 postgres --describe users"
    echo "  ./read_remote_database.sh 192.168.1.50 postgres --query \"SELECT * FROM users\""
    echo "  ./read_remote_database.sh 10.0.0.100 mysql --list-tables"
    echo ""
    echo "Environment Variables:"
    echo "  DB_NAME      Database name (default: myapp_db)"
    echo "  DB_USER      Database user (default: myapp_user)"
    echo "  DB_PASSWORD  Database password (default: changeme123)"
    echo "  DB_PORT      Database port (default: 5432 for postgres, 3306 for mysql)"
    exit 1
fi

# Get IP address and database type
REMOTE_IP="$1"
DB_TYPE="${2:-postgres}"
shift 2 || true

# Configuration
DB_NAME="${DB_NAME:-myapp_db}"
DB_USER="${DB_USER:-myapp_user}"
DB_PASSWORD="${DB_PASSWORD:-changeme123}"

# Set port based on database type
if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "postgresql" ]; then
    DB_PORT="${DB_PORT:-5432}"
else
    DB_PORT="${DB_PORT:-3306}"
fi

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

log_data() {
    echo -e "${BLUE}[DATA]${NC} $1"
}

# Show usage
show_usage() {
    cat << EOF
Remote Database Reader Script

Usage: ./read_remote_database.sh [IP_ADDRESS] [postgres|mysql] [options]

Options:
    --list-tables           List all tables in the database
    --describe TABLE        Describe table structure
    --query "SQL"           Execute custom SQL query
    --format [table|csv]    Output format (default: table)
    --help                  Show this help message

Examples:
    # List all tables on remote server
    ./read_remote_database.sh 192.168.1.50 postgres --list-tables
    
    # Describe a table
    ./read_remote_database.sh 192.168.1.50 postgres --describe users
    
    # Execute custom query
    ./read_remote_database.sh 192.168.1.50 postgres --query "SELECT * FROM users LIMIT 10"
    
    # MySQL with CSV output
    ./read_remote_database.sh 10.0.0.100 mysql --query "SELECT * FROM posts" --format csv
    
    # With custom credentials
    DB_NAME=production DB_USER=admin DB_PASSWORD=secret123 \\
      ./read_remote_database.sh 192.168.1.50 postgres --list-tables

Environment Variables:
    DB_NAME      Database name (default: myapp_db)
    DB_USER      Database user (default: myapp_user)
    DB_PASSWORD  Database password (default: changeme123)
    DB_PORT      Database port (default: 5432 for postgres, 3306 for mysql)

EOF
}

# PostgreSQL functions
postgres_list_tables() {
    log_info "Listing tables in PostgreSQL database '$DB_NAME' at $REMOTE_IP..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$REMOTE_IP" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    "
}

postgres_describe_table() {
    local table_name="$1"
    log_info "Describing table '$table_name' in PostgreSQL database '$DB_NAME' at $REMOTE_IP..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$REMOTE_IP" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            column_name,
            data_type,
            character_maximum_length,
            is_nullable,
            column_default
        FROM information_schema.columns
        WHERE table_name = '$table_name'
        ORDER BY ordinal_position;
    "
}

postgres_query() {
    local query="$1"
    local format="${2:-table}"
    
    log_info "Executing query on PostgreSQL database '$DB_NAME' at $REMOTE_IP..."
    
    if [ "$format" = "csv" ]; then
        PGPASSWORD="$DB_PASSWORD" psql -h "$REMOTE_IP" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$query" --csv
    else
        PGPASSWORD="$DB_PASSWORD" psql -h "$REMOTE_IP" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$query"
    fi
}

# MySQL functions
mysql_list_tables() {
    log_info "Listing tables in MySQL database '$DB_NAME' at $REMOTE_IP..."
    mysql -h "$REMOTE_IP" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SHOW TABLES;"
}

mysql_describe_table() {
    local table_name="$1"
    log_info "Describing table '$table_name' in MySQL database '$DB_NAME' at $REMOTE_IP..."
    mysql -h "$REMOTE_IP" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "DESCRIBE $table_name;"
}

mysql_query() {
    local query="$1"
    local format="${2:-table}"
    
    log_info "Executing query on MySQL database '$DB_NAME' at $REMOTE_IP..."
    
    if [ "$format" = "csv" ]; then
        mysql -h "$REMOTE_IP" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "$query" | sed 's/\t/,/g'
    else
        mysql -h "$REMOTE_IP" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "$query"
    fi
}

# Check if database tools are installed
check_dependencies() {
    if [ "$DB_TYPE" = "postgres" ] || [ "$DB_TYPE" = "postgresql" ]; then
        if ! command -v psql &> /dev/null; then
            log_error "psql is not installed. Please install PostgreSQL client."
            echo ""
            echo "Install on macOS: brew install postgresql@15"
            echo "Install on Ubuntu: sudo apt-get install postgresql-client"
            exit 1
        fi
    elif [ "$DB_TYPE" = "mysql" ] || [ "$DB_TYPE" = "mariadb" ]; then
        if ! command -v mysql &> /dev/null; then
            log_error "mysql is not installed. Please install MySQL client."
            echo ""
            echo "Install on macOS: brew install mysql-client"
            echo "Install on Ubuntu: sudo apt-get install mysql-client"
            exit 1
        fi
    else
        log_error "Unknown database type: $DB_TYPE"
        log_error "Supported types: postgres, mysql"
        exit 1
    fi
}

# Test connection to remote server
test_connection() {
    log_info "Testing connection to $REMOTE_IP:$DB_PORT..."
    
    if command -v nc &> /dev/null; then
        if nc -z -w 5 "$REMOTE_IP" "$DB_PORT" 2>/dev/null; then
            log_info "Port $DB_PORT is open on $REMOTE_IP"
        else
            log_warn "Cannot connect to $REMOTE_IP:$DB_PORT"
            log_warn "Make sure:"
            echo "  1. The database server is running"
            echo "  2. Firewall allows port $DB_PORT"
            echo "  3. PostgreSQL/MySQL is configured to accept remote connections"
            echo ""
            echo "See REMOTE_CONNECTION_GUIDE.md for setup instructions"
        fi
    fi
}

# Parse arguments
parse_args() {
    ACTION=""
    TABLE_NAME=""
    QUERY=""
    FORMAT="table"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list-tables)
                ACTION="list-tables"
                shift
                ;;
            --describe)
                ACTION="describe"
                TABLE_NAME="$2"
                shift 2
                ;;
            --query)
                ACTION="query"
                QUERY="$2"
                shift 2
                ;;
            --format)
                FORMAT="$2"
                shift 2
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
    check_dependencies
    
    log_info "Remote Database Reader"
    log_info "======================"
    log_info "Remote Server: $REMOTE_IP:$DB_PORT"
    log_info "Database Type: $DB_TYPE"
    log_info "Database Name: $DB_NAME"
    log_info "Username: $DB_USER"
    log_info ""
    
    test_connection
    
    case "$DB_TYPE" in
        postgres|postgresql)
            case "$ACTION" in
                list-tables)
                    postgres_list_tables
                    ;;
                describe)
                    postgres_describe_table "$TABLE_NAME"
                    ;;
                query)
                    postgres_query "$QUERY" "$FORMAT"
                    ;;
            esac
            ;;
        mysql|mariadb)
            case "$ACTION" in
                list-tables)
                    mysql_list_tables
                    ;;
                describe)
                    mysql_describe_table "$TABLE_NAME"
                    ;;
                query)
                    mysql_query "$QUERY" "$FORMAT"
                    ;;
            esac
            ;;
    esac
}

# Run main function with all arguments
main "$@"
