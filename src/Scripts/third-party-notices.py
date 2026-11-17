#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Writes THIRD_PARTY_NOTICES.md: every piece of other people's code the app
# carries, with its license's text as its own source states it. Run it after
# changing a pinned version, from a Mac that has built the frameworks (the
# license files come from those builds' sources) and has crate's checkout at
# the version fetch-crate.sh pins:
#
#     ./Scripts/third-party-notices.py
#
# ANGLE_SRC and CRATE_DIR as for build-angle.sh and build-crate.sh. Rust
# libraries come from `cargo metadata`, with the features each is built with.

import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEPS = REPO / ".deps"
ANGLE = Path(os.environ.get("ANGLE_SRC", DEPS / "angle"))
CRATE = Path(os.environ.get("CRATE_DIR", Path.home() / "Repos/crate"))
MOLTENVK = DEPS / "src/MoltenVK-1.4.2"
GLIB = DEPS / "slirp-build/glib-2.90.1"
CARGO = str(Path.home() / ".cargo/bin/cargo")


def pinned(script, name):
    text = (REPO / "Scripts" / script).read_text()
    found = re.search(r'^%s=(?:"([^"]*)"|([^\s#]+))' % name, text, re.M)
    return found.group(1) if found.group(1) is not None else found.group(2)


def revision(name):
    return (MOLTENVK / "ExternalRevisions" / (name + "_repo_revision")).read_text().strip()[:12]


def both(name):
    # In MoltenVK at its revision, and in ANGLE at the one ANGLE pins.
    return "%s in MoltenVK, as ANGLE 9addc29 pins it in GLESv2" % revision(name)


def slirp_licenses():
    # libslirp is built from its tarball; its license files are read from it.
    out = DEPS / "src/libslirp-license"
    tarball = DEPS / "src/libslirp-v4.9.7.tar.gz"
    out.mkdir(exist_ok=True)
    for name in ("LICENSE", "COPYRIGHT"):
        subprocess.run(["tar", "-xzf", str(tarball), "-C", str(out), "--strip-components", "1",
                        "libslirp-v4.9.7/" + name], check=True)
    return [out / "LICENSE", out / "COPYRIGHT"]


