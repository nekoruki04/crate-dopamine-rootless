/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/*
 * crate's C API. Draft v0: nothing here is stable before 1.0, and until then
 * the minor version changes with every incompatible change.
 *
 * Describe a machine with a crate_config, create a crate_machine from it, and
 * start it. The machine runs on its own threads. What it produces (console
 * output, frames, state changes, log messages) arrives through callbacks on
 * those threads, so an app hops to its own thread before touching its UI. What
 * the app sends in (console input, keys, the pointer) goes through calls that
 * any thread may make.
 *
 * Functions that can fail return crate_status, CRATE_OK (0) on success, and
 * crate_last_error() describes the failure.
 *
 * Structs passed in begin with their own size, so later versions can add
 * fields without breaking apps built against earlier ones. Everything else is
 * set through functions for the same reason.
 */
#ifndef CRATE_H
#define CRATE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CRATE_API_VERSION_MAJOR 0
#define CRATE_API_VERSION_MINOR 1

/* The version of the library actually linked: (major << 16) | minor. */
uint32_t crate_api_version(void);

typedef enum crate_status {
    CRATE_OK = 0,
    CRATE_ERR_INVALID_ARGUMENT,
    CRATE_ERR_UNSUPPORTED, /* not on this host, or not in this build */
    CRATE_ERR_NO_MEMORY,
    CRATE_ERR_IO,          /* a file could not be opened, read or written */
    CRATE_ERR_JIT,         /* no executable memory could be had */
    CRATE_ERR_GUEST,       /* the kernel or another guest file is unusable */
    CRATE_ERR_STATE,       /* not allowed in the machine's current state */
    CRATE_ERR_TIMEOUT,
} crate_status;

/* What the calling thread's last failed call went wrong on. Valid until that
   thread's next call into crate. */
const char *crate_last_error(void);

typedef struct crate_config crate_config;
typedef struct crate_machine crate_machine;

/* ---------------------------------------------------------------- logging */

typedef enum crate_log_level {
    CRATE_LOG_ERROR,
    CRATE_LOG_WARN,
    CRATE_LOG_INFO,
    CRATE_LOG_DEBUG,
} crate_log_level;

typedef void (*crate_log_fn)(void *context, crate_log_level level, const char *message);

/* For the whole process. Messages less important than `max` are not made at
   all. A NULL fn restores the default, which writes to stderr. Messages come
   from whichever thread made them. */
void crate_set_log_callback(crate_log_fn fn, void *context, crate_log_level max);

/* ---------------------------------------------------------------- the machine's description */

/* `machine` names a machine type. "virt" is the only one so far: a generic
   arm64 board for Linux, with its hardware described by a device tree. A new
   config has one CPU, 1 GiB of memory and an empty command line. Returns NULL
   for an unknown type. */
crate_config *crate_config_new(const char *machine);
void crate_config_free(crate_config *config);

/* hvf needs the process to be signed with the hypervisor entitlement. Without
   it, CRATE_CPU_AUTO logs that hvf was refused and uses jit, and CRATE_CPU_HVF
   fails with CRATE_ERR_UNSUPPORTED. */
typedef enum crate_cpu_backend {
    CRATE_CPU_AUTO, /* hvf when this process may use it, otherwise jit */
    CRATE_CPU_JIT,  /* the translator */
    CRATE_CPU_HVF,  /* Apple's Hypervisor framework: macOS only */
} crate_cpu_backend;

crate_status crate_config_set_cpu_backend(crate_config *config, crate_cpu_backend backend);

/* 1 to 32 on virt. */
crate_status crate_config_set_cpus(crate_config *config, uint32_t count);

/* A multiple of 2 MiB, from 64 MiB up to 63 GiB on virt. */
crate_status crate_config_set_memory(crate_config *config, uint64_t bytes);

/* Executable memory for the translator.
 *
 * On a Mac or Linux crate gets its own by default: a region mapped twice (once
 * writable, once executable). On iOS it cannot, since only a debugger attached
 * to the app can make memory executable there: the app has the region
 * prepared and passes it here, and without one creating the machine fails
 * with CRATE_ERR_JIT. iOS accepts it one way round: mapped executable first
 * and prepared, then the same pages remapped (copy = false) as the writable
 * alias; a writable mapping given an executable alias faults on execution.
 * Every page is made resident when it is prepared, so it counts against the
 * app's memory limit from the start.
 *
 * `executable` is where code runs, `writable` an alias of the same pages where
 * it is written (the same address where the host allows both at once). It
 * must stay valid until the machine is freed.
 *
 * Either way the region is split between the CPUs, an equal slice each; a CPU
 * uses at most 128 MiB, the reach of a branch. */
