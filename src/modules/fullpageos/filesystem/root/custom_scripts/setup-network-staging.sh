#!/bin/bash

# Setup Network Configuration Staging System
# This script sets up the secure network configuration staging system

set -euo pipefail

echo "Setting up network configuration staging system..."

# Make the processor script executable
chmod +x /usr/local/bin/process-network-configs

# Create staging directories with proper permissions
mkdir -p /var/lib/network-staging/{pending,processed,status}

# Set ownership and permissions
# Root owns the directories, but pi user can write to pending and read status
chown root:root /var/lib/network-staging
chmod 755 /var/lib/network-staging

chown root:pi /var/lib/network-staging/pending
chmod 775 /var/lib/network-staging/pending

chown root:root /var/lib/network-staging/processed
chmod 755 /var/lib/network-staging/processed

chown root:pi /var/lib/network-staging/status
chmod 775 /var/lib/network-staging/status

# Enable the systemd services (they will start on boot)
systemctl enable network-config-processor.service
systemctl enable network-config-processor.timer

echo "Network configuration staging system setup complete"
echo "Services will start automatically on first boot"

# systemctl start network-config-processor.timer
# systemctl start network-config-processor.service
