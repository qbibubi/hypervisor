#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

SNAPSHOT_DIR="/var/lib/libvirt/images/snapshots"

usage() {
  print "VM Snapshot Manager - Creates independent (non-chained) snapshots"
  print ""
  print "USAGE"
  print "           $0 <vm> <command> [args...]"
  print ""
  print "VIRTUAL MACHINES"
  print "  dev        Debuggee VM (hypervisor-dev)"
  print "  dbg        Debugger VM (hypervisor-dbg)"
  print ""
  print "COMMANDS"
  print "  create [name]              Create standalone snapshot"
  print "  list                      List available snapshots"
  print "  delete <name>             Delete snapshot (checks if active first)"
  print "  revert <name>             Revert VM to snapshot (stops VM first)"
  print "  status                    Show current disk and snapshot status"
  print ""
  print "EXAMPLES"
  print "  $0 dev create post-setup      # Create snapshot named 'post-setup'"
  print "  $0 dev revert post-setup      # Revert to 'post-setup' snapshot"
  print "  $0 dev delete old-snap       # Delete 'old-snap' snapshot"
  exit 1
}

get_vm_name() {
  local vm="$1"
  case "$vm" in
    dev) echo "hypervisor-dev" ;;
    dbg) echo "hypervisor-dbg" ;;
    *) print_error "Unknown VM: $vm" && exit 1 ;;
  esac
}

get_disk_target() {
  local vm="$1"
  case "$vm" in
    dev) echo "vda" ;;
    dbg) echo "vda" ;;
  esac
}

get_current_disk() {
  local domain="$1"
  local target="$2"
  sudo virsh domblklist "$domain" 2>/dev/null \
    | awk -v t="$target" '$1 == t {print $2}'
}

get_current_disk_file() {
  local domain="$1"
  local target="$2"
  get_current_disk "$domain" "$target"
}

cmd_create() {
  local vm="$1"
  local name="${2:-snap-$(date +%Y%m%d-%H%M%S)}"
  
  local domain
  domain="$(get_vm_name "$vm")"
  local target
  target="$(get_disk_target "$vm")"
  
  local current_disk
  current_disk="$(get_current_disk "$domain" "$target")"
  
  if [[ -z "$current_disk" ]]; then
    print_error "[$domain] Could not determine current disk"
    exit 1
  fi
  
  sudo mkdir -p "$SNAPSHOT_DIR"
  
  local snapshot_file="${SNAPSHOT_DIR}/${vm}-${name}.qcow2"
  
  if [[ -f "$snapshot_file" ]]; then
    print_error "[$domain] Snapshot file already exists: $snapshot_file"
    exit 1
  fi
  
  print "[$domain] Current disk: $current_disk"
  print "[$domain] Creating standalone snapshot '$name'..."
  print "[$domain] This may take a moment..."
  
  sudo mkdir -p "$SNAPSHOT_DIR"
  
  local snapshot_file="${SNAPSHOT_DIR}/${vm}-${name}.qcow2"
  
  if [[ -f "$snapshot_file" ]]; then
    print_error "[$domain] Snapshot file already exists: $snapshot_file"
    exit 1
  fi
  
  sudo qemu-img convert -O qcow2 -o compat=1.1,lazy_refcounts=off "$current_disk" "$snapshot_file"
  
  print_success "[$domain] Snapshot created: $snapshot_file"
  print "[$domain] To revert to this snapshot, run: $0 $vm revert $name"
}

cmd_list() {
  local vm="$1"
  local domain
  domain="$(get_vm_name "$vm")"
  
  print "[$domain] Standalone snapshots in $SNAPSHOT_DIR:"
  if [[ -d "$SNAPSHOT_DIR" ]]; then
    ls -lh "$SNAPSHOT_DIR/${vm}"-*.qcow2 2>/dev/null \
      | awk '{print $9, $5}' \
      | while read -r file size; do
        local name
        name="$(basename "$file" | sed "s/${vm}-//" | sed 's/\.qcow2$//')"
        print "  $name ($(echo "$size" | sed 's/^/ /'))"
      done
    if ! ls "$SNAPSHOT_DIR/${vm}"-*.qcow2 &>/dev/null; then
      print "  (none)"
    fi
  else
    print "  (none)"
  fi
  
  echo ""
  local target
  target="$(get_disk_target "$vm")"
  print "[$domain] Current disk:"
  get_current_disk "$domain" "$target" | sed 's/^/  /'
}

