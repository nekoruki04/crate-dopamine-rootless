# Credits & Acknowledgments

This project is a derivative work based on open-source virtualization and jailbreak components.

---

## Upstream Projects

### Crate iOS & Crate Virtualization Engine
- **Antonio Mendez** ([@oneamendez](https://github.com/oneamendez)) — Creator & Lead Developer
- Repositories: [crate-ios](https://github.com/oneamendez/crate-ios) and [crate](https://github.com/oneamendez/crate)
- License: Mozilla Public License Version 2.0 (MPL-2.0)
- Components: Swift iOS user interface, Rust virtualization core (`crate-core`, `crate-virt`, `crate-jit`), VirtIO subsystem, and container tooling.

### Dopamine Jailbreak
- **Lars Fröder** ([@opa334](https://github.com/opa334)) — Lead Developer
- Repository: [Dopamine](https://github.com/opa334/Dopamine)
- Components: Rootless jailbreak architecture, BaseBin bootstrap, trustcache management, and `CS_DEBUGGED` execution environment.

### RootHide Project
- **RootHide Team** ([@roothide](https://github.com/roothide))
- Repository: [Dopamine-roothide](https://github.com/roothide/Dopamine-roothide)
- Components: RootHide packaging conventions and stealth filesystem layout.

---

## Third-Party Libraries

- **SwiftTerm**: Terminal emulator engine by Miguel de Icaza — [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (MIT)
- **libslirp**: Userspace TCP/IP networking stack — [libslirp](https://gitlab.freedesktop.org/slirp/libslirp) (BSD-3-Clause)
- **GLib**: Core application utility library — [glib](https://gitlab.gnome.org/GNOME/glib) (LGPL-2.1-or-later)
- **MoltenVK**: Vulkan implementation over Metal by The Khronos Group — [MoltenVK](https://github.com/KhronosGroup/MoltenVK) (Apache-2.0)
- **virglrenderer**: 3D GPU command translator — [virglrenderer](https://gitlab.freedesktop.org/virgl/virglrenderer) (MIT)
- **libepoxy**: OpenGL function pointer management — [libepoxy](https://github.com/anholt/libepoxy) (MIT)
- **ANGLE**: OpenGL ES to Metal/Vulkan translator by Google — [ANGLE](https://chromium.googlesource.com/angle/angle) (BSD-3-Clause)

For complete license texts of third-party dependencies, see [src/THIRD_PARTY_NOTICES.md](../src/THIRD_PARTY_NOTICES.md).

---

## Port Maintainer

- **nekoruki** ([@nekoruki04](https://github.com/nekoruki04)) — Crate Jailbreak port maintainer. Developed the rootless jailbreak port, direct in-process JIT enablement, iOS 16 retargeting, packaging, and compatibility for Dopamine 2 and Dopamine 3 environments.

---

## Port Modifications

The Crate Jailbreak porting work includes:
- Removing tethered companion helper processes (StikJIT, StikDebug, LocalDevVPN, pairing profiles).
- Direct in-process JIT enablement via `mprotect` and jailbreak task debugging capabilities.
- Backporting Swift and SwiftUI view hierarchies for execution on iOS 16.0 – 16.1.1.
- Retargeting prebuilt Mach-O frameworks and binaries to `minos 16.0` using `vtool`.
- Rootless Debian packaging pipeline installing under `/var/jb/Applications/Crate.app`.
- Static verification and integration test suite (`tests/verify_suite.py`).
