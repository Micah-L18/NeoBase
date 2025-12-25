#!/bin/bash
# NeoBase Database Backup Script
# Creates pg_dump backups of PostgreSQL containers

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Error: .env file not found."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BACKUP_DIR=${BACKUP_DIR:-/var/backups/neobase}
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <user_id|all> [backup_label]"
    echo "Examples:"
    echo "  $0 user123                    # Backup single user"
    echo "  $0 all                        # Backup all databases"
    echo "  $0 user123 daily_backup       # Backup with custom label"
    exit 1
fi

USER_ID=$1
BACKUP_LABEL=${2:-"backup"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to backup a single database
backup_database() {
    local user_id=$1
    local container_name="neobase_user_${user_id}_db"
    
    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${RED}Error: Container $container_name is not running${NC}"
        return 1
    fi
    
    # Get database info from connection file
    local connection_file="$SCRIPT_DIR/../.connections/${user_id}.json"
    if [ ! -f "$connection_file" ]; then
        echo -e "${RED}Error: Connection file not found for user $user_id${NC}"
        return 1
    fi
    
    local db_name=$(jq -r '.database' "$connection_file")
    local db_user=$(jq -r '.username' "$connection_file")
    
    # Create backup directory
    local user_backup_dir="$BACKUP_DIR/$user_id"
    mkdir -p "$user_backup_dir"
    
    local backup_file="${user_backup_dir}/${BACKUP_LABEL}_${TIMESTAMP}.sql.gz"
    
    echo -e "${YELLOW}Backing up database for user: $user_id${NC}"
    
    # Perform backup using pg_dump
    docker exec "$container_name" pg_dump -U "$db_user" -d "$db_name" \
        --format=plain \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges | gzip > "$backup_file"
    
    if [ $? -eq 0 ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        echo -e "${GREEN}✓ Backup created: $backup_file ($size)${NC}"
        
        # Create metadata file
        cat > "${backup_file}.meta" << EOF
{
  "user_id": "$user_id",
  "database": "$db_name",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "backup_file": "$backup_file",
  "size": "$size",
  "label": "$BACKUP_LABEL"
}
EOF
        
        return 0
    else
        echo -e "${RED}✗ Backup failed for user: $user_id${NC}"
        return 1
    fi
}

# Function to clean old backups
cleanup_old_backups() {
    echo -e "${YELLOW}Cleaning up backups older than $RETENTION_DAYS days...${NC}"
    
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "*.meta" -mtime +$RETENTION_DAYS -delete
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main execution
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NeoBase Database Backup${NC}"
echo -e "${GREEN}========================================${NC}\n"

mkdir -p "$BACKUP_DIR"

if [ "$USER_ID" == "all" ]; then
    # Backup all databases
    echo -e "${YELLOW}Backing up all databases...${NC}\n"
    
    if [ ! -d "$SCRIPT_DIR/../.connections" ]; then
        echo -e "${RED}Error: No databases found${NC}"
        exit 1
    fi
    
    success_count=0
    fail_count=0
    
    for connection_file in "$SCRIPT_DIR/../.connections"/*.json; do
        if [ -f "$connection_file" ]; then
            user_id=$(basename "$connection_file" .json)
            if backup_database "$user_id"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
            echo ""
        fi
    done
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "Total backups: ${GREEN}$success_count succeeded${NC}, ${RED}$fail_count failed${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    # Backup single database
    backup_database "$USER_ID"
fi

# Cleanup old backups
cleanup_old_backups

echo -e "\n${GREEN}Backup process complete!${NC}"