cmd_delete() {
  local vm="$1"
  local name="$2"
  
  if [[ -z "$name" ]]; then
    print_error "Snapshot name required"
    exit 1
  fi
  
  local domain
  domain="$(get_vm_name "$vm")"
  
  local snapshot_file="${SNAPSHOT_DIR}/${vm}-${name}.qcow2"
  
  if [[ ! -f "$snapshot_file" ]]; then
    print_error "[$domain] Snapshot file not found: $snapshot_file"
    exit 1
  fi
  
  local target
  target="$(get_disk_target "$vm")"
  local current_disk
  current_disk="$(get_current_disk "$domain" "$target")"
  
  if [[ "$current_disk" == "$snapshot_file" ]]; then
    print_error "[$domain] Cannot delete active snapshot! Revert to another disk first."
    exit 1
  fi
  
  print "[$domain] Deleting snapshot '$name'..."
  sudo rm -f "$snapshot_file"
  print_success "[$domain] Snapshot deleted"
}

cmd_revert() {
  local vm="$1"
  local name="$2"
  
  if [[ -z "$name" ]]; then
    print_error "Snapshot name required"
    exit 1
  fi
  
  local domain
  domain="$(get_vm_name "$vm")"
  local target
  target="$(get_disk_target "$vm")"
  
  local snapshot_file="${SNAPSHOT_DIR}/${vm}-${name}.qcow2"
  
  if [[ ! -f "$snapshot_file" ]]; then
    print_error "[$domain] Snapshot not found: $snapshot_file"
    print "[$domain] Available snapshots:"
    ls -1 "${SNAPSHOT_DIR}/${vm}"-*.qcow2 2>/dev/null | sed "s|${SNAPSHOT_DIR}/${vm}-||g" | sed 's/.qcow2$//' | sed 's/^/  - /g' || print "  (none)"
    exit 1
  fi
  
  local current_state
  current_state="$(sudo virsh domstate "$domain" 2>/dev/null || echo "not found")"
  
  if [[ "$current_state" == "running" ]]; then
    print "[$domain] Stopping VM..."
    sudo virsh destroy "$domain" 2>/dev/null || true
  fi
  
  print "[$domain] Reverting to snapshot '$name'..."
  
  local disk_path
  disk_path="$(sudo virsh domblklist "$domain" 2>/dev/null | grep -E "^${target}" | awk '{print $2}')"
  
  print "[$domain] Current disk: $disk_path"
  print "[$domain] New disk: $snapshot_file"
  
  sudo virsh detach-disk "$domain" "$target" --persistent 2>/dev/null || true
  
  sudo virsh attach-disk "$domain" "$snapshot_file" "$target" --persistent --driver qcow2 --cache writeback
  
  print_success "[$domain] Reverted to snapshot '$name'"
  print "[$domain] Start VM with: vm_run.sh $vm start"
}

cmd_status() {
  local vm="$1"
  local domain
  domain="$(get_vm_name "$vm")"
  local target
  target="$(get_disk_target "$vm")"
  
  local state
  state="$(sudo virsh domstate "$domain" 2>/dev/null || echo "not found")"
  
  print "[$domain] State: $state"
  
  local current_disk
  current_disk="$(get_current_disk "$domain" "$target" 2>/dev/null || echo "none")"
  print "[$domain] Current disk: $current_disk"
  
  if [[ "$current_disk" == "$SNAPSHOT_DIR"* ]]; then
    print "[$domain] Using snapshot: $(basename "$current_disk" | sed "s/${vm}-//" | sed 's/\.qcow2$//')"
  elif [[ -n "$current_disk" ]]; then
    print "[$domain] Using base disk"
  fi
}

if [[ $# -lt 2 ]]; then
  usage
fi

VM="$1"
CMD="${2:-}"
shift 2 || true

case "$VM" in
  dev|dbg) ;;
  *) usage ;;
esac

case "$CMD" in
  create) cmd_create "$VM" "${1:-}" ;;
  list)   cmd_list "$VM" ;;
  delete) cmd_delete "$VM" "${1:-}" ;;
  revert) cmd_revert "$VM" "${1:-}" ;;
  status) cmd_status "$VM" ;;
  *)      usage ;;
esac
