#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN_NAME="hypervisor-dev"

usage() {
    echo "Usage: $0 <command> [snapshot-name]"
    echo ""
    echo "Commands (debuggee VM only):"
    echo "  create <name>  - Create snapshot"
    echo "  list           - List all snapshots"
    echo "  delete <name>  - Delete snapshot"
    echo "  revert <name>  - Revert to snapshot"
    echo ""
    echo "Note: Snapshotting is only for the debuggee VM (hypervisor-dev)."
    echo "      The debugger VM rarely changes and doesn't need snapshots."
    exit 1
}

cmd_create() {
    local name="${1:-debuggee-$(date +%Y%m%d-%H%M%S)}"
    local current_disk=$(sudo virsh domblklist "$DOMAIN_NAME" | awk 'NR==3 {print $2}')
    local snapshot_path="${current_disk%.qcow2}-${name}.qcow2"
    
    if [[ -z "$current_disk" ]]; then
        echo "Error: Could not determine current disk" >&2
        exit 1
    fi
    
    echo "Current disk: $current_disk"
    echo "Creating external snapshot '$name'..."
    
    if [[ -f "$snapshot_path" ]]; then
        echo "Error: Snapshot file already exists: $snapshot_path" >&2
        exit 1
    fi
    
    qemu-img create -f qcow2 -b "$current_disk" -F qcow2 "$snapshot_path"
    sudo virsh snapshot-create-as "$DOMAIN_NAME" "$name" \
        --diskspec vda,snapshot=external,file="$snapshot_path" \
        --disk-only
    
    echo "Snapshot created: $snapshot_path"
}

cmd_list() {
    echo "Snapshots for $DOMAIN_NAME:"
    sudo virsh snapshot-list "$DOMAIN_NAME"
}

cmd_delete() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Error: Snapshot name required" >&2
        exit 1
    fi
    
    local snapshot_xml=$(sudo virsh snapshot-dumpxml "$DOMAIN_NAME" "$name" 2>/dev/null)
    local disk_file=$(echo "$snapshot_xml" | grep -oP 'file>\K[^<]+' || true)
    
    echo "Deleting snapshot '$name'..."
    sudo virsh snapshot-delete "$DOMAIN_NAME" "$name"
    
    if [[ -n "$disk_file" ]] && [[ -f "$disk_file" ]]; then
        echo "Removing disk file: $disk_file"
        rm -f "$disk_file"
    fi
    
    echo "Snapshot deleted."
}

cmd_revert() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Error: Snapshot name required" >&2
        exit 1
    fi
    echo "Reverting to snapshot '$name'..."
    sudo virsh snapshot-revert "$DOMAIN_NAME" "$name"
    echo "Reverted to snapshot."
}

case "${1:-}" in
    create) cmd_create "${2:-}" ;;
    list) cmd_list ;;
    delete) cmd_delete "$2" ;;
    revert) cmd_revert "$2" ;;
    *) usage ;;
esac