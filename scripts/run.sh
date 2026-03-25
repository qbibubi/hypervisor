#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Hypervisor Development VM Manager"
    echo ""
    echo "Usage: $0 <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  setup [auto|amd|intel]  - Setup VM with CPU-specific config"
    echo "  configure [auto|amd|intel] - Reconfigure existing VM"
    echo "  run [start|stop|reboot|console|vnc|status] - VM lifecycle"
    echo "  display [dev|dbg|all] - Launch VNC viewer for VMs (uses virt-viewer)"
    echo "  snapshot create <name>  - Create snapshot (debuggee only)"
    echo "  snapshot list           - List snapshots"
    echo "  snapshot delete <name> - Delete snapshot"
    echo "  snapshot revert <name> - Revert to snapshot"
    echo "  revert <name>           - Revert debuggee to snapshot (shorthand)"
    echo "  virtiofsd [start|stop|status|check] - virtiofs daemon"
    echo ""
    echo "Individual scripts available in scripts/:"
    ls -1 "$SCRIPT_DIR"/*.sh 2>/dev/null | xargs -I{} basename {} | sort
    exit 1
}

case "${1:-}" in
    setup)
        shift
        "$SCRIPT_DIR/vm_setup.sh" "$@"
        ;;
    configure)
        shift
        "$SCRIPT_DIR/vm_configure.sh" "$@"
        ;;
    run)
        shift
        "$SCRIPT_DIR/vm_run.sh" "$@"
        ;;
    display)
        shift
        "$SCRIPT_DIR/vm_launch.sh" "$@"
        ;;
    snapshot)
        shift
        "$SCRIPT_DIR/vm_snapshot.sh" "$@"
        ;;
    revert)
        shift
        "$SCRIPT_DIR/vm_revert.sh" "$@"
        ;;
    virtiofsd)
        shift
        "$SCRIPT_DIR/virtiofsd.sh" "$@"
        ;;
    *)
        usage
        ;;
esac
