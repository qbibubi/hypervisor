
```
I am making a type 2 hypervisor that will forward non-handled vm commands into microsoft hyper-V I know something about Windows kernel but nothing about anything else. I am thinking what's the best approach to solving such complex tasks. I am using multiple agents and highly specialized coding tools. I want to learn during the development and broaden my understanding.

You need to design a workflow and provide me a way to learn while using AI tools so that I do not blindly copy paste solutions + so that I can actually understand the topics in depth such as Secure Boot, TPM, DRTM, etc.
```

Building a custom hypervisor that interacts with Microsoft Hyper-V is an incredibly ambitious and rewarding project. Since Hyper-V is essentially a Type-1 hypervisor that runs *underneath* the Windows OS (making the host Windows OS the "root partition"), writing a Type-2 hypervisor on top of it means you will likely be leveraging the **Windows Hypervisor Platform (WHPX) API** or writing a kernel-mode driver that intercepts and forwards hypercalls.

To achieve this while genuinely learning—and avoiding the trap of becoming an "AI copy-paste monkey"—you need a structured workflow. Here is a comprehensive blueprint for your multi-agent architecture, your learning strategy, and your technical roadmap.

---

### Part 1: The "Active Learning" AI Workflow

To deeply understand complex topics like Secure Boot, TPM, and DRTM, you must change how you interact with AI. Instead of asking AI to *write* the code, you will ask AI to *architect, explain, and review*.

**1. Set up a "Socratic Mentor" Agent**
Configure one of your AI agents exclusively as a tutor. Do not allow this agent to write complete code for you. Use a system prompt like this:
> *"You are an expert systems programmer and hypervisor architect. Your goal is to teach me. When I ask how to do something, DO NOT give me the code. Instead, explain the underlying hardware/software mechanism, point me to the relevant Intel SDM / AMD APM / Microsoft documentation, and outline the logical steps. Ask me to write the code. Once I provide the code, critique it."*

**2. The "Feynman Technique" Loop**
Before integrating any complex AI-generated snippet into your codebase, use this workflow:
*   **Prompt the Coder Agent:** Ask it to generate an isolated, highly specific function (e.g., "Write a function to read TPM PCR registers using the Windows CNG API").
*   **Read & Annotate:** Read the code. Add line-by-line comments explaining what you *think* it does.
*   **Prompt the Mentor Agent:** Paste your commented code and ask, *"Here is my understanding of how this TPM read works. Where are the gaps in my understanding?"*
*   **Integration:** Only copy the code into your main project once you can successfully explain it to the Mentor Agent.

**3. Build "Micro-Prototypes"**
Do not try to build the full hypervisor at once. Build throwaway micro-projects to master isolated concepts:
*   *Micro-project 1:* A user-mode app that uses WHPX to boot a dummy 16-bit payload.
*   *Micro-project 2:* A kernel driver that reads TPM PCRs and prints them to `DbgView`.
*   *Micro-project 3:* A script to query Secure Boot variables (`SecureBoot` and `SetupMode`) via firmware APIs.

---

### Part 2: Multi-Agent Development Workflow

Since you are using multiple agents and specialized coding tools (like Cursor, AutoGPT, or custom agent swarms), assign them distinct roles to mimic a real engineering team.

*   **Agent 1: The Architect (High-Level Design)**
    *   **Role:** Designs the state machine, defines interfaces between your hypervisor and Hyper-V, and maps out the VM Exit handler logic.
    *   **Task:** Ask it to generate PlantUML or Mermaid diagrams of your Virtual Machine Control Structure (VMCS) / Virtual Machine Control Block (VMCB) states.
*   **Agent 2: The Systems Coder (Implementation)**
    *   **Role:** Translates architectural concepts into C/C++ or Rust.
    *   **Task:** Writes the boilerplate for handling IOCTLs from user space to your kernel driver, or sets up the WHPX partition structures.
*   **Agent 3: The Kernel/Hardware Expert (The Bridge)**
    *   **Role:** Specializes in the Windows Kernel (which you know) and bridges it to Virtualization (which you are learning).
    *   **Task:** Explains how Windows Memory Manager (Paging, MDLs, EPROCESS) interacts with Extended Page Tables (EPT) or Second Level Address Translation (SLAT).
