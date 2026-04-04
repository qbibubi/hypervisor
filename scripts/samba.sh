#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

SHARE_DIR="/home/qbibubi/dev/hypervisor"
SAMBA_CONF="/etc/samba/smb.conf"
SAMBA_USER="qbibubi"

usage() {
  print "USAGE"
  print "           $0 <command>"
  print ""
  print "COMMANDS"
  print "  - setup        Setup Samba share for hypervisor directory"
  print "  - start        Start Samba service"
  print "  - stop         Stop Samba service"
  print "  - status       Check Samba status"
  print "  - restart      Restart Samba service"
  exit 1
}

cmd_setup() {
  print "[Samba] Setting up share..."
  if ! command -v smbd &>/dev/null; then
    print_warning "[Samba]: Installing"
    sudo pacman -S samba
  fi
  
  print "[Samba] Creating share directory..."
  sudo mkdir -p /var/lib/samba/usershare
  sudo chmod 1777 /var/lib/samba/usershare
  
  print "[Samba] Adding user..."
  sudo pdbedit -L 2>/dev/null | grep -q "$SAMBA_USER" || sudo smbpasswd -a "$SAMBA_USER"
  
  print "[Samba] Creating config..."

  # This could be automated by finding the current user - whoami or something?
  if ! grep -q "\[hypervisor\]" "$SAMBA_CONF" 2>/dev/null; then
    sudo tee -a "$SAMBA_CONF" > /dev/null << 'EOF'
[hypervisor]
  path = /home/qbibubi/dev/hypervisor
  read only = no
  writable = yes
  guest ok = yes
  public = no
  valid users = qbibubi
  force user = qbibubi 
EOF
  fi
  
  print_success "[Samba] Share configured - run '$0 start' to start the service"
}

cmd_start() {
  print "[Samba] Starting..."
  sudo systemctl start smb nmb
  sudo systemctl enable smb nmb
  print_success "[Samba] started"
}

cmd_stop() {
  print "[Samba] Stopping..."
  sudo systemctl stop smb nmb
  print_success "[Samba] Stopped"
}

cmd_status() {
  sudo systemctl status smb nmb --no-pager || true
}

cmd_restart() {
  cmd_stop
  cmd_start
}

case "${1:-usage}" in
  setup)    cmd_setup ;;
  start)    cmd_start ;;
  stop)     cmd_stop ;;
  status)   cmd_status ;;
  restart)  cmd_restart ;;
  *)        usage ;;
esac
