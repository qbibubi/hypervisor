
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

DOMAIN="hypervisor-dev"
DISK_TARGET="vda"

usage() {
    print "USAGE"
    print "           $0 <command> [snapshot-name]"
    print ""
    print "COMMANDS"
    print "  create [name]   Create external snapshot"
    print "  list            List snapshots"
    print "  delete <name>   Delete snapshot (safe)"
    print "  revert <name>   Revert to snapshot"
    exit 1
}

get_current_disk() {
    sudo virsh domblklist "$DOMAIN" \
        | awk -v target="$DISK_TARGET" '$1 == target {print $2}'
}

cmd_create() {
    local name="${1:-snap-$(date +%Y%m%d-%H%M%S)}"
    local current_disk
    current_disk="$(get_current_disk)"

    if [[ -z "$current_disk" ]]; then
        print_error "[$DOMAIN]: Could not determine current disk"
        exit 1
    fi

    local snapshot_path="${current_disk%.qcow2}-${name}.qcow2"

    print "[$DOMAIN]: Current disk: $current_disk"
    print "[$DOMAIN]: Creating snapshot '$name'..."

    if [[ -f "$snapshot_path" ]]; then
        print_error "[$DOMAIN]: File already exists: $snapshot_path"
        exit 1
    fi

    sudo virsh snapshot-create-as "$DOMAIN" "$name" \
        --diskspec ${DISK_TARGET},snapshot=external,file="$snapshot_path" \
        --disk-only --atomic

    # Verify switch
    local new_disk
    new_disk="$(get_current_disk)"

    if [[ "$new_disk" != "$snapshot_path" ]]; then
        print_error "[$DOMAIN]: Snapshot created but disk did not switch!"
        exit 1
    fi

    print_success "[$DOMAIN]: Snapshot created and active"
}

cmd_list() {
    print "[$DOMAIN]: Snapshots:"
    sudo virsh snapshot-list "$DOMAIN" || true

    print ""
    print "[$DOMAIN]: Current disk chain:"
    get_current_disk
}

cmd_delete() {
    local name="$1"

    if [[ -z "$name" ]]; then
        print_error "[$DOMAIN]: Snapshot name required"
        exit 1
    fi

    print "[$DOMAIN]: Deleting snapshot '$name'..."

    # Get snapshot disk file
    local snapshot_xml
    snapshot_xml=$(sudo virsh snapshot-dumpxml "$DOMAIN" "$name" 2>/dev/null || true)

    if [[ -z "$snapshot_xml" ]]; then
        print_error "[$DOMAIN]: Snapshot not found"
        exit 1
    fi

    local disk_file
    disk_file=$(echo "$snapshot_xml" | grep -oP 'file=\x27\K[^\x27]+' || true)

    # SAFETY: ensure it's not the active disk
    local current_disk
    current_disk="$(get_current_disk)"

    if [[ "$disk_file" == "$current_disk" ]]; then
        print_error "[$DOMAIN]: Cannot delete active snapshot!"
        exit 1
    fi

    sudo virsh snapshot-delete "$DOMAIN" "$name"

    # Remove file if still present
    if [[ -n "$disk_file" && -f "$disk_file" ]]; then
        print "[$DOMAIN]: Removing disk file: $disk_file"
        rm -f "$disk_file"
    fi

    print_success "[$DOMAIN]: Snapshot deleted"
}

cmd_revert() {
    local name="$1"

    if [[ -z "$name" ]]; then
        print_error "[$DOMAIN]: Snapshot name required"
        exit 1
    fi

    print "[$DOMAIN]: Reverting to '$name'..."

    sudo virsh snapshot-revert "$DOMAIN" "$name" --running

    print_success "[$DOMAIN]: Reverted"
}

case "${1:-}" in
    create) cmd_create "${2:-}" ;;
    list) cmd_list ;;
    delete) cmd_delete "${2:-}" ;;
    revert) cmd_revert "${2:-}" ;;
    *) usage ;;
esac
