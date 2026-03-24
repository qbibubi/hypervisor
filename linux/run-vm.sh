#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN_NAME="hypervisor-dev"

echo "Setting up and starting $DOMAIN_NAME..."

if sudo virsh dominfo "$DOMAIN_NAME" &>/dev/null; then
    echo "Domain exists, destroying and undefining..."
    sudo virsh destroy "$DOMAIN_NAME" 2>/dev/null || true
    sudo virsh undefine "$DOMAIN_NAME" --keep-nvram 2>/dev/null || true
fi

"$SCRIPT_DIR/setup-hypervisor.sh"

echo "Starting VM..."
sudo virsh start "$DOMAIN_NAME"

echo "Done. Connect with: sudo virsh console $DOMAIN_NAME"