*   **Agent 4: The Security Auditor (Review)**
    *   **Role:** Reviews your code for security and stability.
    *   **Task:** Checks for improper handling of VM exits (which causes host crashes), unhandled MSR reads/writes, or memory leaks in the kernel.

---

### Part 3: Technical Roadmap & Concepts to Master

Here is the step-by-step path to building your project, paired with exactly what you need to learn at each stage.

#### Phase 1: The Hypervisor Foundation
Since Hyper-V owns the CPU's virtualization extensions (Intel VT-x / AMD-V), you cannot execute raw `VMXON` instructions directly without causing a conflict.
*   **What to build:** A basic application using the **Windows Hypervisor Platform (WHPX)**. This allows a Type 2 hypervisor (like QEMU or VirtualBox) to run on Windows by delegating the actual VT-x/AMD-V heavy lifting to the Hyper-V hypervisor.
*   **What to learn:**
    *   *VM Exits:* What happens when a guest OS tries to do something privileged (like reading CPUID or writing to a control register) and control traps back to your hypervisor.
    *   *Hypercalls:* The API used by a guest to communicate directly with Hyper-V.

#### Phase 2: Forwarding Unhandled Commands
You want your hypervisor to handle certain things and pass the rest to Hyper-V.
*   **What to build:** A VM Exit handler switch-statement. For commands you don't want to handle, you will inject them into the WHPX API to let the root partition (Hyper-V) deal with it.
*   **What to learn:**
    *   *MSRs (Model Specific Registers):* How hardware configuration is read/written.
    *   *CPUID Spoofing:* How to intercept the CPUID instruction to trick the guest OS into thinking it's running directly on Hyper-V.

#### Phase 3: Hardware Security (TPM & Secure Boot)
*   **What to build:** Emulate a virtual TPM (vTPM) for your guest VM, or pass through queries to the host's physical TPM.
*   **What to learn (Deep Dive):**
    *   **Secure Boot:** Understand the boot chain. Learn about the Platform Key (PK), Key Exchange Key (KEK), Signature Database (db), and Forbidden Signatures Database (dbx). It relies on UEFI firmware verifying cryptographic signatures before executing bootloaders.
    *   **TPM (Trusted Platform Module):** Think of it as a secure crypto-processor. Learn about **PCRs (Platform Configuration Registers)**. You cannot "write" to a PCR; you can only "extend" it with a cryptographic hash.
    *   **Measured Boot:** How the Windows Bootloader hashes every component it loads and stores those hashes in the TPM PCRs.

#### Phase 4: Advanced Security (DRTM)
*   **What to build:** Research how to intercept the specific CPU instructions related to DRTM (like `GETSEC` on Intel or `SKINIT` on AMD).
*   **What to learn (Deep Dive):**
    *   **SRTM vs DRTM:** Static Root of Trust for Measurement (SRTM) starts at the moment the PC turns on (UEFI). **Dynamic Root of Trust for Measurement (DRTM)** allows the OS to establish a perfectly secure, measured environment *after* the OS is already running, completely untrusted from whatever happened before it. Microsoft uses this heavily for Virtualization Based Security (VBS) and Credential Guard.
    *   **Intel TXT (Trusted Execution Technology):** The hardware feature that powers DRTM.

### Summary Checklist for Your AI Sessions:
1.  **"Explain the Intel SDM Volume 3 chapter on VM Exits in the context of WHPX."**
2.  **"What is the difference between SRTM and DRTM, and how does Windows VBS use DRTM?"**
3.  **"Design the architecture for a WHPX partition that forwards unknown CPUID queries to Hyper-V."**
4.  **"Review this kernel driver code I wrote to handle an MSR read intercept. Are there any race conditions?"**

By maintaining strict control over *which* agent writes code and forcing yourself to explain the code back to your AI mentor, you will safely and effectively bridge your Windows Kernel knowledge into the elite domain of hypervisor engineering and hardware security.