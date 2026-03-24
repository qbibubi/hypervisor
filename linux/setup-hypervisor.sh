#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU_DIR="/etc/libvirt/qemu"
DOMAIN_NAME="hypervisor-dev"

AMD_CONFIG="$SCRIPT_DIR/hypervisor-amd-dev.xml"
INTEL_CONFIG="$SCRIPT_DIR/hypervisor-intel-dev.xml"

check_amd() {
    grep -q '^flags.*\bsvm\b' /proc/cpuinfo 2>/dev/null && return 0 || return 1
}

check_intel() {
    grep -q '^flags.*\bvmx\b' /proc/cpuinfo 2>/dev/null && return 0 || return 1
}

setup_config() {
    local config="$1"
    local config_name=$(basename "$config")
    
    echo "[info]: Setting up $config_name..."
    
    sudo cp "$config" "$QEMU_DIR/hypervisor-dev.xml"
    sudo virsh undefine "$DOMAIN_NAME" 2>/dev/null || true
    sudo virsh define "$QEMU_DIR/hypervisor-dev.xml"
    sudo mkdir -p "$QEMU_DIR/nvram"
    
    echo "[info]: Done. Run 'sudo virsh start $DOMAIN_NAME' to start the VM."
}

case "${1:-auto}" in
    amd)
        setup_config "$AMD_CONFIG"
        ;;
    intel)
        setup_config "$INTEL_CONFIG"
        ;;
    auto)
        if check_intel; then
            echo "Detected Intel CPU"
            setup_config "$INTEL_CONFIG"
        elif check_amd; then
            echo "Detected AMD CPU"
            setup_config "$AMD_CONFIG"
        else
            echo "Error: Could not detect CPU type" >&2
            exit 1
        fi
        ;;
    *)
esac
