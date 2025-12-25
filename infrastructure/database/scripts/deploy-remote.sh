#!/bin/bash
# NeoBase Remote Deployment Script
# Deploys database infrastructure to a remote Ubuntu server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
SERVER_USER=$1
SERVER_IP=$2
ACTION=${3:-setup}  # setup, create-db, delete-db, backup, list

if [ -z "$SERVER_USER" ] || [ -z "$SERVER_IP" ]; then
    echo "Usage: $0 <server_user> <server_ip> <action> [action_args...]"
    echo ""
    echo "Actions:"
    echo "  setup                           - Initial server setup"
    echo "  create-db <user_id> <db_name>  - Create new database"
    echo "  delete-db <user_id>             - Delete database"
    echo "  backup <user_id>                - Backup database"
    echo "  list                            - List all databases"
    echo ""
    echo "Example: $0 ubuntu 192.168.1.100 setup"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="~/neobase-db"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}NeoBase Remote Deployment${NC}"
echo -e "${CYAN}========================================${NC}\n"
echo -e "Server: ${YELLOW}$SERVER_USER@$SERVER_IP${NC}"
echo -e "Action: ${YELLOW}$ACTION${NC}\n"

# Function to check SSH connectivity
check_connection() {
    echo -e "${YELLOW}Checking server connection...${NC}"
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$SERVER_USER@$SERVER_IP" "echo 'Connection successful'" &>/dev/null; then
        echo -e "${GREEN}✓ Connected to server${NC}"
        return 0
    else
        echo -e "${RED}✗ Cannot connect to server${NC}"
        echo -e "${YELLOW}Make sure SSH keys are set up or you'll be prompted for password${NC}"
        return 1
    fi
}

# Function to deploy files
deploy_files() {
    echo -e "${YELLOW}Deploying files to server...${NC}"
    
    # Create remote directory
    ssh "$SERVER_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"
    
    # Copy all files
    rsync -av --progress \
        --exclude='.connections' \
        --exclude='.remote-connections' \
        --exclude='.env' \
        --exclude='*.log' \
        --exclude='web-interface' \
        "$SCRIPT_DIR/../" \
        "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/"
    
    # Make scripts executable
    ssh "$SERVER_USER@$SERVER_IP" "chmod +x $REMOTE_DIR/scripts/*.sh"
    
    echo -e "${GREEN}✓ Files deployed${NC}"
}

# Function to run setup
run_setup() {
    echo -e "${YELLOW}Running setup on server...${NC}"
    
    deploy_files
    
    # Copy .env.example if .env doesn't exist
    ssh "$SERVER_USER@$SERVER_IP" << 'EOF'
        cd ~/neobase-db
        if [ ! -f .env ]; then
            cp .env.example .env
            echo "Created .env file"
        fi
EOF
    
    # Run setup script
    ssh -t "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && sudo ./scripts/setup.sh"
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Function to create database
create_database() {
    local user_id=$4
    local db_name=$5
    
    if [ -z "$user_id" ] || [ -z "$db_name" ]; then
        echo -e "${RED}Error: Missing user_id or db_name${NC}"
        echo "Usage: $0 $SERVER_USER $SERVER_IP create-db <user_id> <db_name>"
        exit 1
    fi
    
    echo -e "${YELLOW}Creating database on server...${NC}"
    
    # Run create-db script and capture output
    ssh "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && ./scripts/create-db.sh $user_id $db_name" | tee /tmp/db_create_output.txt
    
    # Download connection file
    mkdir -p "$SCRIPT_DIR/../.remote-connections"
    scp "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/.connections/${user_id}.json" \
        "$SCRIPT_DIR/../.remote-connections/${user_id}_${SERVER_IP}.json" 2>/dev/null || true
    
    echo -e "\n${GREEN}Database created!${NC}"
    echo -e "${YELLOW}Connection info saved to: $SCRIPT_DIR/../.remote-connections/${user_id}_${SERVER_IP}.json${NC}"
    echo -e "\n${CYAN}To connect via SSH tunnel:${NC}"
    echo -e "${YELLOW}ssh -L 5432:localhost:<port> $SERVER_USER@$SERVER_IP${NC}"
}

# Function to delete database
delete_database() {
    local user_id=$4
    
    if [ -z "$user_id" ]; then
        echo -e "${RED}Error: Missing user_id${NC}"
        echo "Usage: $0 $SERVER_USER $SERVER_IP delete-db <user_id>"
        exit 1
    fi
    
    echo -e "${YELLOW}Deleting database on server...${NC}"
    ssh -t "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && ./scripts/delete-db.sh $user_id"
    
    # Remove local connection file
    rm -f "$SCRIPT_DIR/../.remote-connections/${user_id}_${SERVER_IP}.json"
    
    echo -e "${GREEN}Database deleted${NC}"
}

# Function to backup database
backup_database() {
    local user_id=$4
    
    if [ -z "$user_id" ]; then
        echo -e "${RED}Error: Missing user_id${NC}"
        echo "Usage: $0 $SERVER_USER $SERVER_IP backup <user_id>"
        exit 1
    fi
    
    echo -e "${YELLOW}Creating backup on server...${NC}"
    ssh "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && ./scripts/backup.sh $user_id"
    
    echo -e "${GREEN}Backup complete${NC}"
}

# Function to list databases
list_databases() {
    echo -e "${YELLOW}Listing databases on server...${NC}\n"
    ssh "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && ./scripts/list-db.sh"
}

# Main execution
check_connection

case "$ACTION" in
    setup)
        run_setup
        ;;
    create-db)
        create_database "$@"
        ;;
    delete-db)
        delete_database "$@"
        ;;
    backup)
        backup_database "$@"
        ;;
    list)
        list_databases
        ;;
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}✓ Operation complete!${NC}"
