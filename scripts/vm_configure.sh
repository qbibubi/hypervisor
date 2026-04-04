#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

QEMU_DIR="/etc/libvirt/qemu"
DOMAIN="hypervisor-dev"
CONFIG="$SCRIPT_DIR/../linux/hypervisor-dev.xml"

usage() {
  print "Configure VM based"
  print ""
  print "USAGE"
  print "           $0" 
  exit 1
}

check_amd() {
  grep -q '^flags.*\bsvm\b' /proc/cpuinfo 2>/dev/null && return 0 || return 1
}

check_intel() {
  grep -q '^flags.*\bvmx\b' /proc/cpuinfo 2>/dev/null && return 0 || return 1
}

configure_vm() {
  local config="$1"
  local config_name=$(basename "$config")

  print "[$DOMAIN] Configuring VM with: $config_name"

  if ! sudo virsh list --all | grep -q "$DOMAIN"; then
    print_error "[$DOMAIN] VM does not exist"
    exit 1
  fi

  sudo cp "$config" "$QEMU_DIR/$DOMAIN.xml"
  sudo virsh undefine "$DOMAIN" 2>/dev/null || true
  sudo virsh define "$QEMU_DIR/$DOMAIN.xml"
  sudo mkdir -p "$QEMU_DIR/nvram"

  print_success "[$DOMAIN] Configured - run 'vm_run.sh start' to start"
}

configure_vm "$CONFIG"
