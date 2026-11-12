#include "lookup.h"

#include <dlfcn.h>
#include <mach/mach_time.h>

static void *find(const char *name) { return dlsym(RTLD_DEFAULT, name); }

int motion_clock_lookup_state(void) {
    void (*probe)(void) = find("motion_clock_probe");
    if (!probe || !find("motion_clock_freeze") || !find("motion_clock_advance") || !find("motion_clock_elapsed")) return 0;
    probe();
    return mach_absolute_time() == UINT64_MAX ? 2 : 1;
}

void motion_clock_lookup_freeze(void) {
    void (*freeze)(void) = find("motion_clock_freeze");
    if (freeze) freeze();
}

void motion_clock_lookup_advance(uint64_t nanoseconds) {
    void (*advance)(uint64_t) = find("motion_clock_advance");
    if (advance) advance(nanoseconds);
}

uint64_t motion_clock_lookup_elapsed(void) {
    uint64_t (*elapsed)(void) = find("motion_clock_elapsed");
    return elapsed ? elapsed() : 0;
}
