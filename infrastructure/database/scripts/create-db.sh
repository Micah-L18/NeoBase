#!/bin/bash
# NeoBase Database Creation Script
# Creates a new PostgreSQL container for a user

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Error: .env file not found. Copy .env.example to .env and configure."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to find available port
find_available_port() {
    local start=${PORT_RANGE_START:-5432}
    local end=${PORT_RANGE_END:-6432}
    
    for port in $(seq $start $end); do
        if ! nc -z localhost $port 2>/dev/null; then
            echo $port
            return 0
        fi
    done
    
    echo "Error: No available ports in range $start-$end"
    exit 1
}

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <user_id> <database_name>"
    echo "Example: $0 user123 myapp_db"
    exit 1
fi

USER_ID=$1
DB_NAME=$2
DB_USER=${3:-$USER_ID}
DB_PASSWORD=$(generate_password)
HOST_PORT=$(find_available_port)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Creating PostgreSQL Database${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "neobase_user_${USER_ID}_db"; then
    echo -e "${RED}Error: Database container for user $USER_ID already exists${NC}"
    exit 1
fi

# Create environment file for this specific database
DB_ENV_FILE="$SCRIPT_DIR/../.db_${USER_ID}.env"
cat > "$DB_ENV_FILE" << EOF
USER_ID=$USER_ID
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
HOST_PORT=$HOST_PORT
EOF

echo -e "${YELLOW}Creating database container...${NC}"

# Use docker-compose with environment variables
cd "$SCRIPT_DIR/.."
export USER_ID DB_NAME DB_USER DB_PASSWORD HOST_PORT

docker-compose -f docker-compose.template.yml -p "neobase_user_${USER_ID}" up -d

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
for i in {1..30}; do
    if docker exec "neobase_user_${USER_ID}_db" pg_isready -U "$DB_USER" -d "$DB_NAME" &>/dev/null; then
        echo -e "${GREEN}✓ Database is ready${NC}"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo -e "${RED}Error: Database failed to start${NC}"
        exit 1
    fi
    
    sleep 1
done

# Save connection details to a secure file
CONNECTION_FILE="$SCRIPT_DIR/../.connections/${USER_ID}.json"
mkdir -p "$SCRIPT_DIR/../.connections"
chmod 700 "$SCRIPT_DIR/../.connections"

cat > "$CONNECTION_FILE" << EOF
{
  "user_id": "$USER_ID",
  "database": "$DB_NAME",
  "username": "$DB_USER",
  "password": "$DB_PASSWORD",
  "host": "localhost",
  "port": $HOST_PORT,
  "connection_string": "postgresql://$DB_USER:$DB_PASSWORD@localhost:$HOST_PORT/$DB_NAME",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "container_name": "neobase_user_${USER_ID}_db",
  "resources": {
    "cpu_limit": "1.0",
    "memory_limit": "1G"
  }
}
EOF

chmod 600 "$CONNECTION_FILE"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Database Created Successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"
echo -e "User ID:       ${YELLOW}$USER_ID${NC}"
echo -e "Database:      ${YELLOW}$DB_NAME${NC}"
echo -e "Username:      ${YELLOW}$DB_USER${NC}"
echo -e "Password:      ${YELLOW}$DB_PASSWORD${NC}"
echo -e "Port:          ${YELLOW}$HOST_PORT${NC}"
echo -e "Container:     ${YELLOW}neobase_user_${USER_ID}_db${NC}"
echo ""
echo -e "${GREEN}Connection String:${NC}"
echo -e "${YELLOW}postgresql://$DB_USER:$DB_PASSWORD@localhost:$HOST_PORT/$DB_NAME${NC}"
echo ""
echo -e "${YELLOW}⚠ Connection details saved to: $CONNECTION_FILE${NC}"
echo -e "${YELLOW}⚠ Keep this information secure!${NC}"