crate_status crate_config_set_jit_region(crate_config *config, void *executable, void *writable,
                                         size_t size);

/* How much executable memory crate asks for when it gets its own (never on
   iOS), for the whole machine: by default 128 MiB per CPU. */
crate_status crate_config_set_jit_size(crate_config *config, size_t bytes);

/* Linux's boot protocol: an arm64 Image (raw or gzip-compressed), an optional
   initial ramdisk, and the kernel command line. The machine writes the device
   tree itself. */
crate_status crate_config_set_kernel(crate_config *config, const char *path);
crate_status crate_config_set_initrd(crate_config *config, const char *path);
crate_status crate_config_set_cmdline(crate_config *config, const char *cmdline);

/* ---------------------------------------------------------------- disks */

#define CRATE_DISK_READ_ONLY (1u << 0)

/* When the guest flushes a disk, crate calls fsync on its file by default. On
   Apple systems that reaches only the drive's own cache: FULL_FLUSH uses
   F_FULLFSYNC instead, which is slower and survives power loss; elsewhere it
   changes nothing. NO_FLUSH ignores the guest's flushes, fastest but a host
   crash can lose recent writes, for scratch disks. The two together are
   CRATE_ERR_INVALID_ARGUMENT. */
#define CRATE_DISK_FULL_FLUSH (1u << 1)
#define CRATE_DISK_NO_FLUSH (1u << 2)

/* The guest may discard blocks it no longer uses, and the file gives that space
   back to the host (a sparse file's hole). Not implemented yet:
   CRATE_ERR_UNSUPPORTED. */
#define CRATE_DISK_DISCARD (1u << 3)

/* A virtio block device on a raw image file. Disks appear to the guest in the
   order they are added (vda, vdb, ...). */
crate_status crate_config_add_disk(crate_config *config, const char *path, uint32_t flags);

/* ---------------------------------------------------------------- network */

/* A virtio network device on user-mode networking: the guest's traffic leaves
   through the host's own sockets, with no privileges needed. The guest is
   10.0.2.15 and the host 10.0.2.2. `index` receives the device's number. */
crate_status crate_config_add_network(crate_config *config, uint32_t *index);

/* The device's MAC address. Without one, each network device gets a locally
   administered address of its own, the same on every run, so the guest's
   network setup keeps matching it. */
crate_status crate_config_set_network_mac(crate_config *config, uint32_t network,
                                          const uint8_t mac[6]);

/* IPv6 beside IPv4 on that network. Off by default. */
crate_status crate_config_set_network_ipv6(crate_config *config, uint32_t network, bool enabled);

typedef enum crate_protocol {
    CRATE_TCP,
    CRATE_UDP,
} crate_protocol;

/* Connections to host_address:host_port on the host go to guest_port in the
   guest. host_address is an IPv4 address; NULL or "" means every interface.
   A port that cannot be bound when the machine starts is logged and skipped,
   not fatal. */
crate_status crate_config_add_port_forward(crate_config *config, uint32_t network,
                                           crate_protocol protocol, const char *host_address,
                                           uint16_t host_port, uint16_t guest_port);

/* ---------------------------------------------------------------- consoles */

typedef enum crate_console_kind {
    CRATE_CONSOLE_SERIAL, /* the PL011 UART: Linux's ttyAMA0, live from the kernel's first line */
    CRATE_CONSOLE_VIRTIO, /* a virtio console: hvc0, hvc1, ...; far faster for bulk output */
} crate_console_kind;

typedef struct crate_console_callbacks {
    size_t size; /* sizeof(crate_console_callbacks) */
    void *context;
    /* Bytes the guest wrote, valid only during the call. */
    void (*output)(void *context, uint32_t console, const uint8_t *bytes, size_t length);
    /* The console can take bytes again, after a crate_console_write took fewer
       than it was offered: once per such refusal, on the thread of the guest
       CPU that made room (for the serial console, by reading its last byte;
       for a virtio console, by posting buffers). It may call
       crate_console_write. May be NULL; the app then retries on its own. */
    void (*input_ready)(void *context, uint32_t console);
} crate_console_callbacks;

