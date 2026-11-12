#ifndef MOTION_CLOCK_SHIMS_H
#define MOTION_CLOCK_SHIMS_H

#include <stdint.h>

/// The process's virtual clock.
///
/// This library replaces, for every other image of a process it was loaded into at launch, four ways of
/// reading the machine's uptime: `mach_absolute_time`, `mach_continuous_time`, `mach_approximate_time` and
/// `CACurrentMediaTime`. Until `motion_clock_freeze` they pass straight through. From then on all four read
/// one clock that stands still and moves only by `motion_clock_advance`.

/// Takes the process's clock off the machine's, at the instant the machine's clock reads now. Calling it
/// again does nothing.
void motion_clock_freeze(void);

/// 1 once the clock is frozen, 0 before.
int motion_clock_frozen(void);

/// Moves the frozen clock on by so many nanoseconds. Before `motion_clock_freeze` it does nothing.
void motion_clock_advance(uint64_t nanoseconds);

/// The nanoseconds the clock was moved on since it was frozen; 0 before.
uint64_t motion_clock_elapsed(void);

/// Makes the calling thread's next `mach_absolute_time` return `UINT64_MAX` if, and only if, that call is
/// routed through this library. A caller uses it to learn whether its own calls are replaced. One thread
/// probes at a time. The replacements keep no thread-local state, since the first reads of uptime in a
/// process come before its threads have any.
void motion_clock_probe(void);

#endif
