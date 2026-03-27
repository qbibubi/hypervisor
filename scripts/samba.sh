#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE_DIR="/home/qbibubi/dev/hypervisor"
SAMBA_CONF="/etc/samba/smb.conf"
SAMBA_USER="qbibubi"

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  setup   - Setup Samba share for hypervisor directory"
    echo "  start   - Start Samba service"
    echo "  stop    - Stop Samba service"
    echo "  status  - Check Samba status"
    echo "  restart - Restart Samba service"
    exit 1
}

cmd_setup() {
    echo "Setting up Samba share..."
    
    if ! command -v smbd &>/dev/null; then
        echo "Installing Samba..."
        sudo pacman -S samba
    fi
    
    echo "Creating share directory..."
    sudo mkdir -p /var/lib/samba/usershare
    sudo chmod 1777 /var/lib/samba/usershare
    
    echo "Adding Samba user..."
    sudo pdbedit -L 2>/dev/null | grep -q "$SAMBA_USER" || sudo smbpasswd -a "$SAMBA_USER"
    
    echo "Creating Samba config..."
    if ! grep -q "\[hypervisor\]" "$SAMBA_CONF" 2>/dev/null; then
        sudo tee -a "$SAMBA_CONF" > /dev/null << 'EOF'

[hypervisor]
   path = /home/qbibubi/dev/hypervisor
   public = no
   writable = yes
   valid users = qbibubi
   read only = no
   guest ok = no
EOF
    fi
    
    echo "Samba share configured. Run '$0 start' to start the service."
}

cmd_start() {
    echo "Starting Samba..."
    sudo systemctl start smb nmb
    sudo systemctl enable smb nmb
    echo "Samba started."
}

cmd_stop() {
    echo "Stopping Samba..."
    sudo systemctl stop smb nmb
    echo "Samba stopped."
}

cmd_status() {
    sudo systemctl status smb nmb --no-pager || true
}

cmd_restart() {
    cmd_stop
    cmd_start
}

case "${1:-usage}" in
    setup) cmd_setup ;;
    start) cmd_start ;;
    stop) cmd_stop ;;
    status) cmd_status ;;
    restart) cmd_restart ;;
    *) usage ;;
esac