/* A machine has at most one serial console; a second is
   CRATE_ERR_INVALID_ARGUMENT. Virtio consoles become hvc0, hvc1, ... in the
   order they are added. `index` receives the console's number, counted over
   both kinds in the order they are added, which crate_console_write and the
   callbacks use. */
crate_status crate_config_add_console(crate_config *config, crate_console_kind kind,
                                      const crate_console_callbacks *callbacks, uint32_t *index);

/* Bytes for the guest to read. Never blocks: returns how many were taken, which
   for the serial console is only a few at a time and possibly none while the
   guest is not reading. The app offers the rest when input_ready says so. */
size_t crate_console_write(crate_machine *machine, uint32_t console, const uint8_t *bytes,
                           size_t length);

/* ---------------------------------------------------------------- display */

typedef enum crate_gpu {
    CRATE_GPU_2D,    /* virtio-gpu, the guest draws in software */
    CRATE_GPU_VIRGL, /* virtio-gpu with OpenGL ES through virglrenderer; 2D, with a
                        log message, when that cannot start */
} crate_gpu;

/* virgl loads virglrenderer and EGL when the machine is created rather than
   linking them, so an app without them still runs, in 2D. They are found by
   name: the frameworks an iOS app embeds (virglrenderer.1.framework,
   EGL.framework), or on a Mac libvirglrenderer.1.dylib and ANGLE's
   EGL.framework through DYLD_LIBRARY_PATH and DYLD_FRAMEWORK_PATH. The
   environment variables CRATE_VIRGLRENDERER and CRATE_EGL name others.
   ANGLE runs on Vulkan (CRATE_ANGLE_PLATFORM=metal or default to change it),
   which gives the guest OpenGL ES 3.1. */

typedef struct crate_frame {
    uint32_t width;
    uint32_t height;
    uint32_t stride;       /* bytes per row */
    const uint8_t *pixels; /* 4 bytes a pixel: red, green, blue, unused; the
                              guest's cursor drawn in */
    /* The part that changed since the previous frame. */
    uint32_t dirty_x;
    uint32_t dirty_y;
    uint32_t dirty_width;
    uint32_t dirty_height;
} crate_frame;

typedef struct crate_display_callbacks {
    size_t size; /* sizeof(crate_display_callbacks) */
    void *context;
    /* A new frame, its pixels valid only during the call, on the GPU's
       thread. */
    void (*frame)(void *context, uint32_t display, const crate_frame *frame);
} crate_display_callbacks;

/* A virtio-gpu with one screen. `index` receives the display's number. The
   callbacks may be NULL for a display only a VNC server shows. */
crate_status crate_config_add_display(crate_config *config, crate_gpu gpu,
                                      const crate_display_callbacks *callbacks, uint32_t *index);

typedef struct crate_display_mode {
    uint32_t width;
    uint32_t height;
} crate_display_mode;

/* The sizes the guest is offered, in its EDID, the first one preferred: what
   the guest's console starts at, and what a desktop starts at unless it picks
   another. 1 to 45 of them, 16 to 4095 pixels a side; by default 1024x768,
   640x480, 800x600 and 1280x960. The guest changes between them itself (on
   Linux through its KMS driver, xrandr or wlr-randr). */
crate_status crate_config_set_display_modes(crate_config *config, uint32_t display,
                                            const crate_display_mode *modes, size_t count);

/* An optional VNC server for the display (RFB 3.8, no authentication, Raw
   encoding, DesktopSize), with the machine's input devices behind it:
   "unix:PATH" for a Unix socket only this user may connect to, or
   "tcp:HOST:PORT" (keep that on 127.0.0.1). It makes frames only while a
   client is connected. May be given more than once. A server that cannot
   listen fails crate_machine_create with CRATE_ERR_IO. */
crate_status crate_config_add_vnc(crate_config *config, uint32_t display, const char *address);

/* Frames cost a copy out of the GPU, so they are made only while the display
   is active: an app turns it off while nothing shows it. Off at start; turning
   it on makes a whole frame soon after. Handing the GPU's own surface to the
   app, with no copy, is planned. */
