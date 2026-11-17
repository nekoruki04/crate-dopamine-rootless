# Contributing

Contributions to the Crate Dopamine Rootless port are welcome.

---

## Guidelines

- **Focus**: Bug fixes, performance improvements, and compatibility patches for rootless jailbreaks.
- **Rootless Paths**: Never hardcode rootful paths (`/Applications`, `/Library/MobileSubstrate`). Always follow `/var/jb/` conventions where jailbreak resources are accessed.
- **Compatibility**: Ensure code compiles and runs on iOS 16.0 – 16.5.1 on `arm64e` and `arm64` devices.
- **Testing**: Run `python3 tests/verify_suite.py` before opening a pull request.
- **Scope**: Keep changes minimal and focused. Do not reintroduce tethered companion app workflows.

---

## Submitting Pull Requests

1. Fork and create a topic branch: `git checkout -b fix/issue-name`.
2. Commit your changes with clear, concise messages.
3. Run verification tests.
4. Open a pull request describing the change and the testing performed.
