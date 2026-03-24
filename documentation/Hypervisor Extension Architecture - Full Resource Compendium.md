# Hypervisor Extension Architecture: Full Resource Compendium

## Preliminary Architectural Analysis

Before listing resources, let me map the architectural considerations you raised:

---

### TPM Role & How This Approach Sidesteps It

TPM (Trusted Platform Module) participates in **Measured Boot** — it records SHA hashes of each boot stage (firmware → bootloader → OS loader → kernel → drivers) into PCR registers. BitLocker and remote attestation rely on these PCR values. The exception-handler hooking technique at the hypervisor layer operates **after TPM measurement has finalized** — the hook lives in runtime memory, not in any measured binary. The hypervisor binary itself (`hvix64.exe`/`hvax64.exe`) is measured, but **runtime pointer manipulation of in-memory handler tables is not re-measured**. This is the same reason .data pointer swaps survive in the kernel — TPM does not perform live memory attestation.

However: **DRTM (Dynamic Root of Trust for Measurement)** via Intel TXT or AMD SKINIT can perform late-launch measurements. This is a potential concern if the target environment uses DRTM-based attestation.

---

### Secure Boot Role & Compatibility

Secure Boot validates the **signature of PE images** before execution. It does **not** validate in-memory state after launch. Since your approach does not load an additional unsigned PE image at boot (the hook is applied to already-loaded and already-verified Hyper-V code by patching its exception dispatch tables at runtime from a signed driver or from within the hypervisor's own execution context), Secure Boot is not violated. The catch: the **driver or mechanism that performs the patching** must itself be signed (WHQL or EV-signed for production, test-signed in dev with `bcdedit /set testsigning on`). HVCI complicates this significantly (detailed below).

---

### Developer Debugging Environment

|Tool|Purpose|
|---|---|
|WinDbg Preview (kernel mode)|Primary hypervisor-level debugger|
|Hyper-V synthetic debugger transport|Debug the root partition's kernel|
|Serial/COM/network KD transport|For debugging VMXROOT context|
|VMware Workstation (nested Hyper-V)|Safe sandbox for development|
|Intel HAXM / WHPX|Alternative acceleration for nested testing|
|SoftICE legacy patterns → modern HVDBG|Conceptual reference|

---

## SECTION 1: Foundational Hypervisor Architecture

### Intel VT-x (VMX)

|Resource|Description|Link|
|---|---|---|
|Intel SDM Vol. 3C|Full VMX instruction reference, VMCS fields, exception handling, VM-exit reasons|https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html|
|Intel SDM Chapter 25-34|VMX operation, VMCS layout, exception bitmap, IDT vectoring info fields|Same as above|
|Intel VMX Primer (Reverse Osmosis)|Accessible walkthrough of VMX operation|https://revers.engineering/creating-a-simple-hypervisor/|
|"Blue Pill" original paper - Rutkowska|First public proof-of-concept of transparent hypervisor injection|https://bluepillproject.org/|
|SimpleVisor (Alex Ionescu)|Clean-room minimal Hyper-V-compatible hypervisor implementation in C|https://github.com/ionescu007/SimpleVisor|
|HyperPlatform (Satoshi Tanda)|Production-grade research hypervisor, exception handling included|https://github.com/tandasat/HyperPlatform|

### AMD SVM (AMD-V)

|Resource|Description|Link|
|---|---|---|
|AMD APM Vol. 2 (Chapter 15)|SVM architecture, VMCB layout, #VMEXIT codes, exception intercepts|https://www.amd.com/system/files/TechDocs/24593.pdf|
|AMD VMCB vs Intel VMCS diff analysis|Critical for cross-platform development|https://github.com/tandasat/HyperPlatform/blob/master/HyperPlatform/vmm.cpp|
|AMD SVM Tutorial - OSdev Wiki|Entry-level SVM setup|https://wiki.osdev.org/SVM|
|AMD SEV-SNP documentation|Relevant if targeting encrypted VM environments|https://www.amd.com/system/files/TechDocs/SEV-SNP-strengthening-vm-isolation-with-integrity-protection-and-more.pdf|

---

## SECTION 2: Microsoft Hyper-V Internals

### Core Architecture Documents

|Resource|Description|Link|
|---|---|---|
|Windows Internals 7th Ed. Part 1 & 2 (Yosifovich, Ionescu et al.)|Chapter on Hyper-V architecture, VTL, SLAT|https://www.microsoftpressstore.com/store/windows-internals-part-1-9780735684188|
|Hyper-V Top-Level Functional Spec (TLFS)|Microsoft's own specification of Hyper-V hypercall interface, synthetic MSRs, partitions|https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/reference/tlfs|
|Hyper-V TLFS PDF (direct)|Full specification document|https://github.com/MicrosoftDocs/Virtualization-Documentation/raw/master/tlfs/Hypervisor%20Top%20Level%20Functional%20Specification%20v6.0b.pdf|
|hvix64.exe / hvax64.exe Reverse Engineering|Community reverse engineering of Hyper-V binary|https://github.com/gerhart01/Hyper-V-Internals|
|Hyper-V Internals (gerhart01)|Comprehensive collection of RE findings on Hyper-V internals|https://github.com/gerhart01/Hyper-V-Internals|
|"Fuzzing Hyper-V" - Microsoft Security Blog|Attack surface analysis useful for understanding exception dispatch paths|https://msrc.microsoft.com/blog/2019/01/fuzzing-para-virtualized-devices-in-hyper-v/|

### Exception Handling in Hyper-V Context

|Resource|Description|Link|
|---|---|---|
|Hyper-V IDT structure analysis|How Hyper-V installs its own IDT in VMX root mode|Analysis in gerhart01 repo above|
|VTL (Virtual Trust Level) architecture|Critical: Hyper-V uses VTLs, your hook must respect VTL0/VTL1 boundaries|https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/reference/tlfs|
|Exception bitmap in VMCS|Controls which exceptions cause VM-exits to hypervisor|Intel SDM Table 24-3|
|IDT vectoring information field|Describes in-progress exception delivery at VM-exit|Intel SDM Section 27.2.4|
|Nt Exception Dispatch internals|How Windows exception dispatch works before hypervisor intercept|https://github.com/ntdevlabs/ntinternals|

---

## SECTION 3: The .data Pointer Swap Technique & Exception Handler Hooking

### Kernel .data Pointer Swap References

|Resource|Description|Link|
|---|---|---|
|"Bypassing PatchGuard" - Alex Ionescu talk|Historical and technical overview of PatchGuard and pointer swap techniques|https://github.com/ionescu007/HookCase/blob/master/HookCase/HookCase.cpp (conceptual reference)|
|PatchGuard Internals (Alex Ionescu)|Deep dive into what PatchGuard monitors and what it misses|https://www.alex-ionescu.com/fun-with-patchguard/|
|Windows Kernel Rootkits - Skape/Skywing|Classic paper establishing .data hooking patterns|http://www.uninformed.org/?v=3&a=3|
|"The Art of Hook" - Bruce Dang|Hook detection and implementation at kernel level|https://github.com/bruce30262/windows-kernel-exploitation|
|SSDT Hook vs .data Hook comparison|Why .data avoids PatchGuard's code integrity checks|https://revers.engineering/patchguard-detection-of-hypervisor-based-introspection-p1/|

### Applying This to Hyper-V Exception Handlers

The core concept maps as follows:

```
Windows kernel .data hook:
  → Find function pointer in .data section of ntoskrnl
  → Replace with custom handler pointer  
  → Original call semantics preserved with key discrimination

Hyper-V exception handler hook:
  → Locate exception dispatch table in Hyper-V's VMX-root IDT
  → Replace handler pointer (in LSTAR MSR or IDT descriptor) in .data equivalent
  → Custom handler checks "key" embedded in exception record (e.g., specific 
    error code, RIP range, or synthetic exception code)
  → Legitimate exceptions pass through; keyed exceptions go to custom path
```

|Resource|Description|Link|
|---|---|---|
|LSTAR MSR hooking analysis|SYSCALL handler hooking - structural analog to exception hook|https://revers.engineering/syscall-hooking-via-extended-feature-enable-register-0/|
|IDT hooking in VMX root|Setting interrupt descriptors from within hypervisor|https://github.com/tandasat/HyperPlatform/blob/master/HyperPlatform/ept.cpp|
|Synthetic exception patterns in hypervisors|How CPUID-based and #UD-based hypervisor communication works|https://github.com/ionescu007/SimpleVisor/blob/master/SimpleVisor.c|

---

## SECTION 4: PatchGuard (KPP), HVCI, DSE — The Roadblocks

### PatchGuard (Kernel Patch Protection)

|Resource|Description|Link|
|---|---|---|
|PatchGuard reverse engineering (detailed)|Full analysis of KPP initialization, verification threads, and what it checks|https://github.com/everdox/InfinityHook (includes PG analysis)|
|InfinityHook|Production example of hooking from hypervisor layer that bypasses PatchGuard|https://github.com/everdox/InfinityHook|
|PatchGuard Timer DPC analysis|How PG schedules validation and what triggers BSOD 0x109|https://www.codeproject.com/Articles/68823/Introduction-to-Windows-kernel-patch-protection|
|"Defeating PatchGuard" - x86matthew|Updated analysis for Windows 10/11 PG variants|https://www.x86matthew.com/view_post?id=patchguard|
|PG response to hypervisor hooks|Whether PG detects VMX-root IDT modifications|Analysis: PG runs in VTL0, cannot observe VMX-root structures|

**Critical insight**: PatchGuard operates in VTL0 (guest ring-0). IDT modifications made in VMX-root mode (ring -1) are **not visible** to PatchGuard. However, if your hook path causes visible changes to guest-observable state (modified guest IDT, modified LSTAR visible to RDMSR), PatchGuard **will** detect it.

### HVCI (Hypervisor-Protected Code Integrity)

|Resource|Description|Link|
|---|---|---|
|HVCI Architecture Overview|How HVCI uses the hypervisor to enforce NX on kernel pages|https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-hvci-enablement|
|HVCI Bypass Research|Academic/research analysis of HVCI limitations|https://github.com/fengjixuchui/HVCI-Research|
|HVCI and unsigned code|Why HVCI prevents executing unsigned code in kernel, impact on hooking|https://github.com/tandasat/CVE-2022-34718 (case study)|
|Second-Level Address Translation (SLAT/EPT/NPT)|HVCI uses EPT to mark kernel pages as non-writable; your hook must handle this|Intel SDM Chapter 28; AMD APM Chapter 15|
|"HVCI: Under the Hood" - KA Summit|Conference talk on HVCI internals|https://github.com/gerhart01/Hyper-V-Internals/blob/master/Docs/|

**HVCI is your biggest roadblock.** If HVCI is enabled:

- Kernel pages are read-only from the hypervisor's own nested page tables
- You cannot patch code (consistent with your .data approach — pointer swaps in writable .data sections may still be viable)
- Any JIT or dynamic code execution requires HVCI-aware design

### Driver Signature Enforcement (DSE)

|Resource|Description|Link|
|---|---|---|
|DSE internals - g_CiEnabled analysis|How DSE checks `g_CiEnabled` in ci.dll|https://github.com/hfiref0x/DSEFix|
|WHQL signing process|Obtaining legitimate signatures for kernel drivers|https://learn.microsoft.com/en-us/windows-hardware/drivers/install/kernel-mode-code-signing-walkthrough|
|EV Certificate for kernel signing|Required for production deployment without test mode|https://learn.microsoft.com/en-us/windows-hardware/drivers/dashboard/get-a-code-signing-certificate|
|DSEFix (historical reference)|Technique for disabling DSE (now patched, educational value)|https://github.com/hfiref0x/DSEFix|

---

## SECTION 5: AMD vs Intel Architectural Differences

This is **non-trivial** and a common source of hypervisor bugs.

### Critical Divergence Points

|Feature|Intel VMX|AMD SVM|Reference|
|---|---|---|---|
|Control structure|VMCS (region, accessed via VMREAD/VMWRITE)|VMCB (memory-mapped struct)|SDM Ch.24 / APM Ch.15|
|Exception intercept|Exception bitmap in VMCS 0x4004|Exception intercepts in VMCB offset 0x3C|Both arch manuals|
|APIC virtualization|Posted interrupts, APICv optional|AVIC (AMD Virtual APIC)|SDM Ch.29 / APM Ch.15.21|
|Nested paging|EPT (Extended Page Tables)|NPT (Nested Page Tables)|SDM Ch.28 / APM Ch.15.25|
|MSR bitmap|4KB bitmap in VMCS|2× 2KB bitmaps in VMCB|SDM 24.6.9 / APM 15.11|
|VM-exit reason|32-bit field, reason codes Intel-specific|64-bit EXITCODE in VMCB|Different code values!|
|CPUID faulting|Available in both|Available in both|Same concept, different impls|
|#VMEXIT on INT3|Exception bitmap bit 3|Exception intercept bit 3|Same bit position|
|VMXON/VMXOFF|Required, sets VMX root mode|VMRUN implicit root switch|Fundamental op difference|
|Hypercall mechanism|VMCALL|VMMCALL|Different mnemonics|

### Resources for Cross-Platform Abstraction

|Resource|Description|Link|
|---|---|---|
|Hypervisor From Scratch (Sina Karvandi)|8-part series covering both Intel and AMD with abstraction layer|https://rayanfam.com/topics/hypervisor-from-scratch-part-1/|
|hvpp (hypervisor ++)|C++ hypervisor with clean AMD/Intel abstraction|https://github.com/wbenny/hvpp|
|KasperskyHV analysis|Production hypervisor abstraction patterns|Not public, but referenced in academic papers|
|AMD vs Intel Virtualization Feature Matrix|Side-by-side comparison table|https://en.wikipedia.org/wiki/X86_virtualization#AMD_virtualization_(AMD-V)|
|"Writing a Hypervisor" - Connor McGarr|Modern practical walkthrough|https://connormcgarr.github.io/hvpp/|
|Bareflank Hypervisor|Open-source hypervisor SDK with AMD/Intel abstraction|https://github.com/Bareflank/hypervisor|

---

## SECTION 6: Debugging Environment Setup

### WinDbg & Kernel Debugging

|Resource|Description|Link|
|---|---|---|
|WinDbg Preview|Primary tool for kernel/hypervisor debugging|https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/|
|Hyper-V VM debugging setup|Configuring KD over network/serial for Hyper-V guest|https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/setting-up-network-debugging-of-a-virtual-machine-host|
|Debugging the root partition|Using kernel debugger on the root Hyper-V partition|https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization|
|KD extensions for Hyper-V|`!vmcs`, `!vtop`, and virtualization-specific commands|WinDbg built-in + community extensions|
|LiveKd (Sysinternals)|Kernel debugging without reboot, useful for hypervisor state inspection|https://learn.microsoft.com/en-us/sysinternals/downloads/livekd|
|kdnet setup for Hyper-V|Network kernel debugging across VM boundary|https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/setting-up-a-network-debugging-connection|

### Hypervisor-Specific Debugging

|Resource|Description|Link|
|---|---|---|
|HVDBG|Open-source hypervisor debugger|https://github.com/hvdbg/hvdbg|
|HyperDbg|Modern hypervisor-based debugger (very relevant to your project)|https://github.com/HyperDbg/HyperDbg|
|HyperDbg documentation|Full documentation including exception handling hooks|https://docs.hyperdbg.org/|
|VirtualKD-Redux|Accelerated kernel debugging under VMware/VirtualBox (nested development)|https://github.com/4d61726b/VirtualKD-Redux|
|QEMU + GDB for hypervisor debugging|Alternative low-level approach|https://wiki.qemu.org/Documentation/Debugging|
|Bochs with instrumentation|Full-system emulation with complete visibility|https://bochs.sourceforge.io/|

**Recommended development environment:**

```
Host (bare metal, Intel/AMD with VT-x/AMD-V)
  └─ VMware Workstation Pro (with VT-x nested virt passthrough)
       └─ Windows 11 Dev VM (Hyper-V enabled, nested)
            └─ Your hypervisor extension loaded
                 └─ WinDbg over kdnet from host
```

---

## SECTION 7: The Key-Value Exception Discrimination Mechanism

This is the core novel mechanism — analogous to .data pointer swap but applied to Hyper-V's exception dispatch chain.

### Structural Analogies & Implementation Patterns

|Resource|Description|Link|
|---|---|---|
|CPUID-based hypervisor communication|Standard pattern: guest executes CPUID with magic EAX, hypervisor intercepts and returns custom data|https://github.com/ionescu007/SimpleVisor/blob/master/SimpleVisor.c#L1|
|#VMEXIT on #UD (Invalid Opcode)|Using undefined instruction exceptions as communication channel|Multiple hypervisor codebases|
|#VMEXIT on #GP with specific error codes|General Protection Fault with crafted error codes as signaling|Intel SDM Table 6-15 (error code format)|
|Exception record structure (EXCEPTION_RECORD)|Windows-side structure carrying exception code, address, parameters|https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-exception_record|
|KiDispatchException internals|Windows exception dispatch path before reaching hypervisor|https://github.com/ntdevlabs/ntinternals|
|INT 2E / SYSCALL as analog|How Windows previously used software interrupts for system calls — structural analog|Documented in Windows Internals book|
|VMware backdoor port (0x5658)|Production example of guest-hypervisor communication channel|https://wiki.osdev.org/VMware_tools|

### Designing the Key Discrimination

For your specific mechanism (exception with predesigned data → custom hypervisor handler):

```
Design choices for the "key":
1. Exception code in EXCEPTION_RECORD.ExceptionCode (custom range 0xE0000000+)
2. Specific RIP value (trap to known address)
3. Exception parameter array (ExceptionInformation[0] = MAGIC_KEY)
4. Specific combination: exception type + error code + faulting address
5. VMCS guest register state signature (RAX/RBX pattern at exception time)
```

|Resource|Description|Link|
|---|---|---|
|RaiseException() internals|How usermode raises structured exceptions caught by kernel/hypervisor|https://learn.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-raiseexception|
|EXCEPTION_RECORD layout|Full field documentation for crafting recognizable exceptions|https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-exception_record|
|NtRaiseException (native API)|Kernel-mode exception raising — more direct path to hypervisor|Documented in Process Hacker source|
|SEH (Structured Exception Handling) internals|Full dispatch chain from hardware to user handler|https://www.openrce.org/articles/full_view/21|
|VEH (Vectored Exception Handling) position|VEH fires before SEH, relevant to interception ordering|https://learn.microsoft.com/en-us/windows/win32/debug/vectored-exception-handling|

---

## SECTION 8: Hyper-V Hypercall Interface & Synthetic MSRs

|Resource|Description|Link|
|---|---|---|
|Hyper-V Hypercall ABI|Full specification of hypercall calling convention, input/output pages|TLFS Section 3|
|Hyper-V synthetic MSRs|HV_X64_MSR_GUEST_OS_ID, HV_X64_MSR_HYPERCALL, etc.|TLFS Appendix B|
|Hypercall input/output page setup|Memory-mapped communication between guest and hypervisor|TLFS Section 4|
|VMCALL/VMMCALL instruction|How guest triggers hypervisor entry|Intel SDM / AMD APM|
|HV enlightenments|How Hyper-V communicates capabilities to guest OS|https://github.com/torvalds/linux/blob/master/arch/x86/hyperv/|
|Linux Hyper-V driver source|Clean reference implementation of hypercall interface|https://github.com/torvalds/linux/tree/master/drivers/hv|

---

## SECTION 9: Security Concerns & Threat Model

### From Windows/Hyper-V Perspective

|Concern|Description|Reference|
|---|---|---|
|Credential Guard|Uses VTL1 to protect LSA secrets; your extension must not accidentally violate VTL isolation|https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/|
|Device Guard|Policy enforcement via HVCI; impacts code execution in kernel|https://learn.microsoft.com/en-us/windows/security/threat-protection/device-guard/introduction-to-device-guard-virtualization-based-security-and-windows-defender-application-control|
|Hyper-V Attack Surface|VSM, VMWP, VMBus attack surface; your extension increases it|https://msrc.microsoft.com/blog/2019/01/fuzzing-para-virtualized-devices-in-hyper-v/|
|KASLR bypass implications|If your exception hook leaks kernel addresses|https://www.grsecurity.net/kaslr_an_exercise_in_cargo_cult_security|
|Race conditions in IDT modification|SMP (multi-processor) race during hook installation|Standard SMP synchronization references|
|NMI handling in VMX root|Non-Maskable Interrupts require special handling in VMX root, risk of hang|Intel SDM Section 25.5|
|Machine Check Exception (MCE) in VMX root|Must be handled or forwarded correctly|Intel SDM Section 25.5.1|

### Potential Detection Vectors

|Vector|Description|Mitigation|
|---|---|---|
|Hypervisor presence detection|CPUID.1:ECX[31] (hypervisor present bit) already set by Hyper-V|Not a new issue|
|Timing attacks|RDTSC anomalies when VM-exit occurs|Handle RDTSC via VMX controls|
|VMCS/VMCB inspection|Malicious VMs trying to enumerate VMCS fields|Proper nested virtualization handling|
|EPT violation patterns|Unusual EPT fault patterns revealing hook presence|Careful EPT management|

---

## SECTION 10: Key Academic Papers & Conference Talks

|Paper/Talk|Authors|Venue|Link|
|---|---|---|---|
|"A Hypervisor-Based Security Monitor"|Garfinkel & Rosenblum|SOSP 2003|https://dl.acm.org/doi/10.1145/945445.945464|
|"Blue Pill" hypervisor rootkit|Joanna Rutkowska|Black Hat 2006|https://www.blackhat.com/presentations/bh-usa-06/BH-US-06-Rutkowska.pdf|
|"Hardware Virtualization Rootkits"|Dino Dai Zovi|Black Hat 2006|https://www.blackhat.com/presentations/bh-usa-06/BH-US-06-Zovi.pdf|
|"Stealthy Malware Detection Through VMM-based Out-of-the-Box Semantic View Reconstruction"|CCS 2007|Multiple authors|Search ACM DL|
|"HyperSafe: Lightweight Approach to Provide Lifetime Hypervisor Control-Flow Integrity"|IEEE S&P 2010|Wang & Jiang|https://ieeexplore.ieee.org/document/5504784|
|"Breaking Hyper-V through Hypercall"|Hou & Shen|Black Hat Asia 2017|https://www.blackhat.com/docs/asia-17/materials/asia-17-Hou-Breaking-The-x86-Instruction-Decoder-For-Fun-And-Profit.pdf|
|"Hyper-V Fuzzing"|Nicholas Ottens|Hardwear.io 2021|Search YouTube/conference archives|
|"AMD SEV-SNP: Strengthening VM Isolation"|AMD|Whitepaper|https://www.amd.com/system/files/TechDocs/SEV-SNP-strengthening-vm-isolation-with-integrity-protection-and-more.pdf|

---

## SECTION 11: Open-Source Reference Implementations

|Project|Description|Stars/Activity|Link|
|---|---|---|---|
|**HyperDbg**|Modern hypervisor debugger, most architecturally similar to your project|Active|https://github.com/HyperDbg/HyperDbg|
|**SimpleVisor**|Minimal Hyper-V-aware hypervisor by Alex Ionescu|Mature|https://github.com/ionescu007/SimpleVisor|
|**HyperPlatform**|Research-grade hypervisor, extensive exception handling|Active|https://github.com/tandasat/HyperPlatform|
|**hvpp**|C++ hypervisor with clean abstractions|Mature|https://github.com/wbenny/hvpp|
|**Bareflank**|SDK-style hypervisor framework|Active|https://github.com/Bareflank/hypervisor|
|**ACRN**|Production hypervisor (IoT focus) for reference|Active|https://github.com/projectacrn/acrn-hypervisor|
|**InfinityHook**|Hyper-V based syscall hooking (closest .data analog)|Mature|https://github.com/everdox/InfinityHook|
|**NoirVisor**|Multi-platform research hypervisor (AMD+Intel)|Active|https://github.com/Zero-Tang/NoirVisor|
|**Hyperbone**|Lightweight hypervisor|Reference|https://github.com/DarthTon/HyperBone|

---

## SECTION 12: Development Toolchain

|Tool|Version/Notes|Link|
|---|---|---|
|Windows Driver Kit (WDK)|Latest matching your target OS build|https://learn.microsoft.com/en-us/windows-hardware/drivers/download-the-wdk|
|Visual Studio 2022 + WDK extension|Primary IDE for kernel driver development|https://visualstudio.microsoft.com/|
|Windows SDK|Matching WDK version|https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/|
|NASM/MASM|For VMX/SVM assembly stubs (VMLAUNCH, VMRESUME, etc.)|https://www.nasm.us/|
|DbgView (Sysinternals)|Kernel DbgPrint capture without full debugger|https://learn.microsoft.com/en-us/sysinternals/downloads/debugview|
|Process Monitor / Process Hacker|Runtime inspection|https://learn.microsoft.com/en-us/sysinternals/|
|Ghidra / IDA Pro|Reverse engineering hvix64.exe, hvax64.exe|https://ghidra-sre.org/ / https://hex-rays.com/|
|Binary Ninja|Alternative RE platform with hypervisor plugins|https://binary.ninja/|
|CPUID tool (Instlatx64 database)|Verify CPU feature flags on target hardware|https://instlatx64.atw.hu/|
|VMware Workstation Pro 17+|Nested virtualization for development sandbox|https://www.vmware.com/products/workstation-pro.html|

---

## SECTION 13: Specification Documents (Direct Downloads)

|Document|Version|Direct Link|
|---|---|---|
|Intel SDM (4-volume combined)|Current|https://cdrdv2.intel.com/v1/dl/getContent/671200|
|AMD APM (Architecture Programmer's Manual)|Current|https://www.amd.com/content/dam/amd/en/documents/processor-tech-docs/programmer-references/40332.pdf|
|Hyper-V TLFS|v6.0b|https://github.com/MicrosoftDocs/Virtualization-Documentation/raw/master/tlfs/Hypervisor%20Top%20Level%20Functional%20Specification%20v6.0b.pdf|
|UEFI Specification|2.10|https://uefi.org/sites/default/files/resources/UEFI_Spec_2_10_Aug29.pdf|
|TCG TPM 2.0 Spec|Current|https://trustedcomputinggroup.org/resource/tpm-library-specification/|
|ACPI Specification|6.5|https://uefi.org/specifications|
|PE/COFF Specification|11|https://learn.microsoft.com/en-us/windows/win32/debug/pe-format|

---

## Critical Roadmap Summary

```
Phase 1: Environment Setup
  ├── VMware nested Hyper-V sandbox
  ├── WDK + VS2022 + WinDbg
  └── Test signing mode / EV cert procurement

Phase 2: Architecture Abstraction Layer
  ├── CPU vendor detection (CPUID leaf 0x40000000)
  ├── VMX (Intel) handler implementation
  ├── SVM (AMD) handler implementation
  └── Unified VM-exit dispatch

Phase 3: Exception Intercept Mechanism
  ├── Exception bitmap configuration
  ├── IDT/handler identification in Hyper-V memory
  ├── .data pointer swap implementation (VMX-root)
  ├── Key value discrimination logic
  └── Pass-through path for legitimate exceptions

Phase 4: HVCI/PatchGuard Compatibility
  ├── Ensure hooks only modify writable .data (not code)
  ├── Verify EPT permissions before modification
  └── Audit guest-observable state changes

Phase 5: Secure Boot / TPM Compliance
  ├── Sign all loaded PE images (WHQL/EV)
  ├── Verify hook is applied post-measurement
  └── Document DRTM threat model

Phase 6: Debugging Integration
  ├── WinDbg synthetic exception integration
  ├── DbgPrint over hypervisor channel
  └── HyperDbg as reference/companion tool
```

The most architecturally similar existing project to what you are describing is **HyperDbg** — I strongly recommend studying its exception interception design before finalizing your own architecture, as it solves several of the same problems you will encounter.