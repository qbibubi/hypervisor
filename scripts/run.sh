#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

usage() {
  print "Hypervisor Development VM Manager"
  print ""
  print "USAGE"
  print "           $0 <command> [args...]"
  print ""
  print "COMMANDS"
  print " - configure [auto|amd|intel]                    Reconfigure existing VM"
  print " - run [start|stop|reboot|console|vnc|status]    VM lifecycle"
  print " - display [dev|dbg|all]                         Launch VNC viewer for VMs (uses virt-viewer)"
  print " - snapshot [dev|dbg] create <name>              Create standalone snapshot"
  print " - snapshot [dev|dbg] list                        List snapshots"
  print " - snapshot [dev|dbg] delete <name>              Delete snapshot"
  print " - snapshot [dev|dbg] revert <name>              Revert to snapshot"
  print " - snapshot [dev|dbg] status                     Show snapshot status"
  print " - revert <name>                                 Revert debuggee to snapshot (shorthand)"
  exit 1
}

case "${1:-}" in
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
  *)
    usage
    ;;
esac
