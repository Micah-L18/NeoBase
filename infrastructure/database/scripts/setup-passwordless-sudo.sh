#!/bin/bash
# Setup Passwordless Sudo for NeoBase
# Run this ONCE on your Ubuntu server before using the web interface

if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo: sudo ./setup-passwordless-sudo.sh"
    exit 1
fi

USERNAME=${1:-$SUDO_USER}

if [ -z "$USERNAME" ]; then
    echo "Usage: sudo ./setup-passwordless-sudo.sh [username]"
    echo "Or just run: sudo ./setup-passwordless-sudo.sh"
    exit 1
fi

echo "Setting up passwordless sudo for user: $USERNAME"

# Create sudoers file for NeoBase
cat > /etc/sudoers.d/neobase << EOF
# Allow $USERNAME to run NeoBase setup without password
$USERNAME ALL=(ALL) NOPASSWD: /home/$USERNAME/neobase-db/scripts/setup.sh
$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/apt-get
$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/docker
$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/systemctl
$USERNAME ALL=(ALL) NOPASSWD: /usr/sbin/ufw
EOF

# Set proper permissions
chmod 0440 /etc/sudoers.d/neobase

# Validate sudoers file
if visudo -c -f /etc/sudoers.d/neobase; then
    echo "✓ Passwordless sudo configured successfully!"
    echo ""
    echo "User '$USERNAME' can now run NeoBase commands without password."
else
    echo "✗ Error in sudoers configuration. Removing file."
    rm /etc/sudoers.d/neobase
    exit 1
fi
