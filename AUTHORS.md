# Authors and Contributors

## Upstream Project Authors

### Crate iOS & Crate Virtualization Engine
- **Antonio Mendez** ([@oneamendez](https://github.com/oneamendez)) — Original Creator & Lead Architect
- Contributors to the Crate iOS and Crate Core repositories:
  - https://github.com/oneamendez/crate-ios
  - https://github.com/oneamendez/crate

### Dopamine Jailbreak
- **Lars Fröder** ([@opa334](https://github.com/opa334)) — Lead Developer of Dopamine
- Dopamine project contributors:
  - https://github.com/opa334/Dopamine

### RootHide Project
- **RootHide Team** ([@roothide](https://github.com/roothide))
  - https://github.com/roothide/Dopamine-roothide

---

## Dopamine Rootless Port Contributors

The Dopamine Rootless porting effort was developed independently as a derivative work to adapt Crate iOS for rootless and RootHide jailbreak environments:

- **Rootless Architecture & Packaging**:
  - Implemented rootless payload staging under `/var/jb/Applications/Crate.app/`.
  - Designed Debian packaging automation (`scripts/package_deb.py`) generating standard `ar`-compatible `.deb` archives with `control`, `postinst`, and `prerm` scripts.
  - Configured automatic `uicache` registration and deregistration hooks.

- **Direct Native JIT Integration**:
  - Eliminated tethered helper processes (StikJIT, StikDebug, LocalDevVPN, NetworkExtension pairing profiles).
  - Implemented direct in-process executable memory allocation utilizing iOS 16 `CS_DEBUGGED` jailbreak primitives and `mprotect` state transitions.
  - Verified W^X compliance on Apple Silicon A12X/A13 hardware.

- **iOS 16 Runtime & Deployment Backporting**:
  - Retargeted main executable and 7 bundled dynamic frameworks to minimum OS version `16.0` using `vtool`.
  - Resolved SwiftUI and UIKit modern API dependencies to support iOS 16.0 – 16.1.1 devices without crashing.
  - Implemented static verification test suite (`tests/verify_suite.py`) validating binary slices, entitlements, and package structure.
