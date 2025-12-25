#!/bin/bash
# NeoBase Database List Script
# Lists all active PostgreSQL containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Active NeoBase Databases${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Check if connections directory exists
if [ ! -d "$SCRIPT_DIR/../.connections" ]; then
    echo -e "${YELLOW}No databases found${NC}"
    exit 0
fi

# Count databases
db_count=$(ls -1 "$SCRIPT_DIR/../.connections"/*.json 2>/dev/null | wc -l)

if [ "$db_count" -eq 0 ]; then
    echo -e "${YELLOW}No databases found${NC}"
    exit 0
fi

echo -e "${CYAN}Total databases: $db_count${NC}\n"

# List each database
printf "%-15s %-20s %-15s %-8s %-12s\n" "USER_ID" "DATABASE" "CONTAINER" "PORT" "STATUS"
echo "--------------------------------------------------------------------------------"

for connection_file in "$SCRIPT_DIR/../.connections"/*.json; do
    if [ -f "$connection_file" ]; then
        user_id=$(jq -r '.user_id' "$connection_file")
        database=$(jq -r '.database' "$connection_file")
        container=$(jq -r '.container_name' "$connection_file")
        port=$(jq -r '.port' "$connection_file")
        
        # Check container status
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            status="${GREEN}running${NC}"
        elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            status="${YELLOW}stopped${NC}"
        else
            status="${RED}missing${NC}"
        fi
        
        printf "%-15s %-20s %-15s %-8s " "$user_id" "$database" "${container:12:15}" "$port"
        echo -e "$status"
    fi
done

echo ""
