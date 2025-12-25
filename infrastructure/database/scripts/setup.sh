#!/bin/bash
# NeoBase Database Infrastructure Setup Script for Ubuntu Server
# This script prepares an Ubuntu server to host PostgreSQL containers

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NeoBase Database Infrastructure Setup${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (use sudo)${NC}"
    exit 1
fi

# Update system packages
echo -e "${YELLOW}[1/7] Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

# Install required dependencies
echo -e "${YELLOW}[2/7] Installing dependencies...${NC}"
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    netcat-openbsd

# Install Docker
echo -e "${YELLOW}[3/7] Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    echo -e "${GREEN}✓ Docker installed successfully${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Install Docker Compose (standalone)
echo -e "${YELLOW}[4/7] Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓ Docker Compose installed successfully${NC}"
else
    echo -e "${GREEN}✓ Docker Compose already installed${NC}"
fi

# Create Docker network for NeoBase
echo -e "${YELLOW}[5/7] Creating Docker network...${NC}"
if ! docker network ls | grep -q neobase_network; then
    docker network create --driver bridge --subnet 172.20.0.0/16 neobase_network
    echo -e "${GREEN}✓ Network 'neobase_network' created${NC}"
else
    echo -e "${GREEN}✓ Network 'neobase_network' already exists${NC}"
fi

# Create directories for data and backups
echo -e "${YELLOW}[6/7] Creating storage directories...${NC}"
mkdir -p /var/lib/neobase/data
mkdir -p /var/backups/neobase
chmod 750 /var/lib/neobase/data
chmod 750 /var/backups/neobase

echo -e "${GREEN}✓ Storage directories created${NC}"

# Configure firewall (UFW)
echo -e "${YELLOW}[7/7] Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    # Allow SSH
    ufw allow 22/tcp
    
    # Allow PostgreSQL port range (5432-6432)
    ufw allow 5432:6432/tcp
    
    # Enable firewall if not already enabled
    echo "y" | ufw enable || true
    
    echo -e "${GREEN}✓ Firewall configured${NC}"
else
    echo -e "${YELLOW}⚠ UFW not installed, skipping firewall configuration${NC}"
fi

# Display versions
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy .env.example to .env and configure settings"
echo "2. Use ./create-db.sh to provision new databases"
echo "3. Use ./backup.sh to set up automated backups"
echo ""
echo -e "${GREEN}Setup completed successfully!${NC}"
