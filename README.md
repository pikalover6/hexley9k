# hexley9k

**hexley9k** is a project to retromod [PureDarwin Xmas](http://www.puredarwin.org/developers/xmas) — the 2008 community proof-of-concept release of Darwin 9 (the open-source core of Mac OS X Leopard 10.5.x). The immediate goal is a fully self-contained, reproducible build system capable of producing a bootable PureDarwin Xmas VMware image from source. Longer-term goals include updating components, improving hardware support, and exploring what a modern Darwin userland could look like.

<img width="1672" height="941" alt="9a248216-e77f-4991-b2ce-efb1d827420b" src="https://github.com/user-attachments/assets/2d8a3005-7bd6-4030-b100-ec0a5b945c5a" />

---

## What works today

- **PureDarwin Xmas boots to a graphical desktop in QEMU on a modern Mac — Apple Silicon included.** The blocker was never the OS; it was a missing capability in QEMU's emulated VMware-SVGA card. A ~170-line patch to `vmware_vga.c` (FIFO capability bits + display-topology registers) lets `VMwareIOFramebuffer.kext` initialize, and the WindowMaker desktop comes up at 1024×768.
- **A genuinely from-source `libSystem.B.dylib` (3258 exports) + 178 userland tools** build with a modern cross-toolchain (i386 Mach-O, natively on arm64 — no x86 emulation) and **run on real Darwin 9**: syscalls, Mach, `malloc`/`free`, full stdio, pthreads, signals. This is the hard part of *"no binaries copied from the recovered image."*
- A self-contained 100%-from-source userland (libSystem + all 178 tools) installed under `/fromsrc` and **verified executing real programs on the live OS** (`uname` → `Darwin 9.5.0 i386`, `cat /etc/group | wc -l` → `76`, …).

> **Honest scope:** this is a hobby research build. The full bootable image still rides on the recovered Voodoo XNU kernel + drivers; the *userland foundation* (libSystem + tools) is what is now genuinely from source. A handful of libc functions (some networking, utmpx, copyfile) are stubs that link but return errors. See [`docs/STATUS-AND-HANDOVER.md`](docs/STATUS-AND-HANDOVER.md) for the exact state.

---

## Run it

PureDarwin Xmas is an **i386** OS. You need a way to run a 32-bit x86 VM plus an emulated **VMware-SVGA** display (that's what its graphics stack expects).

**On a real x86 host:** boot the image in **VMware** (Workstation/Fusion/Player) — graphics work out of the box. QEMU on x86 with `-vga vmware` also works.

**On Apple Silicon (or any host, via emulation):** use a QEMU built with the VMware-SVGA patch from this project, then:

```sh
qemu-system-i386 -M pc -cpu Penryn -m 1024 \
  -drive file=puredarwinxmas.raw,format=raw,if=ide,media=disk \
  -vga vmware -boot c
```

Press **Enter** at the Chameleon boot prompt; the desktop appears in ~1–2 minutes (emulated). Use `-vga std` instead of `-vga vmware` to get a text console rather than the GUI.

- Don't have an image? The reference image is the recovered `puredarwinxmas.vmdk` (PureDarwin's *NewBootEnvironment-XMas* release); convert it with `qemu-img convert -O raw puredarwinxmas.vmdk puredarwinxmas.raw`, or build one yourself (below).
- The QEMU patch and a ready-to-run launcher script are documented in [`docs/STATUS-AND-HANDOVER.md`](docs/STATUS-AND-HANDOVER.md).

---

## Build it from source

There are two independent build stories. Pick based on what you want.

### A. The from-source foundation — `libSystem` + userland (modern, runs on any Mac)

This is the current frontier and runs on a **modern macOS + Docker** (Apple Silicon fine). It cross-compiles Apple's Darwin-9 sources to i386 Mach-O with `clang -target i386-apple-darwin9` + `cctools-port`.

```sh
# one-time: a Linux x86_64 container holding the cross-toolchain + Darwin-9 SDK
colima start                       # or Docker Desktop
docker build -t puredarwin-builder .

# build the from-source umbrella libSystem.B.dylib
cd foundation
docker run --rm -v "$PWD/..:/repo" puredarwin-builder \
  sh -c 'cd /repo/foundation && sh build-libsystem.sh'
# -> foundation/lib-system/libSystem.B.dylib  (NOUNDEFS, 3258 exports)
```

The 178 userland tools are prebuilt from source under `puredarwin.roots/Roots/9J61pd1/*.root.tar.gz`. To confirm every tool is symbol-compatible with the from-source libSystem, run `foundation/_analyze.sh`. Full recipe + the runtime-verification harness: [`docs/FROM-SOURCE-RESUME-NOTES.md`](docs/FROM-SOURCE-RESUME-NOTES.md).

### B. The full bootable image (classic DarwinBuild pipeline)

The original pipeline assembles a complete bootable HFS+/VMware image from the committed, pre-patched Darwin sources. It needs the period-correct toolchain:

```sh
./docker-build.sh             # full pipeline in the repo's container, OR
sudo ./setup/pd_build_source  # on macOS Leopard/Snow Leopard + Xcode 3.x
sudo ./setup/pd_setup puredarwin.vmwarevm PureDarwin
```

This path (DarwinBuild, disk layout, bootloaders, kext cache, etc.) is documented in detail in [`docs/BUILD-PIPELINE-AND-INTERNALS.md`](docs/BUILD-PIPELINE-AND-INTERNALS.md).

---

## Essential technical components

- **Patched QEMU vmware-svga** — what makes the GUI come up under emulation on a modern Mac (the kext needs FIFO `CURSOR_BYPASS_3`/`RESERVE` caps + SVGA display-topology registers).
- **Cross-toolchain** — `clang -target i386-apple-darwin9` + `cctools-port`, in a Docker image, producing i386 Mach-O natively on arm64.
- **From-source `libSystem.B.dylib`** — the umbrella every Darwin program links; built from Apple Libc-498.1.7 + xnu-1228.7.58 libsyscall. Getting `malloc` working came down to two systemic i386 syscall-stub bugs (a missing success-path `ret` in every stub, and `$UNIX2003` aliases all collapsing onto `_accept`) — write-up in [`docs/STATUS-AND-HANDOVER.md`](docs/STATUS-AND-HANDOVER.md) §6.
- **Voodoo XNU + Chameleon** — the recovered kernel patched for non-Apple hardware, loaded by the Chameleon bootloader (APM disk, HFS+J).
- **PureFoundation** — an open reimplementation of `Foundation.framework` (Apple's is not fully open-source).

---

## Detailed documentation

Everything that used to live in this README — repo structure, the full build pipeline, disk/boot internals — plus the from-source research notes now live under [`docs/`](docs/):

| Doc | What's in it |
|-----|--------------|
| [`docs/STATUS-AND-HANDOVER.md`](docs/STATUS-AND-HANDOVER.md) | Current state of every track, the malloc post-mortem, how to reproduce/verify |
| [`docs/BUILD-PIPELINE-AND-INTERNALS.md`](docs/BUILD-PIPELINE-AND-INTERNALS.md) | The classic build pipeline, repo layout, bootloaders, disk format, kernels |
| [`docs/FROM-SOURCE-PROGRESS-LEDGER.md`](docs/FROM-SOURCE-PROGRESS-LEDGER.md) | Chronological ledger of the from-source foundation work |
| [`docs/FROM-SOURCE-RESUME-NOTES.md`](docs/FROM-SOURCE-RESUME-NOTES.md) | Terse live state + exact build/verify commands |

---

## Roadmap

hexley9k is the foundation for a larger, deliberately hacky goal: **retromod PureDarwin Xmas into something semi-usable as a modern OS** — a nicer desktop, a real set of working tools, and ideally a web browser. Rough direction:

1. **Finish the from-source userland** — replace the stubbed libc functions (networking, utmpx, copyfile) with real implementations; relink the system's own binaries against the from-source libSystem.
2. **Quality-of-life userland** — bash/zsh, coreutils-level tools, a package story, a writable home.
3. **A modern-feeling desktop** — beyond twm/WindowMaker; a tiling or lightweight DE, working mouse, sane resolution.
4. **Networking + a browser** — get TCP/IP fully functional, then a period-or-ported lightweight browser (the long pole).
5. **Better host story** — a one-command QEMU launcher and a prebuilt image so anyone can boot it without the build dance.

Contributions, ideas, and hacks welcome — "very hacky" is on-brand here.

---

## Licensing

Apple sources are under the **Apple Public Source License 2.0** (`APPLE_LICENSE.txt`); PureDarwin additions under a **BSD license** (`PUREDARWIN_LICENSE.txt`); bundled Apple binary drivers under Apple's **Binary Driver EULA** (`APPLE_DRIVER_LICENSE.txt`). This is an unofficial community project, not affiliated with or endorsed by Apple.
