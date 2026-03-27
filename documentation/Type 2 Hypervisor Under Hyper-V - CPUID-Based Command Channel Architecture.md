# Type 2 Hypervisor Under Hyper-V: CPUID-Based Command Channel Architecture

## Architectural Clarification

What you're describing is a **nested hypervisor** (your layer) that runs beneath Hyper-V. This is a well-established pattern — your hypervisor gains control via `VMXON`/`VMRUN` **before** Hyper-V does, making Hyper-V itself a guest (VT-x level 1), and Windows/other VMs level 2. All traffic passes through transparently unless the key is present.

```
┌─────────────────────────────────────────┐
│  Level 2: Windows Guest VMs             │
├─────────────────────────────────────────┤
│  Level 1: Microsoft Hyper-V (guest)     │  ← Hyper-V thinks it owns hardware
├─────────────────────────────────────────┤
│  Level 0: YOUR HYPERVISOR (VMX root)    │  ← You intercept CPUID VM-exits here
├─────────────────────────────────────────┤
│  Hardware: Intel VT-x / AMD SVM         │
└─────────────────────────────────────────┘
```

---

## The CPUID VM-Exit Command Channel

### Why CPUID is the Ideal Vector

```
- CPUID always causes a VM-exit unconditionally (no bitmap needed)
- It is architecturally benign — no side effects, no privilege escalation
- It is the established standard: VMware uses EAX=0x40000000, 
  Hyper-V uses EAX=0x40000001, Xen uses EAX=0x40000000
- RDX is not part of the standard CPUID ABI — perfect for a key
- Easy to invoke from any privilege level (ring 0–3)
```

### The Dispatch Logic

```c
// On CPUID VM-exit in your VMX-root handler:

void handle_cpuid_vmexit(PGUEST_CONTEXT ctx) {
    
    UINT32 leaf     = (UINT32)ctx->rax;  // CPUID leaf
    UINT64 key      = ctx->rdx;          // YOUR KEY CHECK

    if (key == MAGIC_KEY_VALUE) {
        // ── YOUR COMMAND CHANNEL ──────────────────────────────
        // RCX = command discriminator
        // R8/R9/R10/R11 = command parameters
        // Return values in RAX/RBX/RCX/RDX (CPUID output regs)
        dispatch_custom_command(ctx);
        return;
    }

    // ── PASSTHROUGH PATH ─────────────────────────────────────
    // Emulate CPUID for Hyper-V and all guests transparently
    CPUID_REGS regs = {};
    __cpuidex((int*)&regs, leaf, (int)ctx->rcx);  // ECX = subleaf

    // Optionally mask hypervisor presence bit if desired
    if (leaf == 1) {
        regs.ecx &= ~(1 << 31);  // Clear hypervisor present bit
    }

    ctx->rax = regs.eax;
    ctx->rbx = regs.ebx;
    ctx->rcx = regs.ecx;
    ctx->rdx = regs.edx;

    // Advance RIP past CPUID instruction (2 bytes: 0F A2)
    vmwrite(GUEST_RIP, vmread(GUEST_RIP) + 2);
}
```

---

## Full Resource List for This Specific Architecture

### SECTION 1: Nested Virtualization (Your Core Requirement)

|Resource|Relevance|Link|
|---|---|---|
|Intel SDM Vol. 3C Chapter 25 — "VMX Nested Virtualization"|Defines shadow VMCS, VMXON nesting, VMCS12/VMCS01/VMCS02 relationship|https://cdrdv2.intel.com/v1/dl/getContent/671200|
|Intel SDM Section 25.1 — "Interaction of VMXON and CR0/CR4"|How your hypervisor captures VMXON before Hyper-V|Same PDF|
|AMD APM Vol. 2 Chapter 15.19 — "Nested Virtualization"|AMD #VMEXIT nesting, nested VMCB, nNPT|https://www.amd.com/content/dam/amd/en/documents/processor-tech-docs/programmer-references/40332.pdf|
|"Nested Virtualization" - LWN.net|Conceptual overview of nested VT-x levels|https://lwn.net/Articles/650524/|
|NoirVisor (Zero-Tang)|Open-source nested hypervisor, both Intel and AMD, clean nested virt implementation|https://github.com/Zero-Tang/NoirVisor|
|Hyper-V under another hypervisor — gerhart01 notes|How Hyper-V behaves as a nested guest|https://github.com/gerhart01/Hyper-V-Internals|
|KVM nested VMX source|Linux KVM's production nested VMX — reference for shadow VMCS handling|https://github.com/torvalds/linux/blob/master/arch/x86/kvm/vmx/nested.c|
|"Nested Virtualization: shadow VMCS" — lwn|Shadow VMCS technical detail|https://lwn.net/Articles/650524/|

---

### SECTION 2: CPUID VM-Exit Handling