void crate_display_set_active(crate_machine *machine, uint32_t display, bool active);

/* Offers the guest new modes while it runs, the first preferred, as a display
   unplugged and plugged back in with them: a compositor reads modes when a
   display connects, so this is what makes a desktop take the new preferred
   mode (a phone rotating or folding) with nothing installed in the guest. The
   display reads as disconnected until the guest turns it off, or for a second
   at most, then connects again. Modes given while it is out are the ones it
   comes back with; the same modes as now change nothing. */
crate_status crate_display_set_modes(crate_machine *machine, uint32_t display,
                                     const crate_display_mode *modes, size_t count);

/* ---------------------------------------------------------------- input */

#define CRATE_INPUT_KEYBOARD (1u << 0)
#define CRATE_INPUT_TABLET (1u << 1) /* an absolute pointer: positions, not movements */

/* virtio-input devices: a keyboard and a tablet with three buttons and a
   wheel each way, each its own device. A machine with a display wants both:
   without input devices the guest ignores the app. */
crate_status crate_config_add_input(crate_config *config, uint32_t devices);

/* Keys are Linux input event codes (KEY_A is 30), the guest's own names for them. */
void crate_input_key(crate_machine *machine, uint16_t code, bool down);

/* x and y from 0 to 32767 across the display; buttons: bit 0 left, bit 1
   right, bit 2 middle. */
void crate_input_pointer(crate_machine *machine, uint32_t x, uint32_t y, uint32_t buttons);
/* Wheel notches: positive dy scrolls down, positive dx right. */
void crate_input_scroll(crate_machine *machine, int32_t dx, int32_t dy);

/* ---------------------------------------------------------------- running it */

typedef enum crate_state {
    CRATE_STATE_CREATED,
    CRATE_STATE_RUNNING,
    CRATE_STATE_PAUSED,
    CRATE_STATE_STOPPED,
} crate_state;

typedef enum crate_stop_reason {
    CRATE_STOP_NONE,      /* not stopped */
    CRATE_STOP_POWER_OFF, /* the guest turned itself off */
    CRATE_STOP_RESET,     /* the guest asked to restart; starting again is the app's choice */
    CRATE_STOP_KILLED,    /* crate_machine_kill */
    CRATE_STOP_ERROR,     /* the engine could not go on; crate_last_error on the callback's thread says why */
} crate_stop_reason;

typedef void (*crate_state_fn)(void *context, crate_state state, crate_stop_reason reason);

crate_status crate_config_set_state_callback(crate_config *config, crate_state_fn fn, void *context);

/* Builds the machine from the description: guest memory, executable memory,
   devices, the kernel loaded. The config may be freed afterwards.

   One machine per process: Apple's Hypervisor framework allows one virtual
   machine per process, and jit keeps the same rule for now. Creating a second
   while one exists is CRATE_ERR_STATE. */
crate_status crate_machine_create(const crate_config *config, crate_machine **machine);

/* Returns at once; the guest runs on the engine's threads. */
crate_status crate_machine_start(crate_machine *machine);

/* Not in this build yet: CRATE_ERR_UNSUPPORTED. */
crate_status crate_machine_pause(crate_machine *machine);
crate_status crate_machine_resume(crate_machine *machine);

/* Asks the guest to shut down, as pressing a power button does. virt has no
   power button yet: CRATE_ERR_UNSUPPORTED. */
crate_status crate_machine_request_shutdown(crate_machine *machine);

/* Stops the machine at once, as pulling the plug does. */
crate_status crate_machine_kill(crate_machine *machine);

/* Waits for the machine to stop: up to timeout_ms, or for good if negative.
   Returns once the state callback reporting the stop has returned;
   CRATE_ERR_STATE if the machine was never started. */
crate_status crate_machine_wait(crate_machine *machine, int64_t timeout_ms);

crate_state crate_machine_state(const crate_machine *machine);

/* Kills the machine if it is running, then frees it. Called from one of the
   machine's own callbacks, it does not wait for the machine's thread. */
void crate_machine_free(crate_machine *machine);

/*
 * Not in v0, planned: devices written by the app (an MMIO or PCI device
 * interface; the Rust API has it first), shared folders, snapshots,
 * statistics.
 */

#ifdef __cplusplus
}
#endif

#endif /* CRATE_H */