# (name, version, license, source, what it's part of, license files)
COMPONENTS = [
    ("crate", pinned("fetch-crate.sh", "VERSION"), "MPL-2.0",
     "https://github.com/oneamendez/crate/tree/" + pinned("fetch-crate.sh", "VERSION"),
     "the VM engine, linked into the app", []),
    ("StikJIT", pinned("fetch-stikjit.sh", "VERSION"), "MPL-2.0",
     "https://github.com/StikDebug/StikJIT/tree/" + pinned("fetch-stikjit.sh", "VERSION"),
     "the JIT helper's framework, from its release; it carries its own build of idevice", []),
    ("idevice", "0.1.68", "MIT", "https://github.com/jkcoxson/idevice",
     "linked into the app, built with one patch", [DEPS / "idevice/LICENSE.txt"]),
    ("SwiftTerm", "1.18.0", "MIT", "https://github.com/migueldeicaza/SwiftTerm",
     "linked into the app", [REPO / "build/SourcePackages/checkouts/SwiftTerm/LICENSE"]),
    ("libslirp", "4.9.7", "BSD-3-Clause", "https://gitlab.freedesktop.org/slirp/libslirp",
     "Slirp.framework", None),
    ("GLib", "2.90.1", "LGPL-2.1-or-later", "https://download.gnome.org/sources/glib/2.90/glib-2.90.1.tar.xz",
     "GLib.framework, unmodified and dynamically linked, so it can be replaced", [GLIB / "COPYING"]),
    ("libffi", "3.5.2", "MIT", "https://github.com/libffi/libffi",
     "linked into GLib.framework", [GLIB / "subprojects/libffi-3.5.2/LICENSE"]),
    ("PCRE2", "10.46", "BSD-3-Clause WITH PCRE2-exception", "https://github.com/PCRE2Project/pcre2",
     "linked into GLib.framework", [GLIB / "subprojects/pcre2-10.46/LICENCE.md"]),
    ("proxy-libintl", "0.5", "LGPL-2.0-or-later", "https://github.com/frida/proxy-libintl",
     "linked into GLib.framework", [GLIB / "subprojects/proxy-libintl-0.5/COPYING"]),
    ("MoltenVK", "1.4.2", "Apache-2.0", "https://github.com/KhronosGroup/MoltenVK",
     "MoltenVK.framework", [MOLTENVK / "LICENSE"]),
    ("SPIRV-Cross", revision("SPIRV-Cross"), "Apache-2.0", "https://github.com/KhronosGroup/SPIRV-Cross",
     "linked into MoltenVK.framework", [MOLTENVK / "External/SPIRV-Cross/LICENSE"]),
    ("SPIRV-Tools", both("SPIRV-Tools"), "Apache-2.0", "https://github.com/KhronosGroup/SPIRV-Tools",
     "linked into MoltenVK.framework and the GLESv2 framework", [MOLTENVK / "External/SPIRV-Tools/LICENSE"]),
    ("SPIRV-Headers", both("SPIRV-Headers"), "MIT (Khronos)", "https://github.com/KhronosGroup/SPIRV-Headers",
     "compiled into MoltenVK.framework and the GLESv2 framework",
     [MOLTENVK / "External/SPIRV-Tools/external/spirv-headers/LICENSE"]),
    ("cereal", revision("cereal"), "BSD-3-Clause", "https://github.com/USCiLab/cereal",
     "compiled into MoltenVK.framework", [MOLTENVK / "External/cereal/LICENSE"]),
    ("Vulkan-Headers", both("Vulkan-Headers"), "Apache-2.0 OR MIT", "https://github.com/KhronosGroup/Vulkan-Headers",
     "compiled into MoltenVK.framework and the GLESv2 framework",
     [MOLTENVK / "External/Vulkan-Headers/LICENSE.md", ANGLE / "third_party/vulkan-headers/src/LICENSES/Apache-2.0.txt"]),
    ("ANGLE", "9addc29", "BSD-3-Clause", "https://chromium.googlesource.com/angle/angle",
     "the EGL and GLESv2 frameworks, built with one patch", [ANGLE / "LICENSE"]),
    ("Abseil", "as ANGLE 9addc29 pins it", "Apache-2.0", "https://github.com/abseil/abseil-cpp",
     "linked into the GLESv2 framework", [ANGLE / "third_party/abseil-cpp/LICENSE"]),
    ("astc-encoder", "as ANGLE 9addc29 pins it", "Apache-2.0", "https://github.com/ARM-software/astc-encoder",
     "linked into the GLESv2 framework", [ANGLE / "third_party/astc-encoder/src/LICENSE.txt"]),
    ("LLVM libc", "as ANGLE 9addc29 pins it", "Apache-2.0 WITH LLVM-exception", "https://github.com/llvm/llvm-project",
     "linked into the GLESv2 framework", [ANGLE / "third_party/llvm-libc/src/LICENSE.TXT"]),
    ("Vulkan Memory Allocator", "as ANGLE 9addc29 pins it", "MIT",
     "https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator",
     "linked into the GLESv2 framework", [ANGLE / "third_party/vulkan_memory_allocator/LICENSE.txt"]),
    ("zlib", "as ANGLE 9addc29 pins it", "Zlib", "https://chromium.googlesource.com/chromium/src/third_party/zlib",
     "linked into the GLESv2 framework", [ANGLE / "third_party/zlib/LICENSE"]),
    ("libepoxy", "1.5.10", "MIT", "https://github.com/anholt/libepoxy",
     "epoxy.framework, built with one patch", [DEPS / "src/libepoxy-1.5.10/COPYING"]),
    ("virglrenderer", "1.3.0", "MIT", "https://gitlab.freedesktop.org/virgl/virglrenderer",
     "virglrenderer.1.framework, built with three patches", [DEPS / "src/virglrenderer-1.3.0/COPYING"]),
]

RUST = [
    # (who links them, checkout, package, features as built)
    ("crate", CRATE, "crate-ffi", None),
    ("idevice", DEPS / "idevice", "idevice-ffi", pinned("build-idevice.sh", "FEATURES")),
]

LICENSE_NAME = re.compile(r"^(LICEN[CS]E|COPYING|UNLICENSE|NOTICE)", re.I)


def rust_packages(root, package, features):
    cmd = [CARGO, "metadata", "--format-version", "1", "--filter-platform", "aarch64-apple-ios"]
    if features is not None:
        cmd += ["--no-default-features", "--features", features]
    meta = json.loads(subprocess.run(cmd, cwd=root, capture_output=True, text=True, check=True).stdout)
    members = set(meta["workspace_members"])
    nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
    packages = {p["id"]: p for p in meta["packages"]}
    start = next(i for i in members if packages[i]["name"] == package)
    seen, todo = set(), [start]
    while todo:
        i = todo.pop()
        if i in seen:
            continue
        seen.add(i)
        for dep in nodes[i]["deps"]:
            if any(k["kind"] in (None, "normal") for k in dep["dep_kinds"]):
                todo.append(dep["pkg"])
    return [packages[i] for i in seen if i not in members]


