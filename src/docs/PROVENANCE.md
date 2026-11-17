# Where crate's code comes from

Everything the app ships besides its own code, where each piece comes from, and
how it gets into `Frameworks/`. Nothing there is committed: the scripts in
`Scripts/` fetch or build it, pinned to a version and checked against a SHA-256
or a commit. The built frameworks are published as this repository's
frameworks release, which `fetch-frameworks.sh` fetches; the build scripts make
the same files. crate's own code is MPL-2.0 ([LICENSE](../LICENSE)); each piece
below keeps its own license, and
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) has every license's text,
down to the Rust libraries.

| Piece | Version | License | From | How |
| --- | --- | --- | --- | --- |
| [crate](https://github.com/oneamendez/crate) | v0.1.1 | MPL-2.0 | its release, attested | `fetch-crate.sh`, or `build-crate.sh` from a checkout |
| [StikJIT](https://github.com/StikDebug/StikJIT) | 2.0.1 | MPL-2.0 | its release's framework | `fetch-stikjit.sh` |
| [idevice](https://github.com/jkcoxson/idevice) | 0.1.68 | MIT | its source | `build-idevice.sh`, one patch |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | 1.18.0 | MIT | Swift package | Xcode |
| [libslirp](https://gitlab.freedesktop.org/slirp/libslirp) | 4.9.7 | BSD-3-Clause | its release's source | `build-slirp.sh` |
| [GLib](https://gitlab.gnome.org/GNOME/glib) | 2.90.1 | LGPL-2.1-or-later | its release's source | `build-slirp.sh`, unmodified, a dynamic framework |
| [libffi](https://github.com/libffi/libffi) | 3.5.2 | MIT | GLib's meson subproject | linked into GLib |
| [PCRE2](https://github.com/PCRE2Project/pcre2) | 10.46 | BSD-3-Clause | GLib's meson subproject | linked into GLib |
| [proxy-libintl](https://github.com/frida/proxy-libintl) | 0.5 | LGPL-2.0-or-later | GLib's meson subproject | linked into GLib |
| [MoltenVK](https://github.com/KhronosGroup/MoltenVK) | 1.4.2 | Apache-2.0 | its release tag's source | `build-moltenvk.sh` |
| [ANGLE](https://chromium.googlesource.com/angle/angle) | 9addc29 | BSD-3-Clause | its source | `build-angle.sh`, one patch |
| [libepoxy](https://github.com/anholt/libepoxy) | 1.5.10 | MIT | its release's source | `build-virgl.sh`, one patch |
| [virglrenderer](https://gitlab.freedesktop.org/virgl/virglrenderer) | 1.3.0 | MIT | its release's source | `build-virgl.sh`, three patches |

MoltenVK's build fetches its own dependencies at the revisions its release
names; SPIRV-Cross, SPIRV-Tools, SPIRV-Headers, cereal and the Vulkan headers
end up in MoltenVK.framework (Apache-2.0, MIT and BSD-3-Clause). ANGLE's gclient
checkout does the same for what ANGLE links: Abseil, astc-encoder, LLVM's libc,
SPIRV-Tools, SPIRV-Headers, the Vulkan headers, Vulkan Memory Allocator and zlib
(Apache-2.0, MIT and Zlib). crate links seven small Rust libraries and idevice
about two hundred, all MIT, Apache-2.0, BSD, ISC or similar.

GLib is LGPL: it stays its own framework, unmodified, so it can be replaced,
and its source is its release's tarball, which `build-slirp.sh` downloads and
checks. Everything else is permissive or MPL-2.0, so the app as a whole can be
MPL-2.0.

## Not in the app

crate works with these, but doesn't carry them:

- [StikDebug](https://github.com/StikDebug/StikDebug), the app that can turn
  crate's JIT on. crate asks for it the way StikDebug's legacy.js script
  expects; its built-in JIT is StikJIT, from the same project, above.
- [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044), the tunnel the
  built-in StikJIT reaches the iPhone's debugging service through.
- The guest images, from
  [arm64-desktop-images](https://github.com/oneamendez/arm64-desktop-images):
  downloaded when installing a VM, never part of the app. Each distribution
  is under its own licenses.

## The patches

In `Scripts/patches/`, each with a header saying what it changes and why:

- `idevice-pairable-host.patch`: lets crate advertise itself as a computer the
  iPhone pairs with, for Set Up JIT's on-device pairing.
- `angle-vulkan.patch`: ANGLE's Vulkan backend inside an iOS app, on MoltenVK.
  Written for aTerm, the app crate succeeds, and carried over unchanged.
- `libepoxy-ios-angle.patch`: libepoxy's EGL support on an iPhone, opening
  ANGLE's frameworks.
- `virglrenderer-angle-integer-attribs.patch`: integer vertex attributes
  declared as integers on ANGLE, which Vulkan holds to their declared type.
  Without it every glyph and image Chrome draws on the GPU samples the wrong
  place.
- `virglrenderer-border-clamp.patch`: clamp to the edge where ANGLE on MoltenVK
  has no border clamp, rather than a call ANGLE refuses.
- `virglrenderer-cursor-rows.patch`: the cursor's rows top first, as crate shows
  them; upstream turns every cursor upside down.

## The 3D stack

The guest's Mesa draws through virtio-gpu; crate hands those commands to
virglrenderer, which turns them into OpenGL ES calls (through libepoxy) on ANGLE,
which runs on Vulkan, which is MoltenVK, on Metal. Guest images need nothing of
their own for it: Mesa's virgl driver and the kernel's virtio-gpu driver, both
standard in Debian and Arch.

aTerm had the same stack, but only ANGLE was its own build from upstream: it
took virglrenderer, libepoxy and MoltenVK prebuilt from another project, with
that project's changes to virglrenderer. None of that is used here. Each piece
is built from its upstream release. virglrenderer's three patches above are
crate's own, each found by comparing upstream's behaviour with that build's on
the same guest, never from its source. The sample-count override aTerm had to
patch around isn't in upstream. virglrenderer is built with its
`check-gl-errors` option off, so a GL call ANGLE refuses costs that call rather
than the guest's whole GL context.
