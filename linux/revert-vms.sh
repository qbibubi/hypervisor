#!/bin/bash

set -e

VM_DEBUGGEE_NAME=hypervisor-dev
VM_DEBUGGER_NAME=windbg-debugger

VM_DEBUGGEE_SNAPSHOT_NAME=windows-installed
VM_DEBUGGER_SNAPSHOT_NAME=win-debugger-ready

echo "[info]: Reverting snapshots for $(VM_DEBUGGER_NAME) and $(VM_DEBUGGEE_NAME)"

sudo virsh snapshot-revert $VM_DEBUGGEE_NAME $VM_DEBUGGEE_SNAPSHOT_NAME
sudo virsh snapshot-revert $VM_DEBUGGER_NAME $VM_DEBUGGER_SNAPSHOT_NAME 

echo "[info]: Starting $(VM_DEBUGGER_NAME) and $(VM_DEBUGGEE_NAME)"

sudo virsh start $VM_DEBUGGEE_NAME && sudo virsh start $VM_DEBUGGER_NAME 