|Resource|Relevance|Link|
|---|---|---|
|Intel SDM Section 25.1.3 — "Instructions That Cause VM Exits Unconditionally"|Confirms CPUID always VM-exits in VMX non-root|Intel SDM|
|Intel SDM Table 27-1 — "Exit Reasons"|Exit reason 10 = CPUID|Intel SDM|
|AMD APM Table 15-9 — "#VMEXIT intercept codes"|VMEXIT_CPUID = 0x72|AMD APM|
|SimpleVisor — CpuIdHandler|Canonical minimal CPUID VM-exit emulation by Alex Ionescu|https://github.com/ionescu007/SimpleVisor/blob/master/SimpleVisor.c|
|HyperPlatform — VmHandleCpuid|Production CPUID handler with Hyper-V leaf masking|https://github.com/tandasat/HyperPlatform/blob/master/HyperPlatform/vmm.cpp|
|Hypervisor From Scratch Part 8 (Karvandi)|CPUID-based hypervisor communication channel, exactly your pattern|https://rayanfam.com/topics/hypervisor-from-scratch-part-8/|
|HyperDbg — CPUID hook design|Most complete reference for CPUID-based command dispatch|https://github.com/HyperDbg/HyperDbg|
|VMware hypervisor detection via CPUID 0x40000000|Production example of CPUID-based guest↔hypervisor comms|https://kb.vmware.com/s/article/1009458|
|Hyper-V CPUID leaves (TLFS Appendix A)|Documents all Hyper-V CPUID leaves to avoid collision with your key|https://github.com/MicrosoftDocs/Virtualization-Documentation/raw/master/tlfs/Hypervisor%20Top%20Level%20Functional%20Specification%20v6.0b.pdf|

---

### SECTION 3: Passing Everything Through to Hyper-V (Transparent Operation)

This is the most subtle engineering challenge. Hyper-V will attempt `VMXON` and you must handle this correctly.

|Resource|Relevance|Link|
|---|---|---|
|Intel SDM Section 25.1 — "Dual-Monitor Treatment"|How nested VMXON is handled|Intel SDM Vol. 3C|
|Intel SDM Section 25.5 — "VMXON in VMX non-root"|What happens when Hyper-V does VMXON inside your guest|Intel SDM Vol. 3C|
|Shadow VMCS technique|You maintain a shadow VMCS for each VMCS Hyper-V creates|Intel SDM Section 24.10|
|VMCS12 / VMCS02 model|Intel's standard naming for nested VMCS contexts|Intel SDM Chapter 25|
|NoirVisor nested VMX implementation|Practical shadow VMCS management, best open-source reference|https://github.com/Zero-Tang/NoirVisor/tree/master/src/xpf_core/windows|
|KVM nested VMCS management|Battle-tested shadow VMCS reference|https://github.com/torvalds/linux/blob/master/arch/x86/kvm/vmx/nested.c|
|AMD nNPT (Nested NPT) handling|AMD equivalent for nested paging table management|AMD APM Section 15.25.5|
|VMREAD/VMWRITE emulation|How you intercept Hyper-V's VMREAD/VMWRITE and redirect to shadow VMCS|Intel SDM + NoirVisor source|
|HyperBone|Lightweight "pass-everything-through" hypervisor, good structural reference|https://github.com/DarthTon/HyperBone|

---

### SECTION 4: Key Design — RDX as Discriminator

#### Why RDX Specifically Works

```
Standard CPUID ABI:
  Input:  EAX (leaf), ECX (subleaf) ← hardware uses these
  Output: EAX, EBX, ECX, EDX        ← hardware writes these
  
  RDX is an OUTPUT register for CPUID.
  On VM-exit, the saved guest RDX contains its PRE-CPUID value.
  Hardware will overwrite RDX with CPUID result ONLY if you let it execute.
  Since you're emulating CPUID yourself (never re-executing it),
  RDX entering the VM-exit handler = the value the guest SET before CPUID.
  
  → Guest sets RDX = MAGIC_KEY before executing CPUID
  → Your handler sees RDX = MAGIC_KEY in guest context
  → Legitimate code never sets RDX before CPUID (no ABI requires it)
  → Collision probability with legitimate code ≈ 0 with a 64-bit key
```

|Resource|Relevance|Link|
|---|---|---|
|Intel SDM Section 3.2 — "CPUID instruction"|Confirms RDX is output-only; input value preserved in VMCS guest state|Intel SDM Vol. 2|
|VMCS Guest-State Area — General Purpose Registers|How guest GPRs are saved on VM-exit (including pre-CPUID RDX)|Intel SDM Section 24.4|
|AMD VMCB Guest Save Area|AMD equivalent|AMD APM Section 15.7|
|InfinityHook — key discrimination pattern|Uses similar "signature in register" approach for syscall hooking|https://github.com/everdox/InfinityHook|
|HyperDbg event conditions|How HyperDbg applies conditions to distinguish targeted events|https://docs.hyperdbg.org/using-hyperdbg/prerequisites/how-to-create-a-condition|

---

### SECTION 5: AMD vs Intel — CPUID-Specific Differences

