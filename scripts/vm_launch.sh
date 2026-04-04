#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

VM_DEV="hypervisor-dev"
VM_DBG="hypervisor-dbg"
VNC_DEV_PORT=5900
VNC_DBG_PORT=5901

usage() {
  print "Launch VM display clients (uses virt-viewer, falls back to remmina)"
  print ""
  print "USAGE"
  print "           $0 [dev|dbg|all]"
  print ""
  print " - dev     Connect to debuggee VM (port 5900)"
  print " - dbg     Connect to debugger VM (port 5901)"
  print " - all     Connect to both VMs (default)"
  exit 1
}

launch_viewer() {
  local domain="$1"
  local port="$2"

  if command -v vncviewer &>/dev/null; then
    print "[$domain] Launching vncviewer on port $port..."
    sudo -u qbibubi -i vncviewer "127.0.0.1:$port" &
  elif command -v virt-viewer &>/dev/null; then
    print "[$domain] Launching virt-viewer..."
    sudo -u qbibubi -i virt-viewer --domain-name "$domain" &
  elif command -v remmina &>/dev/null; then
    print "[$domain] Launching remmina on port $port..."
    remmina -c "vnc://127.0.0.1:$port" &
  else
    print_error "[$domain] No VNC viewer found (tried vncviewer, virt-viewer, remmina)"
    exit 1
  fi

  print_success "[$domain] Display client launched"
}

case "${1:-all}" in
  dev)
    launch_viewer "$VM_DEV" "$VNC_DEV_PORT"
    ;;
  dbg)
    launch_viewer "$VM_DBG" "$VNC_DBG_PORT"
    ;;
  all)
    launch_viewer "$VM_DEV" "$VNC_DEV_PORT"
    launch_viewer "$VM_DBG" "$VNC_DBG_PORT"
    ;;
  *)
    usage
    ;;
esac

