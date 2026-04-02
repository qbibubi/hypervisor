#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU_DIR="/etc/libvirt/qemu"
DOMAIN_NAME="hypervisor-dev"

AMD_CONFIG="$SCRIPT_DIR/../linux/hypervisor-amd-dev.xml"
INTEL_CONFIG="$SCRIPT_DIR/../linux/hypervisor-intel-dev.xml"

usage() {
    echo "Usage: $0 [auto|amd|intel]"
    echo ""
    echo "Configure VM based on detected or specified CPU type:"
    echo "  auto   - Auto-detect CPU and use appropriate config (default)"
    echo "  amd    - Use AMD configuration"
    echo "  intel  - Use Intel configuration"
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
    
    echo "[$DOMAIN_NAME] Configuring VM with: $config_name"
    
    if ! sudo virsh list --all | grep -q "$DOMAIN_NAME"; then
        echo "[ERROR]: VM does not exist. Run vm_setup.sh first."
        exit 1
    fi
    
    sudo cp "$config" "$QEMU_DIR/$DOMAIN_NAME.xml"
    sudo virsh undefine "$DOMAIN_NAME" 2>/dev/null || true
    sudo virsh define "$QEMU_DIR/$DOMAIN_NAME.xml"
    sudo mkdir -p "$QEMU_DIR/nvram"
    
    echo "[$DOMAIN_NAME] VM configured - run 'vm_run.sh start' to start."
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
            echo "[INFO]: Detected Intel CPU"
            configure_vm "$INTEL_CONFIG"
        elif check_amd; then
            echo "[INFO]: Detected AMD CPU"
            configure_vm "$AMD_CONFIG"
        else
            echo "[ERROR]: Could not detect CPU type" >&2
            exit 1
        fi
        ;;
    *) usage ;;
esac
