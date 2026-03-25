#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN_NAME="hypervisor-dev"

usage() {
    echo "Usage: $0 <snapshot-name>"
    echo ""
    echo "Revert the debuggee VM (hypervisor-dev) to a snapshot."
    echo ""
    echo "Examples:"
    echo "  $0 win-installed    # Revert to 'win-installed' snapshot"
    echo "  $0 clean-install    # Revert to 'clean-install' snapshot"
    echo ""
    echo "List available snapshots with: vm_snapshot.sh list"
    exit 1
}

if [[ -z "$1" ]]; then
    usage
fi

SNAPSHOT_NAME="$1"

echo "Reverting $DOMAIN_NAME to snapshot '$SNAPSHOT_NAME'..."
sudo virsh snapshot-revert "$DOMAIN_NAME" "$SNAPSHOT_NAME"
echo "Done. VM reverted to snapshot '$SNAPSHOT_NAME'."