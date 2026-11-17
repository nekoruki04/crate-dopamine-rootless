#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/sysctl.h>
#include <sys/wait.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>

#define CS_OPS_STATUS 0
#define CS_DEBUGGED 0x10000000
#define CS_GET_TASK_ALLOW 0x00000004
#define PT_ATTACH 10
#define PT_DETACH 11

extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
extern int ptrace(int request, pid_t pid, caddr_t addr, int data);

bool crate_jit_cs_flags(uint32_t *flags) {
    return csops(getpid(), CS_OPS_STATUS, flags, sizeof *flags) == 0;
}

bool crate_jailbreak_activate_jit(void) {
    uint32_t flags = 0;
    if (crate_jit_cs_flags(&flags) && (flags & CS_DEBUGGED)) {
        return true;
    }

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

    return false;
}

int main(int argc, char **argv) {
    printf("JIT test helper compiled successfully.\n");
    return 0;
}
