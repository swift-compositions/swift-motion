#include "shims.h"

#include <mach/mach_time.h>
#include <pthread.h>
#include <stdatomic.h>

extern double CACurrentMediaTime(void);

static _Atomic int frozen = 0;
static _Atomic uint64_t elapsed = 0;
static uint64_t origin = 0;
static mach_timebase_info_data_t timebase;
static pthread_mutex_t freezing = PTHREAD_MUTEX_INITIALIZER;
static _Atomic(uintptr_t) prober = 0;

void motion_clock_freeze(void) {
    pthread_mutex_lock(&freezing);
    if (!atomic_load(&frozen)) {
        mach_timebase_info(&timebase);
        origin = mach_absolute_time();
        atomic_store(&elapsed, 0);
        atomic_store(&frozen, 1);
    }
    pthread_mutex_unlock(&freezing);
}

int motion_clock_frozen(void) { return atomic_load(&frozen); }

void motion_clock_advance(uint64_t nanoseconds) {
    if (atomic_load(&frozen)) atomic_fetch_add(&elapsed, nanoseconds);
}

uint64_t motion_clock_elapsed(void) { return atomic_load(&frozen) ? atomic_load(&elapsed) : 0; }

void motion_clock_probe(void) { atomic_store(&prober, (uintptr_t)pthread_self()); }

/// The frozen clock in the machine's ticks: where it was frozen, plus what it was moved on.
static uint64_t ticks(void) {
    return origin + (uint64_t)((__uint128_t)atomic_load(&elapsed) * timebase.denom / timebase.numer);
}

static uint64_t replaced_mach_absolute_time(void) {
    uintptr_t probing = atomic_load(&prober);
    if (probing && probing == (uintptr_t)pthread_self()) {
        atomic_store(&prober, 0);
        return UINT64_MAX;
    }
    return atomic_load(&frozen) ? ticks() : mach_absolute_time();
}

static uint64_t replaced_mach_continuous_time(void) { return atomic_load(&frozen) ? ticks() : mach_continuous_time(); }

static uint64_t replaced_mach_approximate_time(void) { return atomic_load(&frozen) ? ticks() : mach_approximate_time(); }

static double replaced_CACurrentMediaTime(void) {
    return atomic_load(&frozen) ? (double)ticks() * timebase.numer / timebase.denom / 1e9 : CACurrentMediaTime();
}

/// dyld reads this section when the library is loaded at launch and binds every other image's calls to the
/// replacements. Calls made inside this library keep reaching the machine's own functions.
__attribute__((used)) static struct {
    const void *replacement;
    const void *replacee;
} interposers[] __attribute__((section("__DATA,__interpose"))) = {
    {(const void *)replaced_mach_absolute_time, (const void *)mach_absolute_time},
    {(const void *)replaced_mach_continuous_time, (const void *)mach_continuous_time},
    {(const void *)replaced_mach_approximate_time, (const void *)mach_approximate_time},
    {(const void *)replaced_CACurrentMediaTime, (const void *)CACurrentMediaTime},
};
