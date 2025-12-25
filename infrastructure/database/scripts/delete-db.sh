#!/bin/bash
# NeoBase Database Deletion Script
# Removes a PostgreSQL container and its data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <user_id> [--keep-backup]"
    echo "Example: $0 user123"
    echo ""
    echo "Options:"
    echo "  --keep-backup    Keep a final backup before deletion"
    exit 1
fi

USER_ID=$1
KEEP_BACKUP=false

if [ "$2" == "--keep-backup" ]; then
    KEEP_BACKUP=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="neobase_user_${USER_ID}_db"
VOLUME_NAME="neobase_user_${USER_ID}_data"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Database Deletion${NC}"
echo -e "${YELLOW}========================================${NC}\n"

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
    echo -e "${RED}Error: Database container for user $USER_ID does not exist${NC}"
    exit 1
fi

# Confirm deletion
echo -e "${RED}WARNING: This will permanently delete the database for user $USER_ID${NC}"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Deletion cancelled${NC}"
    exit 0
fi

# Create backup if requested
if [ "$KEEP_BACKUP" = true ]; then
    echo -e "${YELLOW}Creating final backup...${NC}"
    "$SCRIPT_DIR/backup.sh" "$USER_ID" "final_backup"
    echo -e "${GREEN}✓ Backup created${NC}"
fi

# Stop and remove container
echo -e "${YELLOW}Stopping container...${NC}"
docker stop "$CONTAINER_NAME" 2>/dev/null || true
echo -e "${GREEN}✓ Container stopped${NC}"

echo -e "${YELLOW}Removing container...${NC}"
docker rm "$CONTAINER_NAME" 2>/dev/null || true
echo -e "${GREEN}✓ Container removed${NC}"

# Remove volume
echo -e "${YELLOW}Removing data volume...${NC}"
docker volume rm "$VOLUME_NAME" 2>/dev/null || true
echo -e "${GREEN}✓ Volume removed${NC}"

# Clean up environment and connection files
ENV_FILE="$SCRIPT_DIR/../.db_${USER_ID}.env"
CONNECTION_FILE="$SCRIPT_DIR/../.connections/${USER_ID}.json"

[ -f "$ENV_FILE" ] && rm "$ENV_FILE" && echo -e "${GREEN}✓ Environment file removed${NC}"
[ -f "$CONNECTION_FILE" ] && rm "$CONNECTION_FILE" && echo -e "${GREEN}✓ Connection file removed${NC}"

# Remove from docker-compose
cd "$SCRIPT_DIR/.."
docker-compose -f docker-compose.template.yml -p "neobase_user_${USER_ID}" down 2>/dev/null || true

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Database Deleted Successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"
echo -e "User ID: ${YELLOW}$USER_ID${NC}"

if [ "$KEEP_BACKUP" = true ]; then
    echo -e "${YELLOW}Final backup available in: /var/backups/neobase/${NC}"
fi
