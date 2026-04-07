#pragma once
#include <cstdint>

struct Cpu
{
  enum Register
  {
    Eax,
    Ebx,
    Ecx,
    Edx
  };

  int Info[4];
};

constexpr auto LARGEST_EXTENDED_FUNCTION = 0x80000000;
constexpr auto EXTENDED_FEATURES = 0x80000001;
constexpr auto SVM_FEATURES = 0x8000000A;

constexpr auto MSR_VM_CR = 0xC0010114;
constexpr auto MSR_EFER = 0xC0000080;
constexpr auto MSR_VM_HSAVE_PA = 0xC0010117;

/**
 * @brief CPUID 0x80000001: Extended Feature Identification
 */
typedef union _CPUID_80000001_ECX
{
  uint32_t UInt32;

  struct
  {
    uint32_t LahfSahf : 1;     // [0] LAHF/SAHF instructions
    uint32_t CmpLegacy : 1;    // [1] Core multi-processing legacy mode
    uint32_t Svm : 1;          // [2] Secure Virtual Machine (SVM)
    uint32_t ExtApicSpace : 1; // [3] Extended APIC space
    uint32_t AltMovCr8 : 1;    // [4] LOCK MOV CR0 means MOV CR8
    uint32_t Lzcnt : 1;        // [5] LZCNT instruction
    uint32_t Sse4A : 1;        // [6] SSE4A instruction
    uint32_t MisAlignSse : 1;  // [7] Misaligned SSE mode
    uint32_t PREFETCHW : 1;    // [8] PREFETCHW instruction
    uint32_t OsVw : 1;         // [9] OS visible workaround
    uint32_t Ibs : 1;          // [10] Instruction based sampling
    uint32_t Xop : 1;          // [11] XOP instruction
    uint32_t Skinit : 1;       // [12] SKINIT/STGI instructions
    uint32_t Wdt : 1;          // [13] Watchdog timer
    uint32_t Reserved1 : 18;   // [14:31] Reserved
  } Bits;
} CPUID_80000001_ECX;

/**
 * @brief CPUID 0x8000000A: SVM Revision and Feature Identification
 */
typedef union _CPUID_8000000A_EDX
{
  uint32_t UInt32;

  struct
  {
    uint32_t Npt : 1;               // [0] Nested Paging (NPT)
    uint32_t LbrVirtualization : 1; // [1] LBR Virtualization
    uint32_t SvmLock : 1;           // [2] SVM Lock
    uint32_t NripSave : 1;          // [3] NRIP Save (Next RIP saved on VMEXIT)
    uint32_t TscRateMsr : 1;        // [4] MSR based TSC rate control
    uint32_t VmcbClean : 1;         // [5] VMCB Clean Bits support
    uint32_t FlushByAsid : 1;       // [6] Flush by ASID
    uint32_t DecodeAssists : 1;     // [7] Decode Assists
    uint32_t Reserved : 24;         // [8:31] Reserved
  } Bits;
} CPUID_8000000A_EDX;

/**
 * @brief AMD MSRs (Model Specific Registers)
 */
typedef union _VM_CR_MSR
{
  unsigned __int64 UInt64;

  struct
  {
    unsigned __int64 DebugPortDisable : 1; // [0] Debug port disable
    unsigned __int64 RInit : 1;            // [1] Intercept INIT
    unsigned __int64 A20m : 1;             // [2] Intercept A20M
    unsigned __int64 Lock : 1;             // [3] VM_CR Lock
    unsigned __int64 SvmDisable : 1;       // [4] SVM Disable (If 1, BIOS disabled SVM)
    unsigned __int64 Reserved : 59;        // [5:63]
  } Bits;
} VM_CR_MSR;
