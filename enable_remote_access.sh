#!/bin/bash

################################################################################
# Enable Remote Access for PostgreSQL
# Run this script ON THE LINUX SERVER to allow remote connections
# Usage: sudo ./enable_remote_access.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "PostgreSQL Remote Access Enabler"
log_info "=================================="
echo ""

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    log_error "PostgreSQL is not installed"
    exit 1
fi

log_success "PostgreSQL is installed"

# Find PostgreSQL config files
log_info "Locating PostgreSQL configuration files..."

POSTGRESQL_CONF=$(sudo -u postgres psql -t -c "SHOW config_file;" 2>/dev/null | xargs)
if [ -z "$POSTGRESQL_CONF" ]; then
    # Try common locations
    for conf in /etc/postgresql/*/main/postgresql.conf; do
        if [ -f "$conf" ]; then
            POSTGRESQL_CONF="$conf"
            break
        fi
    done
fi

if [ -z "$POSTGRESQL_CONF" ] || [ ! -f "$POSTGRESQL_CONF" ]; then
    log_error "Could not find postgresql.conf"
    exit 1
fi

PG_HBA_CONF=$(dirname "$POSTGRESQL_CONF")/pg_hba.conf
if [ ! -f "$PG_HBA_CONF" ]; then
    log_error "Could not find pg_hba.conf at $PG_HBA_CONF"
    exit 1
fi

log_success "Found configuration files:"
echo "  postgresql.conf: $POSTGRESQL_CONF"
echo "  pg_hba.conf: $PG_HBA_CONF"
echo ""

# Backup configuration files
log_info "Creating backup of configuration files..."
cp "$POSTGRESQL_CONF" "${POSTGRESQL_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$PG_HBA_CONF" "${PG_HBA_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
log_success "Backup created"

# Step 1: Configure postgresql.conf to listen on all interfaces
log_info "Configuring PostgreSQL to listen on all interfaces..."

if grep -q "^listen_addresses" "$POSTGRESQL_CONF"; then
    # Uncomment and change existing line
    sed -i "s/^#*listen_addresses.*/listen_addresses = '*'/" "$POSTGRESQL_CONF"
else
    # Add new line
    echo "listen_addresses = '*'" >> "$POSTGRESQL_CONF"
fi

log_success "Updated listen_addresses in postgresql.conf"

# Step 2: Configure pg_hba.conf to allow remote connections
log_info "Configuring client authentication..."

# Check if remote access rule already exists
if grep -q "host.*all.*all.*0.0.0.0/0.*md5" "$PG_HBA_CONF"; then
    log_warn "Remote access rule already exists in pg_hba.conf"
else
    # Add remote access rule
    echo "" >> "$PG_HBA_CONF"
    echo "# Allow remote connections (added by enable_remote_access.sh)" >> "$PG_HBA_CONF"
    echo "host    all             all             0.0.0.0/0               md5" >> "$PG_HBA_CONF"
    log_success "Added remote access rule to pg_hba.conf"
fi

# Step 3: Restart PostgreSQL
log_info "Restarting PostgreSQL service..."
if systemctl restart postgresql 2>/dev/null; then
    log_success "PostgreSQL restarted successfully"
elif service postgresql restart 2>/dev/null; then
    log_success "PostgreSQL restarted successfully"
else
    log_error "Failed to restart PostgreSQL"
    log_warn "Try manually: sudo systemctl restart postgresql"
    exit 1
fi

# Step 4: Configure firewall
log_info "Configuring firewall..."

if command -v ufw &> /dev/null; then
    # Ubuntu/Debian with UFW
    log_info "Detected UFW firewall"
    ufw allow 5432/tcp
    log_success "Opened port 5432 in UFW"
elif command -v firewall-cmd &> /dev/null; then
    # CentOS/RHEL with firewalld
    log_info "Detected firewalld"
    firewall-cmd --permanent --add-port=5432/tcp
    firewall-cmd --reload
    log_success "Opened port 5432 in firewalld"
else
    log_warn "No recognized firewall detected (ufw or firewalld)"
    log_warn "You may need to manually open port 5432"
fi

# Step 5: Verify PostgreSQL is listening
log_info "Verifying PostgreSQL is listening on network..."
sleep 2

if netstat -plnt 2>/dev/null | grep -q ":5432.*0.0.0.0"; then
    log_success "PostgreSQL is listening on all interfaces (0.0.0.0:5432)"
elif ss -plnt 2>/dev/null | grep -q ":5432.*0.0.0.0"; then
    log_success "PostgreSQL is listening on all interfaces (0.0.0.0:5432)"
else
    log_warn "Could not verify PostgreSQL is listening on all interfaces"
    log_info "Check with: sudo netstat -plnt | grep 5432"
fi

# Get server IP addresses
log_info "Getting server IP addresses..."
echo ""
log_success "Your server IP addresses:"
ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print "  " $2}' | cut -d'/' -f1

echo ""
log_success "================================================"
log_success "Remote access has been enabled!"
log_success "================================================"
echo ""
echo "You can now connect from remote machines using:"
echo ""
echo "  psql -h YOUR_SERVER_IP -p 5432 -U myapp_user -d myapp_db"
echo ""
echo "Or using the remote script:"
echo "  ./read_remote_database.sh YOUR_SERVER_IP postgres --list-tables"
echo ""
log_warn "SECURITY NOTES:"
echo "  1. The current setup allows connections from ANY IP address"
echo "  2. For production, edit $PG_HBA_CONF"
echo "  3. Replace '0.0.0.0/0' with specific IP addresses or subnets"
echo "  4. Example: host all all 192.168.1.100/32 md5"
echo ""
echo "Configuration backups saved with .backup.* extension"
echo ""

# Show current pg_hba.conf rules
log_info "Current remote access rules:"
grep -E "^host" "$PG_HBA_CONF" | grep -v "^#"
echo ""

log_success "Setup complete!"
