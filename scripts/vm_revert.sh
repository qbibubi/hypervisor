#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

DOMAIN="hypervisor-dev"

usage() {
  print "USAGE"
  print "           $0 <snapshot-name>"
  print ""
  print "Revert the debuggee VM (hypervisor-dev) to a snapshot."
  print ""
  print "EXAMPLES"
  print "  - $0 win-installed    # Revert to 'win-installed' snapshot"
  print "  - $0 clean-install    # Revert to 'clean-install' snapshot"
  print ""
  print "List available snapshots with: vm_snapshot.sh list"
  exit 1
}

if [[ -z "$1" ]]; then
  usage
fi

SNAPSHOT_NAME="$1"

print "[$DOMAIN] Reverting to snapshot '$SNAPSHOT_NAME'..."
sudo virsh snapshot-revert "$DOMAIN" "$SNAPSHOT_NAME"
print_success "[$DOMAIN] Reverted to snapshot '$SNAPSHOT_NAME' successfuly"
