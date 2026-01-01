#!/bin/bash

################################################################################
# Database Reader Script (Shell version)
# Reads and queries PostgreSQL or MySQL databases
# Usage: ./read_database.sh [postgres|mysql] [options]
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

log_data() {
    echo -e "${BLUE}[DATA]${NC} $1"
}

# Show usage
show_usage() {
    cat << EOF
Database Reader Script (Shell version)

Usage: ./read_database.sh [postgres|mysql] [options]

Options:
    --list-tables           List all tables in the database
    --describe TABLE        Describe table structure
    --query "SQL"           Execute custom SQL query
    --format [table|csv]    Output format (default: table)
    --help                  Show this help message

Examples:
    # List all tables
    ./read_database.sh postgres --list-tables
    
    # Describe a table
    ./read_database.sh postgres --describe users
    
    # Execute custom query
    ./read_database.sh postgres --query "SELECT * FROM users LIMIT 10"
    
    # MySQL with CSV output
    ./read_database.sh mysql --query "SELECT * FROM posts" --format csv

Environment Variables:
    DB_NAME      Database name (default: myapp_db)
    DB_USER      Database user (default: myapp_user)
    DB_PASSWORD  Database password (default: changeme123)
    DB_HOST      Database host (default: localhost)
    DB_PORT_POSTGRES  PostgreSQL port (default: 5432)
    DB_PORT_MYSQL     MySQL port (default: 3306)

EOF
}

# PostgreSQL functions
postgres_list_tables() {
    log_info "Listing tables in PostgreSQL database '$DB_NAME'..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT_POSTGRES" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    "
}

postgres_describe_table() {
    local table_name="$1"
    log_info "Describing table '$table_name' in PostgreSQL database '$DB_NAME'..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT_POSTGRES" -U "$DB_USER" -d "$DB_NAME" -c "
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
    
    if [ "$format" = "csv" ]; then
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT_POSTGRES" -U "$DB_USER" -d "$DB_NAME" -c "$query" --csv
    else
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT_POSTGRES" -U "$DB_USER" -d "$DB_NAME" -c "$query"
    fi
}

# MySQL functions
mysql_list_tables() {
    log_info "Listing tables in MySQL database '$DB_NAME'..."
    mysql -h "$DB_HOST" -P "$DB_PORT_MYSQL" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SHOW TABLES;"
}

mysql_describe_table() {
    local table_name="$1"
    log_info "Describing table '$table_name' in MySQL database '$DB_NAME'..."
    mysql -h "$DB_HOST" -P "$DB_PORT_MYSQL" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "DESCRIBE $table_name;"
}

mysql_query() {
    local query="$1"
    local format="${2:-table}"
    
    if [ "$format" = "csv" ]; then
        mysql -h "$DB_HOST" -P "$DB_PORT_MYSQL" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "$query" | sed 's/\t/,/g'
    else
        mysql -h "$DB_HOST" -P "$DB_PORT_MYSQL" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "$query"
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
    
    log_info "Database Reader"
    log_info "==============="
    log_info "Database Type: $DB_TYPE"
    log_info "Database Name: $DB_NAME"
    log_info ""
    
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
