# Contributing to Crate Dopamine Rootless

Thank you for your interest in contributing to **Crate Dopamine Rootless**. This project aims to maintain a stable, autonomous Linux virtualization environment for jailbroken iOS devices running Dopamine Rootless and Dopamine RootHide.

---

## Code of Conduct

We encourage respectful, collaborative, and constructive interactions. When submitting issues or pull requests:
- Be clear and specific in problem descriptions.
- Provide hardware details, iOS version, jailbreak environment, and reproducible steps.
- Avoid vague bug reports or duplicate discussions.

---

## Development Workflow

### 1. Environment Setup
- macOS 14+ with Xcode 15 or 16.
- iPhoneOS SDK installed.
- Rust toolchain with target `aarch64-apple-ios`.
- `ldid` and `vtool` command line tools.

### 2. Making Changes
- Fork and clone the repository.
- Create a feature branch: `git checkout -b feature/your-feature-name`.
- Follow clean coding practices:
  - Keep changes focused and minimal.
  - Do not introduce hardcoded rootful paths (`/Applications`, `/Library/MobileSubstrate`, etc.).
  - Always use rootless `/var/jb` conventions where jailbreak resources are accessed.
  - Ensure compatibility with iOS 16.0 – 16.5.1 devices.
  - Avoid reintroducing tethered helper applications or companion pairings.

### 3. Testing
Before submitting a pull request, run the verification test suite:
```bash
python3 tests/verify_suite.py
```
Ensure all verification checks pass with zero errors.

### 4. Submitting Pull Requests
- Provide a clear, descriptive title and detailed summary of changes.
- Reference any related issues or discussions.
- Ensure all commits are signed and follow standard commit messaging guidelines.
