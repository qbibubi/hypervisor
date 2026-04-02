#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

DOMAIN="hypervisor-dev"

usage() {
    print "USAGE"
    print "           $0 <command> [snapshot-name]"
    print ""
    print "COMMANDS (debuggee VM only)"
    print "  - create <name>    Create snapshot"
    print "  - list             List all snapshots"
    print "  - delete <name>    Delete snapshot"
    print "  - revert <name>    Revert to snapshot"
    print ""
    print "NOTE"
    print "   Snapshotting is only for the debuggee VM (hypervisor-dev)"
    print "   The debugger VM rarely changes and doesn't need snapshots"
    exit 1
}

cmd_create() {
    local name="${1:-debuggee-$(date +%Y%m%d-%H%M%S)}"
    local current_disk=$(sudo virsh domblklist "$DOMAIN" | awk 'NR==3 {print $2}')
    local snapshot_path="${current_disk%.qcow2}-${name}.qcow2"
    
    if [[ -z "$current_disk" ]]; then
        print_error "[$DOMAIN]: Could not determine current disk" >&2
        exit 1
    fi
    
    print "[$DOMAIN]: Current disk: $current_disk"
    print "[$DOMAIN]: Creating external snapshot '$name'..."
    
    if [[ -f "$snapshot_path" ]]; then
        print_error "[$DOMAIN]: Snapshot file already exists: $snapshot_path" >&2
        exit 1
    fi
    
    qemu-img create -f qcow2 -b "$current_disk" -F qcow2 "$snapshot_path"
    sudo virsh snapshot-create-as "$DOMAIN" "$name" \
        --diskspec vda,snapshot=external,file="$snapshot_path" \
        --disk-only
    
    print "[$DOMAIN]: Snapshot created: $snapshot_path"
}

cmd_list() {
    print "[$DOMAIN]: Snapshots:"
    sudo virsh snapshot-list "$DOMAIN"
}

cmd_delete() {
    local name="$1"
    if [[ -z "$name" ]]; then
        print_error "[$DOMAIN]: Snapshot name required" >&2
        exit 1
    fi
    
    local snapshot_xml=$(sudo virsh snapshot-dumpxml "$DOMAIN" "$name" 2>/dev/null)
    local disk_file=$(print "$snapshot_xml" | grep -oP 'file>\K[^<]+' || true)
    
    print "[$DOMAIN]: Deleting snapshot '$name'..."
    sudo virsh snapshot-delete "$DOMAIN" "$name"
    
    if [[ -n "$disk_file" ]] && [[ -f "$disk_file" ]]; then
        print "[$DOMAIN]: Removing disk file: $disk_file"
        rm -f "$disk_file"
    fi
    
    print_success "[$DOMAIN]: Snapshot deleted"
}

cmd_revert() {
    local name="$1"
    if [[ -z "$name" ]]; then
        print_error "[$DOMAIN]: Snapshot name required" >&2
        exit 1
    fi

    print "[$DOMAIN]: Reverting to snapshot '$name'..."
    sudo virsh snapshot-revert "$DOMAIN" "$name"
    print_success "[$DOMAIN]: Reverted to snapshot"
}

case "${1:-}" in
    create) cmd_create "${2:-}" ;;
    list) cmd_list ;;
    delete) cmd_delete "$2" ;;
    revert) cmd_revert "$2" ;;
    *) usage ;;
esac
