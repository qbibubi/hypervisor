# Hypervisor Development Environment - Session Summary

## Date: 2026-03-23

---

## Hardware
- **CPU**: AMD Ryzen 5 2600 (Zen+) with SVM support
- **Host OS**: Arch Linux
- **KVM nested**: Enabled (nested=1)

---

## VMs Created

### 1. hypervisor-dev (Debuggee)
| Property | Value |
|----------|-------|
| RAM | 16GB |
| vCPUs | 4 |
| Disk | 120GB |
| Network | virtio + e1000e (kdnet) |
| Serial | 127.0.0.1:54320 |
| VNC | 127.0.0.1:5900 |
| IP | 192.168.122.243 |
| Hostname | DESKTOP-J7GRK00 |
| OS | Windows 10 Pro |
| Features | Hyper-V enabled, test signing on, kdnet configured |
| Status | Running, WinDbg connected |

### 2. windbg-debugger (Debugger)
| Property | Value |
|----------|-------|
| RAM | 4GB |
| vCPUs | 2 |
| Disk | 60GB |
| Network | virtio |
| Serial | 127.0.0.1:54321 |
| VNC | 127.0.0.1:5901 |
| IP | 192.168.122.138 |
| Hostname | DESKTOP-EKTL426 |
| OS | Windows 10 Pro |
| Tools | WinDbg (Microsoft Store) |
| Status | Running |

---

## Network Configuration

- **Network**: libvirt default (192.168.122.0/24)
- **DHCP**: Provided by libvirt dnsmasq
- **kdnet settings**: hostip:192.168.122.138, port:50000, key:1.2.3.4

---

## Snapshots Created

| VM | Snapshot | Time |
|----|-----------|------|
| hypervisor-dev | windows-installed | 2026-03-23 21:17:13 |
| windbg-debugger | win-debugger-ready | 2026-03-23 23:52:XX |

---

## Project Files

```
/home/qbibubi/dev/hypervisor/
├── linux/
│   ├── hypervisor-dev.xml      # Debuggee VM config
│   ├── windbg-debugger.xml     # Debugger VM config
│   ├── run-vm.sh               # Start script
│   └── setup-hypervisor.sh     # Setup script
├── windows/
│   ├── VmFreshInstallScript.ps1  # Post-install setup
│   └── WdkSetupScript.ps1
└── .git/                        # Git repository
```

---

## ISOs Available

```
/home/qbibubi/isos/
├── Win10_22H2_English_x64v1.iso    # Windows 10 (used)
├── Win11_25H2_English_x64.iso      # Windows 11 (not used - requires Secure Boot)
└── virtio-win-0.1.285.iso         # VirtIO drivers
```

---

## Current Development Workflow

1. **Edit code** on Arch Linux host (in /home/qbibubi/dev/hypervisor/)
2. **Build** in hypervisor-dev VM via virtiofs share (Z:\)
3. **Test** driver - expect BSODs during development
4. **Debug** via WinDbg in windbg-debugger VM
5. **Revert** to snapshot if needed:
   ```bash
   sudo virsh snapshot-revert hypervisor-dev windows-installed
   ```

---

## Commands Reference

```bash
# Start VMs
sudo virsh start hypervisor-dev
sudo virsh start windbg-debugger

# Connect to serial console
telnet 127.0.0.1 54320  # debuggee
telnet 127.0.0.1 54321  # debugger

# Connect to VNC
vncviewer 127.0.0.1:5900  # debuggee
vncviewer 127.0.0.1:5901  # debugger

# Snapshots
sudo virsh snapshot-list hypervisor-dev
sudo virsh snapshot-revert hypervisor-dev windows-installed

# Check VMs
sudo virsh list --all
sudo virsh net-dhcp-leases default
```

---

## Next Steps for Development

1. **Verify Hyper-V is running** in hypervisor-dev:
   ```powershell
   Get-ComputerInfo | Select-Object HyperV*
   ```

2. **Build your hypervisor driver** in the debuggee VM

3. **Load and test** the driver:
   ```powershell
   sc create hypervisor type= kernel binPath= C:\path\to\driver.sys
   sc start hypervisor
   ```

4. **Debug via WinDbg** when BSOD occurs

---

## Notes

- Windows 10 used instead of Windows 11 due to Secure Boot requirement in QEMU
- kdnet uses port 50000, key 1.2.3.4
- virtiofs share mounts as Z:\ in Windows VMs, pointing to /home/qbibubi/dev/hypervisor/
- Both VMs share the same libvirt network (192.168.122.0/24)