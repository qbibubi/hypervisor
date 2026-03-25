## AMD Ryzen 5 2600 — Honest Capability Assessment First

```
Ryzen 5 2600 (Zen+) Feature Matrix:
┌─────────────────────────────────┬──────────┬─────────────────────────────┐
│ Feature                         │ Status   │ Impact                      │
├─────────────────────────────────┼──────────┼─────────────────────────────┤
│ AMD-V (SVM)                     │ ✅ YES   │ Can run your SVM code path  │
│ NPT (Nested Page Tables)        │ ✅ YES   │ SLAT works                  │
│ Hardware Nested Virt (nSVM)     │ ⚠️ SOFT  │ KVM emulates, not hardware  │
│ SME / SEV                       │ ❌ NO    │ Zen 2+ only, irrelevant     │
│ Intel VMX                       │ ❌ NO    │ CANNOT test VMX path locally│
│ AVX-512                         │ ❌ NO    │ Irrelevant                  │
│ VMCB nesting acceleration       │ ❌ NO    │ Zen 2+ (Ryzen 4000+)        │
└─────────────────────────────────┴──────────┴─────────────────────────────┘

Bottom line: You can develop and test the AMD SVM path entirely locally.
Intel VMX path MUST be tested on separate hardware or cloud.
```

---

## The Full Nesting Stack on Your Machine

```
┌──────────────────────────────────────────────────┐
│  Arch Linux Host (bare metal, AMD SVM active)    │  ← Ring -1 (KVM owns hardware)
├──────────────────────────────────────────────────┤
│  KVM / QEMU (Level 0 hypervisor)                 │  ← Software SVM exposed to guest
├──────────────────────────────────────────────────┤
│  Windows 11 Dev VM (nested guest)                │
│  ┌────────────────────────────────────────────┐  │
│  │  YOUR HYPERVISOR DRIVER (VMRUN here)       │  │  ← Level 1: Your code
│  ├────────────────────────────────────────────┤  │
│  │  Microsoft Hyper-V (guest of YOUR layer)   │  │  ← Level 2: Hyper-V as guest
│  ├────────────────────────────────────────────┤  │
│  │  Windows (guest of Hyper-V)                │  │  ← Level 3: OS
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘

3 levels of nesting = SLOW but 100% functional for development
Performance is irrelevant at this stage — correctness is all that matters
```

---

## Step 1: Arch Linux Host Configuration

### Install Required Packages

```bash
# Core virtualization stack
sudo pacman -S qemu-full virt-manager libvirt dnsmasq bridge-utils \
               ebtables iptables-nft vde2 ovmf

# Development and cross-compilation tools
sudo pacman -S base-devel git cmake ninja python3 python-pip \
               mingw-w64-gcc nasm yasm

# Debugging and RE tools
sudo pacman -S gdb qemu-system-x86 wireshark-qt

# Optional but useful
sudo pacman -S bochs

# AUR: WinDbg is Windows-only, but you'll run it IN the VM
# AUR: VirtualKD-Redux for accelerated KD transport
yay -S virtualbox-ext-oracle  # Alternative sandbox if needed
```

### Enable Nested Virtualization (Critical)

```bash
# Check current nested virt status
cat /sys/module/kvm_amd/parameters/nested

# Enable permanently
sudo tee /etc/modprobe.d/kvm.conf << 'EOF'
options kvm_amd nested=1
options kvm_amd npt=1
options kvm ignore_msrs=1
options kvm report_ignored_msrs=0
EOF

# Apply without reboot
sudo modprobe -r kvm_amd && sudo modprobe kvm_amd nested=1

# Verify
cat /sys/module/kvm_amd/parameters/nested
# Must output: 1
```

### Configure libvirt

```bash
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm $(whoami)
newgrp libvirt

# Enable default network
sudo virsh net-autostart default
sudo virsh net-start default
```

---

## Step 2: QEMU VM Configuration for Maximum Nesting Compatibility

The VM XML configuration is critical — wrong CPU flags will break nested Hyper-V entirely.