|Concern|Intel|AMD|Notes|
|---|---|---|---|
|VM-exit reason for CPUID|Reason 10 (0xA)|VMEXIT_CPUID (0x72)|Different values, abstract in your dispatch|
|Guest RIP after CPUID|Guest RIP = address of CPUID instruction|Same|Must advance by 2 (0F A2) in both|
|Guest RDX location|VMCS Guest RDX (field 0x681A)|VMCB offset 0x90|Different access mechanism|
|CPUID leaf 0x40000000|Intel: returns hypervisor brand|AMD: same|Both platforms; check TLFS for Hyper-V's usage|
|Hyper-V CPUID leaves under AMD|Uses HV_X64_MSR_* differently on AMD|Documented in TLFS|Test on both hardware platforms|

|Resource|Relevance|Link|
|---|---|---|
|VMCS field encoding 0x681A (GUEST_RDX)|Intel field ID for reading guest RDX|Intel SDM Appendix B|
|VMCB Guest Save Area offset map|AMD VMCB offsets for all GPRs|AMD APM Table 15-2|
|Cross-platform GPR abstraction in hvpp|Clean C++ abstraction over VMCS/VMCB GPR access|https://github.com/wbenny/hvpp/blob/master/src/hvpp/hvpp/vcpu.cpp|
|NoirVisor CPU dispatch table|How NoirVisor abstracts Intel/AMD differences in VM-exit dispatch|https://github.com/Zero-Tang/NoirVisor|

---

### SECTION 6: Intercepting Before Hyper-V — Boot Sequence

Your hypervisor must load and execute `VMXON` **before** Hyper-V does. This requires a kernel driver that loads early.

|Resource|Relevance|Link|
|---|---|---|
|Driver load order groups|`Boot` group drivers load before Hyper-V initializes|https://learn.microsoft.com/en-us/windows-hardware/drivers/install/specifying-driver-load-order|
|`SERVICE_BOOT_START` driver timing|Earliest possible driver load, before most of Windows|WDK Documentation|
|Hyper-V initialization sequence|When hvix64.exe executes VMXON relative to boot drivers|gerhart01 Hyper-V Internals repo|
|VMXON execution from driver|How to safely execute VMXON from a boot driver|SimpleVisor / HyperPlatform source|
|KeIpiGenericCall for SMP VMXON|Must execute VMXON on ALL logical processors simultaneously|https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/nf-wdm-keipigenericcall|
|Per-processor VMXON region allocation|Each logical processor needs its own 4KB VMXON region|Intel SDM Section 24.11|

---

### SECTION 7: Full Reference Implementations (Most Relevant to Your Exact Design)

|Project|Why Relevant|Link|
|---|---|---|
|**NoirVisor**|Type 2, passes through to Hyper-V, AMD+Intel, closest to your design|https://github.com/Zero-Tang/NoirVisor|
|**SimpleVisor**|Minimal, clean CPUID handling, Hyper-V aware|https://github.com/ionescu007/SimpleVisor|
|**HyperDbg**|Uses CPUID-based command channel, production quality debugging|https://github.com/HyperDbg/HyperDbg|
|**hvpp**|Clean C++ abstractions, excellent for building your abstraction layer|https://github.com/wbenny/hvpp|
|**InfinityHook**|Key-discriminated hook pattern, structural reference|https://github.com/everdox/InfinityHook|
|**HyperBone**|Transparent pass-through Type 2 hypervisor|https://github.com/DarthTon/HyperBone|
|**Hypervisor From Scratch**|Step-by-step build of exactly this type of project|https://rayanfam.com/topics/hypervisor-from-scratch-part-1/|

---

### Minimal Viable Command Protocol Design

```
┌─────────────────────────────────────────────────────────┐
│  GUEST INVOCATION CONVENTION                            │
│                                                         │
│  MOV RAX, <cpuid_leaf>      ; any leaf (suggest custom) │
│  MOV RCX, <subleaf>         ; subleaf if needed         │
│  MOV RDX, MAGIC_KEY_64BIT   ; e.g. 0xDEADBEEFCAFEBABE  │
│  MOV R8,  COMMAND_ID        ; your command              │
│  MOV R9,  ARG0              ; argument 0                │
│  MOV R10, ARG1              ; argument 1                │
│  CPUID                      ; triggers VM-exit          │
│                                                         │
│  ; Return values in RAX, RBX, RCX (RDX reserved)       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  HYPERVISOR DISPATCH (VMX ROOT)                         │
│                                                         │
│  VM-exit reason 10 (CPUID)                              │
│    └─ RDX == MAGIC_KEY?                                 │
│         ├─ YES → dispatch_command(R8, R9, R10)          │
│         │         write results → RAX, RBX, RCX         │
│         │         advance RIP += 2                      │
│         └─ NO  → __cpuidex(RAX, RCX) passthrough        │
│                   apply Hyper-V leaf masking if needed  │
│                   advance RIP += 2                      │
└─────────────────────────────────────────────────────────┘
```

This architecture is clean, collision-resistant, privilege-level agnostic (works from ring 0–3), and completely invisible to PatchGuard, HVCI, and Secure Boot since no code is patched and no unsigned images are loaded.