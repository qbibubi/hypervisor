#include "../dbg/debug.h"
#include "../sdk/amd_cpu.h"
#include "ntstatus.h"

#include <intrin.h>

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

/*
 * 1) Enable SVM: Set Bit 12 of MSR_EFER on all CPU cores.
 * 2) Allocate Host Save Area: Allocate a 4KB physical page for every CPU core and put its physical address into MSR_VM_HSAVE_PA.
 * 3) Allocate the VMCB: Allocate a 4KB physical page to act as your L2 Guest.
 * 4) Setup the VMCB: Fill the State Save Area with valid Segment Registers, CR0, CR3, and a valid RIP (Instruction Pointer).
 * 5) Write the Assembly Stub: Write a .asm file that saves your general-purpose registers and calls vmrun.
 * 6) Launch: Execute your assembly stub and watch the magic happen.
 */
NTSTATUS DriverEntry(PDRIVER_OBJECT DriverObject, [[maybe_unused]] PUNICODE_STRING ObjectPath)
{
  Cpu cpu;
  __cpuid(cpu.Info, LARGEST_EXTENDED_FUNCTION);

  const auto maxExtendedLeaf = cpu.Info[Cpu::Register::Ecx];
  if (maxExtendedLeaf < EXTENDED_FEATURES)
  {
    Log("[-] CPU has no extended features");
    return STATUS_UNSUCCESSFUL;
  }

  // SVM Support
  __cpuid(cpu.Info, EXTENDED_FEATURES);
  CPUID_80000001_ECX extendedFeatures = { 0 };
  extendedFeatures.UInt32 = cpu.Info[Cpu::Register::Ecx];

  if (!extendedFeatures.Bits.Svm)
  {
    Log("[-] SVM is not supported");
    return STATUS_UNSUCCESSFUL;
  }

  // I dont get why are we reading MSR here
  VM_CR_MSR vmCr = { 0 };
  vmCr.UInt64 = __readmsr(MSR_VM_CR);

  if (vmCr.Bits.SvmDisable)
  {
    Log("[-] SVM is disabled");
    return STATUS_UNSUCCESSFUL;
  }

  if (maxExtendedLeaf < SVM_FEATURES)
  {
    return STATUS_UNSUCCESSFUL;
  }

  __cpuid(cpu.Info, SVM_FEATURES);
  CPUID_8000000A_EDX svmFeatures = { 0 };
  svmFeatures.UInt32 = cpu.Info[Cpu::Register::Ecx];

  if (!svmFeatures.Bits.Npt)
  {
    Log("[-] Nested Paging is not supported");
  }

  return STATUS_SUCCESS;
}