```xml
<!-- Save as: /etc/libvirt/qemu/hypervisor-dev.xml -->
<!-- Key settings explained inline -->

<domain type='kvm'>
  <name>hypervisor-dev</name>
  <memory unit='GiB'>16</memory>       <!-- Minimum 16GB for 3-level nesting -->
  <vcpu placement='static'>8</vcpu>    <!-- Give it plenty of vCPUs -->
  
  <cpu mode='host-passthrough' check='none' migratable='off'>
    <!-- host-passthrough: exposes ALL host CPU features including SVM -->
    <!-- This is NON-NEGOTIABLE for nested virt to work -->
    <feature policy='require' name='svm'/>
    <feature policy='require' name='hypervisor'/>
    <feature policy='require' name='topoext'/>
    <!-- Hyper-V enlightenments for the outer layer -->
    <feature policy='require' name='hv-relaxed'/>
    <feature policy='require' name='hv-vapic'/>
    <feature policy='require' name='hv-time'/>
    <feature policy='disable' name='hv-evmcs'/>
    <!-- evmcs MUST be disabled — it breaks your nested hypervisor -->
  </cpu>

  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <loader readonly='yes' type='pflash'>
      /usr/share/edk2/x64/OVMF_CODE.4m.fd  <!-- UEFI: required for Secure Boot testing -->
    </loader>
    <nvram template='/usr/share/edk2/x64/OVMF_VARS.4m.fd'>
      /var/lib/libvirt/qemu/nvram/hypervisor-dev_VARS.fd
    </nvram>
    <bootmenu enable='yes'/>
  </os>

  <features>
    <acpi/>
    <apic/>
    <hyperv mode='custom'>
      <!-- Expose Hyper-V enlightenments to make Windows happy as nested guest -->
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
      <vpindex state='on'/>
      <runtime state='on'/>
      <synic state='on'/>
      <stimer state='on'/>
      <reset state='on'/>
      <vendor_id state='on' value='KVM Hv'/>
      <frequencies state='on'/>
      <reenlightenment state='off'/>   <!-- off: prevents QEMU intercepting your hypervisor's hypercalls -->
      <tlbflush state='on'/>
      <ipi state='on'/>
      <evmcs state='off'/>             <!-- MUST BE OFF -->
    </hyperv>
    <kvm>
      <hidden state='on'/>  <!-- Hides KVM from Windows; cleaner testing -->
    </kvm>
    <vmport state='off'/>
    <smm state='on'/>       <!-- Required for Secure Boot -->
  </features>

  <!-- Disk: VirtIO for performance -->
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='writeback' io='threads'/>
      <source file='/var/lib/libvirt/images/hypervisor-dev.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>

    <!-- Network: VirtIO + dedicated debug network -->
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    
    <!-- Secondary NIC for kdnet debugging (isolated) -->
    <interface type='network'>
      <source network='default'/>
      <model type='e1000e'/>    <!-- e1000e: WinDbg kdnet works reliably with this -->
      <mac address='52:54:00:DE:AD:01'/>
    </interface>

    <!-- Serial port for emergency console -->
    <serial type='tcp'>
      <source mode='bind' host='127.0.0.1' service='54320'/>
      <protocol type='telnet'/>
      <target type='isa-serial' port='0'/>
    </serial>

    <!-- TPM emulation (for testing TPM interactions) -->
    <tpm model='tpm-crb'>
      <backend type='emulator' version='2.0'/>
    </tpm>
  </devices>
</domain>
```

### Create the VM Disk

```bash
# 120GB thin-provisioned disk
sudo qemu-img create -f qcow2 \
  /var/lib/libvirt/images/hypervisor-dev.qcow2 120G

# Define the VM
sudo virsh define /etc/libvirt/qemu/hypervisor-dev.xml
```

---

## Step 3: Windows VM Setup

### Windows Installation Requirements

```
Windows Version: Windows 11 Pro or Enterprise (NOT Home - no Hyper-V)
  OR: Windows Server 2022 (better for headless/server workflows)

Recommended: Windows 11 Enterprise Evaluation
  → 90-day free eval, full features including Hyper-V
  → https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise

ISO: Download via aria2c or wget directly
```

### Post-Install Windows Configuration

```powershell
# Run all of this in elevated PowerShell inside the VM

# 1. Enable Hyper-V
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart

# 2. Enable test signing (CRITICAL for unsigned driver loading during development)
bcdedit /set testsigning on

# 3. Disable driver signature enforcement for dev (alternative to test signing)
# bcdedit /set nointegritychecks on  # More aggressive, use if testsigning insufficient

# 4. Enable kernel debugging over network
bcdedit /dbgsettings net hostip:10.0.2.2 port:50000 key:1.2.3.4
bcdedit /debug on

# 5. Disable automatic restart on BSOD (you want to READ the crash)
bcdedit /set recoveryenabled no
wmic recoveros set AutoReboot = False

# 6. Increase crash dump verbosity
# Set to "Complete memory dump" in System Properties → Advanced → Startup and Recovery

# 7. Optional: Disable HVCI for initial development (re-enable to test compatibility)
# bcdedit /set hypervisorlaunchtype off   # Disable Hyper-V entirely for isolated AMD-V testing
# bcdedit /set hypervisorlaunchtype auto  # Re-enable Hyper-V

# 8. Verify SVM is visible to Windows inside VM
Get-ComputerInfo | Select-Object HyperV*
```

---

## Step 4: WDK Development Environment Inside Windows VM

