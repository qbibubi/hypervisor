#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logs.sh"

VM_DEBUGGEE="hypervisor-dev"
VM_DEBUGGER="hypervisor-dbg"

usage() {
    print "USAGE"
    print "           $0 <vm> <command>"
    print ""
    print "VIRTUAL MACHINES"
    print " - dev      Debuggee VM (hypervisor-dev)"
    print " - dbg      Debugger VM (hypervisor-dbg)"
    print " - all      Both VMs (start/stop only)"
    print ""
    print "COMMANDS"
    print " - start      Start the VM"
    print " - stop       Stop (destroy) the VM"
    print " - reboot     Reboot the VM"
    print " - console    Connect to serial console"
    print " - vnc        Launch VNC viewer"
    print " - status     Show VM status"
    exit 1
}

get_vnc_port() {
    local domain="$1"
    local port=$(sudo virsh domdisplay "$domain" 2>/dev/null | grep -oP ':\d+$' | tr -d ':')
    print "${port:-5900}"
}

run_cmd() {
    local domain="$1"
    local cmd="$2"
    sudo virsh "$cmd" "$domain" 2>/dev/null || true
}

cmd_start() {
    local domain="$1"
    print "[$domain]: Starting..."
    sudo virsh start "$domain"
    print_success "[$domain]: Success"
}

cmd_stop() {
    local domain="$1"
    print "[$domain]: Stopping..."
    sudo virsh destroy "$domain" 2>/dev/null || print_warning "[$domain]: Already stopped"
}

cmd_reboot() {
    local domain="$1"
    print "[$domain]: Restarting..." 
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
        print_error "[$domain]: No VNC viewer found. Connect to 127.0.0.1:$port"
    fi
}

cmd_status() {
    local domain="$1"
    sudo virsh dominfo "$domain" 2>/dev/null || print "VM '$domain' does not exist"
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
            *) 
              print "USAGE"
              print "           $0 all [start|stop]" ;;
        esac
        ;;
    *) usage ;;
esac
