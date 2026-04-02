#pragma once
#include <wdm.h>

inline void Log(const char* message)
{
  KdPrint((message));
}