```powershell
# Install via winget (run inside Windows VM)
winget install Microsoft.VisualStudio.2022.Community
winget install Microsoft.WindowsSDK.10.0.22621
winget install Microsoft.WindowsWDK.10.0.22621
winget install Microsoft.WinDbg

# Alternatively via Chocolatey:
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install visualstudio2022community -y
choco install windows-sdk-10.1 -y
choco install windbg -y
choco install nasm -y
```

### Shared Folder: Code on Arch, Build in VM

```bash
# On Arch host - set up virtiofs or samba share for code sharing
# Option 1: virtiofs (modern, fast)
sudo pacman -S virtiofsd

# Add to VM XML:
# <filesystem type='mount' accessmode='passthrough'>
#   <driver type='virtiofs'/>
#   <source dir='/home/youruser/hypervisor-project'/>
#   <target dir='hypervisor'/>
# </filesystem>

# Option 2: Simple samba (more compatible)
sudo pacman -S samba
sudo tee /etc/samba/smb.conf << 'EOF'
[hypervisor]
   path = /home/youruser/hypervisor-project
   browseable = yes
   read only = no
   guest ok = yes
EOF
sudo systemctl enable --now smb nmb
```

---

## Step 5: Debugging Setup (WinDbg ↔ KD over kdnet)

### On Arch Host — Forward kdnet Port

```bash
# QEMU exposes the VM network via NAT by default
# The kdnet port (50000) must reach your WinDbg instance

# If running WinDbg on a separate Windows machine on same network:
# Nothing to do — use the VM's IP directly

# If debugging from within the VM itself using a second Windows instance:
# Set up a dedicated host-only network in libvirt for kdnet

# Verify kdnet is reachable
sudo virsh domifaddr hypervisor-dev
# Note the VM IP, use that as debuggee address in WinDbg
```

### WinDbg Connection Command

```
# Run in WinDbg on your debug machine (inside the VM or on network)
windbg -k net:port=50000,key=1.2.3.4

# Or in WinDbg Preview:
# File → Attach to kernel → Net
# Port: 50000, Key: 1.2.3.4
```

### Serial Console Fallback (When KD Network Fails)

```bash
# On Arch host — connect to serial console
telnet 127.0.0.1 54320

# This gives you an emergency console when your hypervisor
# breaks networking (which will happen frequently)
```

---

## Step 6: Intel VMX Testing Strategy (Critical Gap)

Since your Ryzen 5 2600 cannot test VMX, you need a parallel strategy:

### Option A: Cloud Intel Instance (Recommended)

```
AWS EC2:
  Instance type: c5.metal or c5n.metal (bare metal, Intel Xeon)
  OR: c5.2xlarge (supports nested virt, not bare metal)
  
  Enable nested virt:
  aws ec2 modify-instance-attribute \
    --instance-id i-xxxx \
    --attribute sriovNetSupport \
    --value simple

Azure:
  VM size: Standard_D4s_v3 or higher (supports nested virt)
  Intel Xeon processors
  Hyper-V is already the underlying hypervisor on Azure
  → Testing your layer on top of Azure Hyper-V = perfect scenario

GitHub Actions:
  Free for open source
  Windows runners are Hyper-V guests on Intel
  → CI/CD pipeline: commit → auto-build → auto-test on Intel
```

### Option B: Second-Hand Intel Dev Machine

```
Minimum spec for Intel VMX testing:
  → Any Intel CPU with VT-x (Haswell+ preferred for VMCS shadowing)
  → Intel Core i5-4xxx or newer (~€30-50 used)
  → 8GB RAM minimum
  → No GPU needed — headless Windows Server install is fine
  
  Recommended: Intel NUC (compact, cheap, VT-x, Ethernet for kdnet)
```

### Option C: Abstract Early, Test Intel in CI

```
Strategy:
  1. Write full AMD SVM implementation and validate locally
  2. Write Intel VMX implementation behind compile-time abstraction
  3. CI pipeline on GitHub Actions (Intel runners) validates VMX path
  4. Only test VMX locally when you acquire Intel hardware
```

---

## Step 7: Project Repository Structure

