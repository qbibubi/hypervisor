#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VM_DEBUGGEE="hypervisor-dev"
VM_DEBUGGER="hypervisor-dbg"

usage() {
    echo "Usage: $0 <vm> <command>"
    echo ""
    echo "VMs:"
    echo "  dev   - Debuggee VM (hypervisor-dev)"
    echo "  dbg   - Debugger VM (hypervisor-dbg)"
    echo "  all   - Both VMs (start/stop only)"
    echo ""
    echo "Commands:"
    echo "  start    - Start the VM"
    echo "  stop     - Stop (destroy) the VM"
    echo "  reboot   - Reboot the VM"
    echo "  console  - Connect to serial console"
    echo "  vnc      - Launch VNC viewer"
    echo "  status   - Show VM status"
    exit 1
}

get_vnc_port() {
    local domain="$1"
    local port=$(sudo virsh domdisplay "$domain" 2>/dev/null | grep -oP ':\d+$' | tr -d ':')
    echo "${port:-5900}"
}

run_cmd() {
    local domain="$1"
    local cmd="$2"
    sudo virsh "$cmd" "$domain" 2>/dev/null || true
}

cmd_start() {
    local domain="$1"
    echo "[$domain]: Starting..."
    sudo virsh start "$domain"
    echo "[$domain]: Success"
}

cmd_stop() {
    local domain="$1"
    
    echo "[$domain]: Stopping..."
    sudo virsh destroy "$domain" 2>/dev/null || echo "[$domain]: Already stopped"
}

cmd_reboot() {
    local domain="$1"
    echo "[$domain] Restarting..." 
    sudo virsh reboot "$domain"
}

cmd_console() {
    local domain="$1"
    sudo virsh console "$domain"
}

cmd_vnc() {
    local domain="$1"
    local port=$(get_vnc_port "$domain")
    if command -v virt-viewer &>/dev/null; then
        virt-viewer --domain-name "$domain"
    elif command -v remmina &>/dev/null; then
        remmina "vnc://127.0.0.1:$port"
    elif command -v vncviewer &>/dev/null; then
        sudo vncviewer "127.0.0.1:$port" 
    elif command -v gnome-remote-desktop &>/dev/null; then
        sudo gnome-remote-desktop -v "127.0.0.1:$port"
    else
        echo "No VNC viewer found. Connect to 127.0.0.1:$port"
    fi
}

cmd_status() {
    local domain="$1"
    sudo virsh dominfo "$domain" 2>/dev/null || echo "VM '$domain' does not exist."
}

case "${1:-}" in
    dev)
        VM="${2:-status}"
        case "$VM" in
            start) cmd_start "$VM_DEBUGGEE" ;;
            stop) cmd_stop "$VM_DEBUGGEE" ;;
            reboot) cmd_reboot "$VM_DEBUGGEE" ;;
            console) cmd_console "$VM_DEBUGGEE" ;;
            vnc) cmd_vnc "$VM_DEBUGGEE" ;;
            status) cmd_status "$VM_DEBUGGEE" ;;
            *) usage ;;
        esac
        ;;
    dbg)
        VM="${2:-status}"
        case "$VM" in
            start) cmd_start "$VM_DEBUGGER" ;;
            stop) cmd_stop "$VM_DEBUGGER" ;;
            reboot) cmd_reboot "$VM_DEBUGGER" ;;
            console) cmd_console "$VM_DEBUGGER" ;;
            vnc) cmd_vnc "$VM_DEBUGGER" ;;
            status) cmd_status "$VM_DEBUGGER" ;;
            *) usage ;;
        esac
        ;;
    all)
        case "${2:-}" in
            start)
                cmd_start "$VM_DEBUGGEE"
                cmd_start "$VM_DEBUGGER"
                ;;
            stop)
                cmd_stop "$VM_DEBUGGEE"
                cmd_stop "$VM_DEBUGGER"
                ;;
            *) echo "Usage: $0 all [start|stop]" ;;
        esac
        ;;
    *) usage ;;
esac
