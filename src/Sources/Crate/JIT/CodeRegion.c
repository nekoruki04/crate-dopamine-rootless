/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

#include "CodeRegion.h"

#include <errno.h>
#include <libkern/OSCacheControl.h>
#include <mach/mach.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/sysctl.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

#define CS_DEBUGGED 0x10000000
#define CS_GET_TASK_ALLOW 0x00000004
#define PT_ATTACH 10
#define PT_DETACH 11

extern int ptrace(int request, pid_t pid, caddr_t addr, int data);

/* Not in the public SDK, but a stable libSystem wrapper of the csops syscall. */
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

#define CS_OPS_STATUS 0

bool crate_jit_cs_flags(uint32_t *flags) {
    return csops(getpid(), CS_OPS_STATUS, flags, sizeof *flags) == 0;
}

bool crate_jit_traced(void) {
    struct kinfo_proc info;
    size_t size = sizeof info;
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return false;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

bool crate_jailbreak_activate_jit(void) {
    uint32_t flags = 0;
    if (crate_jit_cs_flags(&flags) && (flags & CS_DEBUGGED)) {
        return true;
    }

    /* 1. Attempt in-process ptrace child self-attach cycle */
    pid_t target = getpid();
    pid_t child = fork();
    if (child == 0) {
        int r = ptrace(PT_ATTACH, target, NULL, 0);
        if (r == 0) {
            int status = 0;
            waitpid(target, &status, 0);
            ptrace(PT_DETACH, target, NULL, 0);
        }
        _exit(r == 0 ? 0 : 1);
    } else if (child > 0) {
        int status = 0;
        waitpid(child, &status, 0);
    }

    if (crate_jit_cs_flags(&flags) && (flags & CS_DEBUGGED)) {
        return true;
    }

    /* 2. Fallback: invoke jbctl proc_set_debugged if available under Dopamine 2/3 BaseBin */
    const char *jbctl_paths[] = {
        "/var/jb/basebin/jbctl",
        "/var/jb/usr/bin/jbctl",
        NULL
    };

    for (int i = 0; jbctl_paths[i]; i++) {
        if (access(jbctl_paths[i], X_OK) == 0) {
            char pid_str[32];
            snprintf(pid_str, sizeof pid_str, "%d", target);
            char *const argv[] = {
                (char *)jbctl_paths[i],
                "proc_set_debugged",
                pid_str,
                NULL
            };
            pid_t jbctl_pid;
            if (posix_spawn(&jbctl_pid, jbctl_paths[i], NULL, NULL, argv, environ) == 0) {
                int status = 0;
                waitpid(jbctl_pid, &status, 0);
            }
            break;
        }
    }

    if (crate_jit_cs_flags(&flags) && (flags & CS_DEBUGGED)) {
        return true;
    }

    return (flags & CS_DEBUGGED) != 0;
}

/* Stops for the debugger, which prepares the pages and resumes past the
   instruction. Returns x0 as the debugger left it: the address again, unless
   it put an error code there. */
static uint64_t ask_debugger_to_authorize(void *start, size_t size) {
#if defined(__arm64__)
    register uint64_t x0 __asm__("x0") = (uint64_t)start;
    register uint64_t x1 __asm__("x1") = (uint64_t)size;
    __asm__ volatile("brk #0x69" : "+r"(x0) : "r"(x1) : "memory");
    return x0;
#else
    (void)size;
    return (uint64_t)start;
#endif
}

/* StikJIT's and StikDebug's scripts send each page's address to debugserver in
   9 hex digits, so they authorize only pages below 64 GiB: above, they write
   to the wrong address, and running from the region kills the process. */
#define AUTHORIZABLE_END (64ULL << 30)

uint64_t crate_code_region_first_offer;
uint64_t crate_code_region_largest_gap;

/* The lowest gap of at least `size` bytes in this task's address space between
   `from` and `to`, page-aligned, found by walking its regions; 0 if none. Also
   notes the largest gap seen, for the log. */
static uint64_t find_gap(uint64_t from, uint64_t to, size_t size) {
    vm_address_t address = (vm_address_t)from;
    uint64_t cursor = from;
    crate_code_region_largest_gap = 0;
    for (;;) {
        vm_size_t region_size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object = MACH_PORT_NULL;
        kern_return_t kr = vm_region_64(mach_task_self(), &address, &region_size, VM_REGION_BASIC_INFO_64,
                                        (vm_region_info_t)&info, &count, &object);
        /* No region at or above `address`: the rest up to `to` is free. */
        uint64_t next = kr == KERN_SUCCESS ? (uint64_t)address : to;
        if (next > to) next = to;
        if (next > cursor) {
            uint64_t gap = next - cursor;
            if (gap > crate_code_region_largest_gap) crate_code_region_largest_gap = gap;
            if (gap >= size) return cursor;
        }
        if (kr != KERN_SUCCESS || (uint64_t)address >= to) return 0;
        cursor = (uint64_t)address + region_size;
        address = (vm_address_t)cursor;
    }
}

static void *map_executable(size_t *size_io, size_t min_size, bool below_64_gib) {
    size_t size = *size_io;
    void *first = NULL;
#if DEBUG
    /* Test hook: start where the crashes that found the 64 GiB limit had it. */
    if (getenv("CRATE_TEST_HIGH_REGION")) first = (void *)0x7000000000ULL;
#endif
    void *exec = mmap(first, size, PROT_READ | PROT_EXEC, MAP_PRIVATE | MAP_ANON, -1, 0);
    crate_code_region_first_offer = exec == MAP_FAILED ? 0 : (uint64_t)exec;
    if (!below_64_gib) return exec;
    if (exec != MAP_FAILED) {
        if ((uint64_t)exec + size <= AUTHORIZABLE_END) return exec;
        munmap(exec, size);
    }
    /* Where iOS put it was too high (with extended virtual addressing it often
       is, and a hint lower isn't always taken): map it exactly into the lowest
       free gap above 4 GiB that ends below the limit, found by walking our own
       address space. */
    uint64_t gap = find_gap(4ULL << 30, AUTHORIZABLE_END, size);
    if (gap == 0) {
        /* How much room there is below the limit depends on where iOS put
           everything else this launch: settle for the largest gap, when it's
           big enough to be worth having. The failed walk measured it all. */
        size_t largest = (size_t)(crate_code_region_largest_gap >> 20 << 20);
        if (largest == 0 || largest < min_size) {
            errno = ENOMEM;
            return MAP_FAILED;
        }
        size = largest;
        gap = find_gap(4ULL << 30, AUTHORIZABLE_END, size);
        crate_code_region_largest_gap = largest;
        if (gap == 0) {
            errno = ENOMEM;
            return MAP_FAILED;
        }
    }
    void *placed = mmap((void *)gap, size, PROT_READ | PROT_EXEC, MAP_PRIVATE | MAP_ANON | MAP_FIXED, -1, 0);
    if (placed != MAP_FAILED) *size_io = size;
    return placed;
}


crate_region_status crate_code_region_map(size_t size, size_t min_size, bool below_64_gib,
                                          crate_code_region *out) {
    size_t page = (size_t)getpagesize();
    size = (size + page - 1) / page * page;
    void *exec = map_executable(&size, min_size, below_64_gib);
    if (exec == MAP_FAILED) return CRATE_REGION_MAP_FAILED;
    out->executable = exec;
    out->writable = NULL;
    out->size = size;
    return CRATE_REGION_OK;
}

crate_region_status crate_code_region_finish(crate_code_region *region, bool ask_debugger) {
    void *exec = region->executable;
    size_t size = region->size;

    if (ask_debugger) {
        if ((uint64_t)exec + size > AUTHORIZABLE_END) {
            munmap(exec, size);
            return CRATE_REGION_REFUSED;
        }
        if (ask_debugger_to_authorize(exec, size) != (uint64_t)exec) {
            munmap(exec, size);
            return CRATE_REGION_REFUSED;
        }
    }

    /* vm_remap rather than mach_vm_remap, whose header the iOS SDK refuses; on
       arm64 they take the same 64-bit addresses. FALSE: share the pages. */
    vm_address_t write = 0;
    vm_prot_t cur, max;
    kern_return_t kr = vm_remap(mach_task_self(), &write, size, 0, VM_FLAGS_ANYWHERE,
                                mach_task_self(), (vm_address_t)exec, FALSE,
                                &cur, &max, VM_INHERIT_NONE);
    if (kr != KERN_SUCCESS) {
        munmap(exec, size);
        return CRATE_REGION_REMAP_FAILED;
    }
    if (mprotect((void *)write, size, PROT_READ | PROT_WRITE) != 0) {
        int saved = errno;
        munmap((void *)write, size);
        munmap(exec, size);
        errno = saved;
        return CRATE_REGION_PROTECT_FAILED;
    }
    region->writable = (void *)write;
    return CRATE_REGION_OK;
}

bool crate_code_region_test(const crate_code_region *region) {
#if defined(__arm64__)
    /* mov w0, #42; ret */
    static const uint32_t code[] = {0x52800540, 0xd65f03c0};
    memcpy(region->writable, code, sizeof code);
    sys_icache_invalidate(region->executable, sizeof code);
    int (*answer)(void) = (int (*)(void))region->executable;
    bool ok = answer() == 42;
    memset(region->writable, 0, sizeof code);
    sys_icache_invalidate(region->executable, sizeof code);
    return ok;
#else
    (void)region;
    return false;
#endif
}
