# Credits & Acknowledgments

**Crate Dopamine Rootless** is a derivative project built upon foundational open-source virtualization and jailbreak technologies. We express sincere gratitude to the original creators, contributors, and maintainers of these projects.

---

## Upstream Projects

### 1. Crate iOS & Crate Virtualization Engine
- **Authors & Contributors**: Antonio Mendez ([@oneamendez](https://github.com/oneamendez)) and the Crate community.
- **Repository**: [https://github.com/oneamendez/crate-ios](https://github.com/oneamendez/crate-ios) and [https://github.com/oneamendez/crate](https://github.com/oneamendez/crate)
- **License**: Mozilla Public License Version 2.0 (MPL-2.0)
- **Contributions**:
  Original architecture, Rust emulation engine (`crate-core`, `crate-virt`, `crate-jit`), VirtIO subsystem, Swift iOS user interface, and Linux guest container management.

### 2. Dopamine Jailbreak Environment
- **Lead Developer**: Lars Fröder ([@opa334](https://github.com/opa334))
- **Repository**: [https://github.com/opa334/Dopamine](https://github.com/opa334/Dopamine)
- **Contributors**: The Dopamine development team and jailbreak community.
- **License**: Components licensed under GPLv3, BSD, MIT, and Apache 2.0.
- **Contributions**:
  Dopamine rootless architecture, BaseBin bootstrap environment, trustcache injection, and jailbreak security APIs enabling autonomous unassisted JIT on iOS 15.0 – 16.5.1.

### 3. RootHide Project
- **Developer**: RootHide Team ([@roothide](https://github.com/roothide))
- **Repository**: [https://github.com/roothide/Dopamine-roothide](https://github.com/roothide/Dopamine-roothide)
- **Contributions**:
  RootHide jailbreak conventions, stealth rootless filesystem layout, and rootless packaging standards.

---

## Third-Party Libraries & Subsystems

- **SwiftTerm**: Terminal emulator engine by Miguel de Icaza ([https://github.com/migueldeicaza/SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)) — MIT License.
- **libslirp**: Userspace TCP/IP stack ([https://gitlab.freedesktop.org/slirp/libslirp](https://gitlab.freedesktop.org/slirp/libslirp)) — BSD-3-Clause.
- **GLib**: Core application building blocks ([https://gitlab.gnome.org/GNOME/glib](https://gitlab.gnome.org/GNOME/glib)) — LGPL-2.1-or-later.
- **MoltenVK**: Vulkan implementation over Metal by The Khronos Group ([https://github.com/KhronosGroup/MoltenVK](https://github.com/KhronosGroup/MoltenVK)) — Apache-2.0.
- **virglrenderer**: Virtual 3D GPU rendering library ([https://gitlab.freedesktop.org/virgl/virglrenderer](https://gitlab.freedesktop.org/virgl/virglrenderer)) — MIT License.
- **libepoxy**: OpenGL function pointer management library ([https://github.com/anholt/libepoxy](https://github.com/anholt/libepoxy)) — MIT License.
- **ANGLE**: Almost Native Graphics Layer Engine by Google ([https://chromium.googlesource.com/angle/angle](https://chromium.googlesource.com/angle/angle)) — BSD-3-Clause.

---

## Porting & Rootless Integration

- **Port Author**: Porting engineering team for Dopamine Rootless.
- **Scope of Porting Work**:
  - Elimination of companion and pairing dependencies (StikJIT, StikDebug, LocalDevVPN, pairing profiles).
  - Implementation of direct in-process JIT enablement via `mprotect` and jailbreak task debugging capabilities.
  - Backporting Swift and SwiftUI view hierarchies for reliable execution on iOS / iPadOS 16.0 – 16.1.1.
  - Retargeting prebuilt Mach-O frameworks and binaries to `minos 16.0` using `vtool`.
  - Construction of rootless Debian packaging pipeline targeting `/var/jb/Applications/Crate.app`.
  - Automated verification and validation test suite.