```
hypervisor-project/
├── src/
│   ├── core/
│   │   ├── cpu_abstraction.h       ← AMD/Intel unified interface
│   │   ├── cpu_abstraction.c
│   │   ├── vmx/                    ← Intel VMX implementation
│   │   │   ├── vmx_init.c          ← VMXON, VMCS setup
│   │   │   ├── vmx_vmexit.c        ← VM-exit dispatcher
│   │   │   ├── vmx_cpuid.c         ← CPUID handler (your command channel)
│   │   │   └── vmx_asm.asm         ← VMLAUNCH, VMRESUME, host state save
│   │   ├── svm/                    ← AMD SVM implementation  
│   │   │   ├── svm_init.c          ← VMRUN setup, VMCB allocation
│   │   │   ├── svm_vmexit.c        ← #VMEXIT dispatcher
│   │   │   ├── svm_cpuid.c         ← CPUID handler
│   │   │   └── svm_asm.asm         ← VMLOAD, VMSAVE, VMRUN stubs
│   │   └── command_channel/
│   │       ├── dispatcher.c         ← Key discrimination logic
│   │       ├── commands.h           ← Command ID definitions
│   │       └── passthrough.c        ← Hyper-V transparent passthrough
│   ├── driver/
│   │   ├── driver_entry.c           ← DriverEntry, boot-start setup
│   │   ├── per_cpu_init.c           ← KeIpiGenericCall VMXON/VMRUN per LP
│   │   └── driver.inf
│   └── client/
│       ├── client_lib.c             ← Usermode/kernel library for invoking channel
│       └── client_lib.h
├── build/
│   ├── CMakeLists.txt               ← Or use WDK .vcxproj
│   └── sign.bat                     ← Test signing script
├── debug/
│   ├── windbg_scripts/              ← WinDbg automation scripts
│   └── hyperdbg_scripts/            ← HyperDbg companion scripts
├── docs/
│   ├── architecture.md
│   └── cpuid_channel_protocol.md
└── tests/
    ├── test_cpuid_channel.c          ← Unit tests for command channel
    └── test_passthrough.c            ← Verify Hyper-V still works
```

---

## Recommended Daily Development Workflow

```
┌─────────────────────────────────────────────────────────┐
│  1. Edit code on Arch Linux (your preferred editor)     │
│     VSCode with clangd, or vim/neovim + clang-format    │
├─────────────────────────────────────────────────────────┤
│  2. Build inside Windows VM via shared folder           │
│     msbuild or cmake + WDK toolchain                    │
│     → Produces signed .sys file                         │
├─────────────────────────────────────────────────────────┤
│  3. Install driver in Windows VM                        │
│     sc create / sc start                                │
│     → BSOD expected frequently at this stage            │
├─────────────────────────────────────────────────────────┤
│  4. Debug via WinDbg kdnet from Arch host               │
│     (WinDbg runs in a second lightweight Windows VM     │
│      OR on bare metal Windows if available)             │
├─────────────────────────────────────────────────────────┤
│  5. On BSOD → VM auto-recovers (QEMU snapshot)          │
│     Take snapshot before each test:                     │
│     virsh snapshot-create-as hypervisor-dev "pre-test"  │
│     virsh snapshot-revert hypervisor-dev "pre-test"     │
├─────────────────────────────────────────────────────────┤
│  6. Commit → GitHub Actions runs Intel VMX CI           │
└─────────────────────────────────────────────────────────┘
```

### Snapshot-Based Crash Recovery (Non-Negotiable)

```bash
# ALWAYS snapshot before loading a new driver build
alias hv-snap='virsh snapshot-create-as hypervisor-dev "$(date +%H%M%S)-pre-load"'
alias hv-revert='virsh snapshot-revert hypervisor-dev $(virsh snapshot-list hypervisor-dev --name | tail -1)'

# Add to ~/.bashrc
echo "alias hv-snap='virsh snapshot-create-as hypervisor-dev \"\$(date +%H%M%S)-pre-load\"'" >> ~/.bashrc
echo "alias hv-revert='virsh snapshot-revert hypervisor-dev \$(virsh snapshot-list hypervisor-dev --name | tail -1)'" >> ~/.bashrc
```

---

## Ryzen 5 2600 Specific Gotchas

```
1. SVM VMCB nesting is software-emulated in KVM on Zen+
   → Expect 10-20x slowdown in nested context vs bare metal
   → Irrelevant for correctness testing

2. No hardware AVIC (AMD Virtual APIC) passthrough in nested config
   → APIC virtualization in your hypervisor must be software path
   → Test with AVIC disabled initially

3. RDTSC timing will be severely skewed at 3 nesting levels
   → Implement RDTSC intercept/correction early
   → Required for any timing-dependent code in your hypervisor

4. KVM will handle some SVM exits itself before passing to your layer
   → Some CPUID leaves KVM intercepts transparently
   → Verify your command channel CPUID leaf is NOT one KVM handles
   → Test with: kvm_amd.nested=1 and check which exits reach your handler

5. The VMCB npt field: on Zen+, NPT works but nested NPT (nNPT) 
   is emulated — correctness is fine, performance is poor
```

This gives you a complete, reproducible environment. The most important immediate action is enabling nested virtualization in KVM and validating that 3-level nesting works before writing any hypervisor code — run NoirVisor inside your QEMU Windows VM first to confirm the stack functions correctly as a baseline.