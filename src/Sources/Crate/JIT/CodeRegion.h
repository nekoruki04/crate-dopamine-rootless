/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

#ifndef CRATE_CODE_REGION_H
#define CRATE_CODE_REGION_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* The executable memory crate's translator writes code into, claimed once per
   launch. See JIT.swift for when it is claimed and why only once. */

/* This process's code-signing flags (CS_DEBUGGED, CS_GET_TASK_ALLOW, ...).
   False if iOS wouldn't say. */
bool crate_jit_cs_flags(uint32_t *flags);

/* Whether a debugger is tracing this process right now (P_TRACED): the one that
   would answer `brk #0x69`. */
bool crate_jit_traced(void);

typedef struct {
    /* Where code runs. */
    void *executable;
    /* The same pages, mapped again to be written. */
    void *writable;
    size_t size;
} crate_code_region;

typedef enum {
    CRATE_REGION_OK = 0,
    /* mmap of the executable mapping failed: errno says why. */
    CRATE_REGION_MAP_FAILED,
    /* The debugger answered the trap with an error in x0 instead of resuming
       with the address, or the region was too high for it to authorize. */
    CRATE_REGION_REFUSED,
    /* mach_vm_remap of the writable alias failed. */
    CRATE_REGION_REMAP_FAILED,
    /* mprotect of the alias failed: errno says why. */
    CRATE_REGION_PROTECT_FAILED,
} crate_region_status;

/* Claiming is two steps, so the caller can log where the region is before the
   step that can kill the process.

   crate_code_region_map maps `size` bytes (rounded up to whole pages)
   executable. With `below_64_gib` the region ends below 64 GiB, the most a
   debugger's script can authorize (see CodeRegion.c). Where that leaves no gap
   of `size`, it takes the largest gap there is, in whole MiB, if that is at
   least `min_size`, and otherwise fails. out->size is what it mapped.

   crate_code_region_finish then, when `ask_debugger` is set, stops on
   `brk #0x69` with the address in x0 and the length in x1 for the attached
   debugger to authorize the pages (iOS 26 and later), and last maps a writable
   alias of the same pages. In that order: made the other way round the
   authorized pages fault when run. Only call it with `ask_debugger` while
   crate_jit_traced() is true. With no debugger to answer it the trap kills
   the process. */
crate_region_status crate_code_region_map(size_t size, size_t min_size, bool below_64_gib,
                                          crate_code_region *out);
/* Where iOS first put the region in the last crate_code_region_map, before
   any move lower, and the largest free gap below 64 GiB the move found: for
   the log. */
extern uint64_t crate_code_region_first_offer;
extern uint64_t crate_code_region_largest_gap;
crate_region_status crate_code_region_finish(crate_code_region *region, bool ask_debugger);

/* Writes a function that returns 42 into the region, runs it, and says whether
   it returned 42. If the pages weren't really authorized, iOS kills the process
   here instead. */
bool crate_code_region_test(const crate_code_region *region);

/* Autonomous in-process Dopamine RootHide JIT activation.
   Checks csflags, invokes self-attach cycle via ptrace if needed,
   and verifies process JIT capability. */
bool crate_jailbreak_activate_jit(void);

#endif
