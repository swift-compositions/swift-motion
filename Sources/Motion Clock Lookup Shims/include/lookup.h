#ifndef MOTION_CLOCK_LOOKUP_SHIMS_H
#define MOTION_CLOCK_LOOKUP_SHIMS_H

#include <stdint.h>

/// Finds the `Motion Clock Shims` library in the running process and calls into it. This code is built
/// into the caller's own image, so its reads of the machine's uptime are among those the library replaces.

/// 0 when the shim library is not in the process, 1 when it is but this image's calls are not routed
/// through it, 2 when they are.
int motion_clock_lookup_state(void);

/// `motion_clock_freeze` of the shim library; nothing when it is absent.
void motion_clock_lookup_freeze(void);

/// `motion_clock_advance` of the shim library; nothing when it is absent.
void motion_clock_lookup_advance(uint64_t nanoseconds);

/// `motion_clock_elapsed` of the shim library; 0 when it is absent.
uint64_t motion_clock_lookup_elapsed(void);

#endif
