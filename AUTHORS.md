# Authors and Contributors

## Upstream Authors

### Crate iOS & Crate Virtualization Engine
- **Antonio Mendez** ([@oneamendez](https://github.com/oneamendez)) — Creator & Lead Architect
- Upstream contributors to [crate-ios](https://github.com/oneamendez/crate-ios) and [crate](https://github.com/oneamendez/crate).

### Dopamine Jailbreak
- **Lars Fröder** ([@opa334](https://github.com/opa334)) — Lead Developer
- Contributors to [Dopamine](https://github.com/opa334/Dopamine).

### RootHide Project
- **RootHide Team** ([@roothide](https://github.com/roothide))
- Contributors to [Dopamine-roothide](https://github.com/roothide/Dopamine-roothide).

---

## Port Maintainers

The Dopamine Rootless port was developed as a derivative work to adapt Crate iOS for rootless jailbreak environments:

- **Rootless Packaging**: Implemented payload staging under `/var/jb/Applications/Crate.app/`, package generation via `scripts/package_deb.py`, and `uicache` hooks.
- **Direct JIT**: Removed companion app requirements and implemented in-process executable memory transitions under Dopamine's `CS_DEBUGGED` execution environment.
- **iOS 16 Retargeting**: Retargeted main binary and frameworks to `minos 16.0` and backported SwiftUI tab views.
- **Verification**: Created automated validation suite (`tests/verify_suite.py`).
