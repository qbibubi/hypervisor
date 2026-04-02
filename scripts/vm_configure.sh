#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

QEMU_DIR="/etc/libvirt/qemu"
DOMAIN="hypervisor-dev"

AMD_CONFIG="$SCRIPT_DIR/../linux/hypervisor-amd-dev.xml"
INTEL_CONFIG="$SCRIPT_DIR/../linux/hypervisor-intel-dev.xml"

usage() {
  print "USAGE"
  print "           $0 [auto|amd|intel]"
  print ""
  print "Configure VM based on detected or specified CPU type"
  print " - auto    Auto-detect CPU and use appropriate config (default)"
  print " - amd     Use AMD configuration"
  print " - intel   Use Intel configuration"
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
    
    print "[$DOMAIN]: Configuring VM with: $config_name"
    
    if ! sudo virsh list --all | grep -q "$DOMAIN"; then
        print "[$DOMAIN]: VM does not exist. Run vm_setup.sh first."
        exit 1
    fi
    
    sudo cp "$config" "$QEMU_DIR/$DOMAIN.xml"
    sudo virsh undefine "$DOMAIN" 2>/dev/null || true
    sudo virsh define "$QEMU_DIR/$DOMAIN.xml"
    sudo mkdir -p "$QEMU_DIR/nvram"
    
    print_success "[$DOMAIN]: Configured - run 'vm_run.sh start' to start."
}

case "${1:-auto}" in
    amd)
        configure_vm "$AMD_CONFIG"
        ;;
    intel)
        configure_vm "$INTEL_CONFIG"
        ;;
    auto)
        if check_intel; then
            print "[$DOMAIN]: Detected Intel CPU"
            configure_vm "$INTEL_CONFIG"
        elif check_amd; then
            print "[$DOMAIN]: Detected AMD CPU"
            configure_vm "$AMD_CONFIG"
        else
            print "[$DOMAIN]: Could not detect CPU type" >&2
            exit 1
        fi
        ;;
    *) usage ;;
esac