def rust_license_files(package):
    """The package's license files: for a choice that includes MIT, its MIT
    text; otherwise all of them. NOTICE files always."""
    folder = Path(package["manifest_path"]).parent
    files = sorted(f for f in folder.iterdir() if f.is_file() and LICENSE_NAME.match(f.name))
    if package.get("license_file"):
        files.append(folder / package["license_file"])
    notices = [f for f in files if f.name.upper().startswith("NOTICE")]
    mit = [f for f in files if "MIT" in f.name.upper()]
    expression = package["license"] or ""
    if mit and re.search(r"\bMIT\b", expression) and (" OR " in expression or "/" in expression):
        return mit + notices
    return list(dict.fromkeys(files))


def main():
    for name, version, _, _, _, files in COMPONENTS:
        for f in files or []:
            if not f.is_file():
                sys.exit("no %s for %s %s: build it first (see README.md)" % (f, name, version))
    crate_version = subprocess.run(["git", "-C", str(CRATE), "describe", "--tags", "--exact-match"],
                                   capture_output=True, text=True).stdout.strip()
    if crate_version != pinned("fetch-crate.sh", "VERSION"):
        sys.exit("crate's checkout at %s isn't at %s, the version fetch-crate.sh pins" % (CRATE, pinned("fetch-crate.sh", "VERSION")))

    out = ["# Third-party notices", "",
           "crate's own code is MPL-2.0 ([LICENSE](LICENSE)). The app also carries the code below,",
           "each under its own license, whose text follows as that project's source states it.",
           "Where a project is MPL-2.0, its license is the same text as [LICENSE](LICENSE). Written by",
           "`Scripts/third-party-notices.py`; [docs/PROVENANCE.md](docs/PROVENANCE.md) says how each",
           "piece is fetched or built.", "",
           "| Component | Version | License | Source | In the app |", "|---|---|---|---|---|"]
    for name, version, spdx, url, where, _ in COMPONENTS:
        out.append("| %s | %s | %s | %s | %s |" % (name, version, spdx, url, where))
    rust = {}
    for owner, root, package, features in RUST:
        for p in rust_packages(root, package, features):
            rust.setdefault((p["name"], p["version"]), (p, set()))[1].add(owner)
    out += ["", "Rust libraries linked into crate and idevice:", "",
            "| Crate | Version | License | Linked into |", "|---|---|---|---|"]
    for (name, version), (p, owners) in sorted(rust.items()):
        out.append("| [%s](https://crates.io/crates/%s) | %s | %s | %s |"
                   % (name, name, version, p["license"], ", ".join(sorted(owners))))

    texts = {}  # sha -> (text, [who])
    order = []

    def add(who, path):
        text = path.read_text(errors="replace").strip("\n")
        key = hashlib.sha256(text.encode()).hexdigest()
        if key not in texts:
            texts[key] = (text, [])
            order.append(key)
        texts[key][1].append(who)

    def label(name, version, path, files):
        # The version when it's one, and which file when there are several.
        text = name if " " in version else "%s %s" % (name, version)
        return text + (" (%s)" % path.name if len(files) > 1 else "")

    for name, version, _, _, _, files in COMPONENTS:
        files = slirp_licenses() if files is None else files
        for f in files:
            add(label(name, version, f, files), f)
    missing = []
    for (name, version), (p, _) in sorted(rust.items()):
        files = rust_license_files(p)
        if not files:
            missing.append("%s %s (%s)" % (name, version, p["license"]))
        for f in files:
            add(label(name, version, f, files), f)

    out += ["", "## License texts", ""]
    for key in order:
        text, who = texts[key]
        out += ["### " + "; ".join(who), "", "````text", text, "````", ""]
    if missing:
        out += ["### Packages that ship no license file", "",
                "These are under the license their package declares, as listed above:", ""]
        out += ["- " + m for m in missing] + [""]
    (REPO / "THIRD_PARTY_NOTICES.md").write_text("\n".join(out))
    print("THIRD_PARTY_NOTICES.md: %d components, %d Rust libraries, %d license texts"
          % (len(COMPONENTS), len(rust), len(order)))


if __name__ == "__main__":
    main()
