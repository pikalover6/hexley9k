# hexley9k

**hexley9k** is a project to retromod [PureDarwin Xmas](http://www.puredarwin.org/developers/xmas) — the 2008 community proof-of-concept release of Darwin 9 (the open-source core of Mac OS X Leopard 10.5.x). The immediate goal is a fully self-contained, reproducible build system capable of producing a bootable PureDarwin Xmas VMware image from source. Longer-term goals include updating components, improving hardware support, and exploring what a modern Darwin userland could look like.

<img width="1672" height="941" alt="9a248216-e77f-4991-b2ce-efb1d827420b" src="https://github.com/user-attachments/assets/2d8a3005-7bd6-4030-b100-ec0a5b945c5a" />
---

## Table of Contents

1. [Background](#1-background)
2. [Repository Structure](#2-repository-structure)
3. [Build Pipeline Overview](#3-build-pipeline-overview)
4. [Build Guide — macOS (primary)](#4-build-guide--macos-primary)
5. [Build Guide — Windows / Linux (experimental)](#5-build-guide--windows--linux-experimental)
6. [Offline Build](#6-offline-build)
7. [Source Changes Reference](#7-source-changes-reference)
8. [Binary Roots Reference](#8-binary-roots-reference)
9. [Repo Contents Detail](#9-repo-contents-detail)
10. [Key Technical Details](#10-key-technical-details)
11. [Known Limitations and Issues](#11-known-limitations-and-issues)
12. [Future Goals](#12-future-goals)
13. [Licensing](#13-licensing)

---

## 1. Background

**PureDarwin** was a community project started around 2007 to make Darwin — Apple's open-source BSD-based operating system core — independently bootable without any closed-source components. It consumed Apple's publicly released Darwin source tarballs from `src.macosforge.org` (now defunct), patched them to remove or stub out internal Apple-only APIs, compiled them with DarwinBuild, and assembled a bootable HFS+J disk image.

**PureDarwin Xmas** was a Christmas 2008 release that demonstrated a working i386 VMware virtual machine running Darwin 9 (corresponding to Mac OS X 10.5.6) with a basic userland, XNU kernel, Chameleon bootloader, X11 window system, and simple desktop (Fluxbox + xterm). It remains the last publicly distributed bootable PureDarwin release.

The original build pipeline broke completely circa 2016 when `macosforge.org` was shut down, taking all source and binary download links with it. hexley9k replaces those dead links: the patched Darwin source trees are committed directly in `source/`, pre-built binary roots for every unmodified package are committed in `puredarwin.roots/Roots/`, and the Darwin SDK headers needed for cross-compilation are assembled from those same pre-built roots — so the entire build works from a single `git clone` with no external downloads.

---

## 2. Repository Structure

```
hexley9k/
│
├── README.md                        ← this file
├── .gitignore
│
├── APPLE_LICENSE.txt                ← Apple Public Source License (APSL 2.0)
├── APPLE_DRIVER_LICENSE.txt         ← Apple Binary Driver EULA
├── PUREDARWIN_LICENSE.txt           ← PureDarwin BSD license
│
├── plists/                          ← DarwinBuild project descriptor
│   └── 9J61pd1.plist                ← Darwin 9 / 10.5.7 / PureDarwin build target
│
├── projects/                        ← PureDarwin-specific source projects
│   ├── pd_xkp/                      ← Obj-C tool: PureDarwin Xmas Kit Package
│   ├── PureDarwinArtworks/          ← Branding images
│   ├── PureDarwinPackageDatabase/   ← SQLite package metadata database + tools
│   └── PureDarwinSettings/          ← Config files deployed verbatim to the image
│       ├── etc/                     ← bashrc, zshrc, ttys, pam.d/
│       ├── Library/Preferences/SystemConfiguration/
│       ├── System/Library/LaunchDaemons/
│       └── var/db/dslocal/nodes/Default/users/root.plist
│
├── puredarwin.roots/
│   ├── Mirror/                      ← Bundled third-party source archives
│   │   ├── libdwarf-8.tar.gz        ← Build dep for dtrace (pre-patched)
│   │   ├── libelf-3.tar.gz          ← Build dep for dtrace + libdwarf
│   │   ├── keymaps-31.tar.gz
│   │   ├── pcsc-lite-1.4.102.tar.gz
│   │   ├── zfs-119.tar.gz
│   │   ├── ACPIPS2Nub-1.tar.gz
│   │   ├── DarwinInstaller-1.tar.gz
│   │   └── DarwinTools-1.tar.gz
│   └── Roots/                       ← Pre-built binary roots (.root.tar.gz)
│       ├── 9A581/                   ← Darwin 9A581 roots (bsm, passwordserver_sasl)
│       ├── 9D34/                    ← Darwin 9D34 roots (DSPasswordServerPlugin, Libinfo)
│       ├── 9F33pd1/                 ← PureDarwin-patched Darwin 9F33 roots (~13 packages)
│       ├── 9G55pd1/                 ← PureDarwin-patched Darwin 9G55 roots (~10 packages)
│       ├── 9J61pd1/                 ← PureDarwin-patched Darwin 9J61 roots (CarbonHeaders)
│       ├── mp/                      ← MacPorts compiled package (tcl 8.5.6)
│       ├── pd/                      ← PureDarwin-specific roots (~32 packages)
│       │   ├── Voodoo_kernel.root.tar.gz        ← Patched XNU for non-Apple hardware
│       │   ├── VoodooPS2Controller.root.tar.gz  ← PS/2 keyboard + mouse KEXT
│       │   ├── Chameleon-2.0-RC4-r684-bin.root.tar.gz ← Bootloader
│       │   ├── PureFoundation.root.tar.gz       ← Open reimplementation of Foundation.framework
│       │   ├── configd.root.tar.gz              ← System Configuration daemon (patched)
│       │   ├── xnu.root.tar.gz                  ← Vanilla XNU headers
│       │   └── ...
│       └── X/                       ← MacPorts X11 packages (25 packages)
│           ├── XFree86-4.7.0*.tbz2  ← X.Org server port
│           ├── fluxbox-1.1.0.1*.tbz2
│           └── ...
│
├── scripts/                         ← Shell utilities deployed inside Darwin
│   ├── pd_adduser                   ← Add user accounts via dscl/passwd
│   ├── pd_injectuser                ← Inject user into dslocal DB (salted SHA-1)
│   ├── pd_installer                 ← CLI installer invoked by launchd on first boot
│   ├── pd_nanoshell                 ← Minimal shell for launchd environments
│   ├── pd_makedmg                   ← Create a DMG from a volume
│   ├── pd_repairpermissions         ← Repair disk permissions
│   ├── pd_startx                    ← Start X11
│   ├── pd_remove                    ← Package removal
│   ├── pd_kextviz                   ← Visualise kext dependency graph (graphviz)
│   ├── pd_machviz                   ← Visualise Mach-O linkage
│   ├── pd_portviz                   ← Visualise Mach port topology
│   ├── pd_dot                       ← Dot graph helper
│   └── pd_ascii_hexley*             ← ASCII art of Hexley mascot
│
├── setup/                           ← Build pipeline scripts (run on macOS host)
│   ├── pd_config                    ← Global variables (ARCH=i386, DARWIN_RELEASE=9)
│   ├── pd_build_source              ← Compile with DarwinBuild (macOS); delegates to pd_build_linux on Linux
│   ├── pd_build_linux               ← Cross-compile with clang + cctools-port (Linux/WSL) ⚠ experimental
│   ├── pd_setup                     ← Assemble bootable HFS+ / VMware image (macOS)
│   ├── pd_setup_linux               ← Assemble bootable image (Linux/WSL) ⚠ experimental
│   ├── pd_setup_prebuilt            ← Shortcut: package a pre-extracted filesystem (macOS)
│   ├── pd_roots                     ← Package list — full release (~160 packages)
│   ├── pd_roots.bootstrap           ← Package list — bootstrap release (~60 packages)
│   ├── pd_roots.nano                ← Package list — minimal nano release
│   ├── pd_roots.extra               ← Extra PureDarwin-specific packages
│   ├── README.txt                   ← Setup notes and pipeline documentation
│   └── pd_setup_files/
│       ├── boot/i386/               ← Chameleon bootloader binaries (boot0, boot1h, boot, cdboot)
│       ├── mkisofs                  ← El Torito ISO builder (macOS binary, used by pd_setup)
│       ├── qemu-img                 ← VMDK converter (macOS binary, used by pd_setup)
│       ├── startupfiletool          ← Sets HFS+ startup file
│       ├── iofindwholemedia         ← Locates whole-disk device node
│       ├── VMware-Drivers-OpenSource.zip  ← NullCPUPowerManagement + LegacyPIIXATA KEXTs
│       └── VMwareIOFramebuffer.kext.zip   ← VMware display driver
│
├── Dockerfile                       ← Multi-stage Docker build (cctools-port + Darwin SDK + compiler)
├── docker-build.sh                  ← One-command wrapper: build + assemble (Windows/Linux) ⚠ experimental
│
├── extracted/
│   └── filesystem/
│       └── PureDarwinXmas/          ← Complete extracted Xmas filesystem (reference)
│           ├── mach_kernel          ← XNU kernel (vanilla)
│           ├── mach_kernel.voodoo   ← XNU kernel (Voodoo patch, used in VM)
│           ├── mach_kernel.ctfsys   ← DTrace CTF type info
│           ├── bin/, sbin/, usr/    ← Standard Darwin userland
│           ├── System/              ← Frameworks, KEXTs, LaunchDaemons
│           ├── Library/             ← Preferences, StartupItems
│           ├── private/             ← etc → /etc, var → /var, tmp → /tmp symlinks
│           └── ...
│
└── source/                          ← Pre-patched Apple Darwin source (committed, all patches applied)
    ├── apple/                       ← Darwin projects at exact tagged versions with patches applied in-tree
    │   ├── at_cmds/                 ← at_cmds-54
    │   ├── bless/                   ← bless-63.2
    │   ├── CF/                      ← CF-476.15
    │   ├── configd/                 ← configd-212.2
    │   ├── dtrace/                  ← dtrace-48
    │   ├── gnutar/                  ← gnutar-442.0.1
    │   ├── IOAudioFamily/           ← IOAudioFamily-169.4.3
    │   ├── iodbc/                   ← iodbc-34
    │   ├── IOHIDFamily/             ← IOHIDFamily-258.3
    │   ├── IOKitUser/               ← IOKitUser-388.2.1
    │   ├── ipv6configuration/       ← ipv6configuration-27
    │   ├── kext_tools/              ← kext_tools-117
    │   ├── launchd_258.18/          ← launchd-258.18 (9J61pd1 target)
    │   ├── launchd_258.1/           ← launchd-258.1 (9F33pd1 target, older)
    │   ├── libsecurity_apple_csp/   ← libsecurity_apple_csp-35205
    │   ├── libsecurity_filevault/   ← libsecurity_filevault-28631
    │   ├── mDNSResponder/           ← mDNSResponder-176.2
    │   └── Tokend/                  ← Tokend-35209
    └── third_party/
        ├── libdwarf-20081013/       ← Extracted from puredarwin.roots/Mirror/libdwarf-8.tar.gz
        └── libelf-3/                ← Extracted from puredarwin.roots/Mirror/libelf-3.tar.gz
```

> `source/` is committed with all upstream patches already applied. Clone the repo and build — no separate fetch or patch step required.

---

## 3. Build Pipeline Overview

The build has two phases — **compile** (produces `.root.tar.gz` archives from source) and **assemble** (packs those archives into a bootable disk image).  Compilation requires a Darwin-compatible toolchain; assembly only requires standard disk-image utilities.

```
 git clone hexley9k
 (source/ included with all patches pre-applied — no separate fetch/patch step)
     │
     ├─── macOS path ──────────────────────────────────────────────────────────
     │    pd_build_source          (DarwinBuild + Xcode 3.x / GCC 4.2)
     │    → Roots/9J61pd1/*.root.tar.gz
     │    pd_setup                 (dd + pdisk + newfs_hfs + bless + qemu-img)
     │    → puredarwin.vmwarevm
     │
     └─── Windows / Linux path  ⚠ EXPERIMENTAL ────────────────────────────────
          docker-build.sh  OR  pd_build_linux
          (clang cross-compiling to i386-apple-darwin9 via cctools-port)
          → Roots/9J61pd1/*.root.tar.gz
          pd_setup_linux           (losetup + parted + mkfs.hfsplus + qemu-img)
          → puredarwin.vmwarevm
```

The pre-built binary roots in `puredarwin.roots/Roots/` cover the majority of packages; only the ~19 patched projects in `source/` need compiling.  The SDK headers used for cross-compilation are assembled from `puredarwin.roots/Roots/pd/xnu.root.tar.gz` and `puredarwin.roots/Roots/9F33pd1/objc4.root.tar.gz` — both committed in this repo.  **No external downloads are required after cloning.**

---

## 4. Build Guide — macOS (primary)

This is the **recommended and fully tested** path.  It uses the same toolchain Darwin 9 was originally built with.

### Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| macOS | 10.5 Leopard or 10.6 Snow Leopard | Recommended; later versions require the 10.5 SDK |
| Xcode | 3.x (3.1.4 is last for Leopard) | Provides GCC 4.2, MacOSX10.5.sdk, pb_makefiles |
| DarwinBuild | current git main | Build driver that manages chroot + dependencies |
| git | any | For cloning this repo |

**Disk space:** ~1.6 GB repo + ~5–10 GB DarwinBuild root + ~800 MB output.

Xcode 3.x is available at [developer.apple.com/download/more](https://developer.apple.com/download/more/) (free Apple Developer account required).

**Install DarwinBuild:**
```sh
git clone https://github.com/apple-oss-distributions/darwinbuild
cd darwinbuild
sudo make install   # installs to /usr/local/bin/darwinbuild
```

### Step 1 — Clone the repo

```sh
git clone https://github.com/pikalover6/hexley9k.git
cd hexley9k
```

`source/` is committed with all patches pre-applied.  No separate fetch or patch step is needed, and no internet access is required after cloning.

### Step 2 — Compile

```sh
sudo ./setup/pd_build_source
```

To rebuild a single project:
```sh
sudo ./setup/pd_build_source kext_tools
```

`pd_build_source` stages the pre-patched source into DarwinBuild's `SourceCache/` (skipping its own download step), then calls `darwinbuild <project>` for each project in dependency order, writing the results to `puredarwin.roots/Roots/9J61pd1/`.

**Build order** (dependency-safe):
```
libelf → libdwarf → dtrace → IOKitUser → IOHIDFamily → IOAudioFamily
→ iodbc → kext_tools → at_cmds → bless → configd → gnutar
→ ipv6configuration → launchd → libsecurity_apple_csp
→ libsecurity_filevault → mDNSResponder → Tokend → CF
```

**Requires:** macOS, root, `darwinbuild`, Xcode 3.x with MacOSX10.5.sdk  
**Output:** `puredarwin.roots/Roots/9J61pd1/<project>.root.tar.gz`

### Step 3 — Assemble the image

```sh
cd setup
sudo ./pd_setup puredarwin.vmwarevm PureDarwin
```

`pd_setup` creates a zeroed raw image, partitions it as Apple Partition Map, formats HFS+J, deploys the binary roots, blesses the volume, creates a `toor` user, rebuilds the kext cache, and converts to VMDK.

| Output path | Format |
|-------------|--------|
| `foo.vmwarevm` | VMware virtual machine bundle (`.vmx` + `.vmdk`) |
| `foo.vmdk` | Raw VMDK only |
| `foo.iso` | Bootable ISO with El Torito |
| `/Volumes/PureDarwin` | Install to a mounted volume |

**Requires:** macOS root, `hdid`, `pdisk`, `newfs_hfs`, `hdiutil`, `vsdbutil`, `kextcache`, `bless`, `ditto`, `chroot`

### Shortcut — Use the pre-built filesystem

Skip compilation and repackage the reference PureDarwin Xmas filesystem directly:

```sh
cd setup
sudo ./pd_setup_prebuilt ../extracted/filesystem/PureDarwinXmas puredarwin.vmwarevm PureDarwin
```

Edit files under `extracted/filesystem/PureDarwinXmas/` before running if you want to customise the image.

---

## 5. Build Guide — Windows / Linux (experimental)

> ⚠️ **Experimental.**  The Windows/Linux pipeline cross-compiles Darwin projects on Linux using `clang` targeting `i386-apple-darwin9` plus [`cctools-port`](https://github.com/tpoechtrager/cctools-port) for the Mach-O linker.  The Darwin SDK headers are assembled entirely from pre-built roots already in this repo — no Apple repositories are cloned.
>
> Cross-compilation of Objective-C heavy projects (CF, configd, IOKitUser) is incomplete without a full Darwin `libSystem` stub.  Expect some projects to produce empty or placeholder roots.  The assembled image will boot with the pre-built roots; the cross-compiled roots are supplementary.

### Option A — Docker (recommended for Windows / any Linux)

**Prerequisites:** Docker Desktop ≥ 20.10 (Windows/Mac) or Docker Engine ≥ 20.10 (Linux).

```sh
# Clone the repo
git clone https://github.com/pikalover6/hexley9k.git
cd hexley9k

# Full pipeline: compile + assemble (first run builds the Docker image ~10–30 min)
./docker-build.sh

# Or: compile only
./docker-build.sh --build-only

# Or: assemble only (if you already have roots from a prior build)
./docker-build.sh --assemble-only

# Rebuild specific projects
./docker-build.sh libelf launchd
```

**On Windows** (from PowerShell or Git Bash with Docker Desktop running):
```powershell
git clone https://github.com/pikalover6/hexley9k.git
cd hexley9k
./docker-build.sh
```

**Output:** `puredarwin.vmwarevm` in the repo root.

The Docker image is self-contained: it builds `cctools-port` from source and assembles the Darwin 9 SDK headers from `puredarwin.roots/Roots/pd/xnu.root.tar.gz` (mach/, sys/, libkern/ headers) and `puredarwin.roots/Roots/9F33pd1/objc4.root.tar.gz` (objc/ headers).  No network access beyond the initial Docker image pull and `cctools-port` clone is required.

**WSL2 note:** WSL1 does not support loop devices.  Ensure you are using WSL2:
```
# In %USERPROFILE%\.wslconfig:
[wsl2]
kernelCommandLine = vsyscall=emulate
```
Then load the loop module before running `pd_setup_linux`:
```sh
sudo modprobe loop
```

### Option B — Bare Linux / WSL2 (manual toolchain setup)

```sh
# 1. Install system packages
sudo apt-get install clang llvm lld make autoconf automake \
     parted kpartx hfsprogs genisoimage qemu-utils rsync openssl xxd

# 2. Build cctools-port
git clone https://github.com/tpoechtrager/cctools-port /opt/cctools-src
cd /opt/cctools-src/cctools
./configure --target=i386-apple-darwin9 --prefix=/opt/cctools \
            --with-llvm-config=/usr/bin/llvm-config
make -j$(nproc) && sudo make install
export PATH=/opt/cctools/bin:$PATH

# 3. Assemble the Darwin 9 SDK from in-repo roots (no Apple cloning needed)
export DARWIN_SDK=/opt/darwin9-sdk
mkdir -p "$DARWIN_SDK"
# XNU kernel headers (mach/, sys/, libkern/, i386/, bsm/, …) + IOKit framework tree
tar xzf puredarwin.roots/Roots/pd/xnu.root.tar.gz -C "$DARWIN_SDK" \
    --wildcards './usr/include/*' './System/Library/Frameworks/IOKit.framework/*'
# Copy IOKit headers into usr/include/IOKit for -I$DARWIN_SDK/usr/include lookups
mkdir -p "$DARWIN_SDK/usr/include/IOKit"
cp -r "$DARWIN_SDK/System/Library/Frameworks/IOKit.framework/Versions/A/Headers/." \
    "$DARWIN_SDK/usr/include/IOKit/"
# Objective-C runtime headers
tar xzf puredarwin.roots/Roots/9F33pd1/objc4.root.tar.gz -C "$DARWIN_SDK" \
    --wildcards './usr/include/objc/*'

# 4. Compile all Darwin projects
./setup/pd_build_linux

# 5. Assemble the disk image (requires root)
sudo ./setup/pd_setup_linux puredarwin.vmwarevm PureDarwin
```

Set `PD_BUILD_VERBOSE=1` to see full compiler output during `pd_build_linux`.

**Output formats supported by `pd_setup_linux`:**
```sh
sudo ./setup/pd_setup_linux puredarwin.vmwarevm PureDarwin   # VMware bundle
sudo ./setup/pd_setup_linux puredarwin.vmdk      PureDarwin  # VMDK only
sudo ./setup/pd_setup_linux puredarwin.iso       PureDarwin  # bootable ISO
```

---

## 6. Offline Build

After the initial `git clone`, **no internet access is required** for any build step on any platform.

| Step | Network needed? | Notes |
|------|----------------|-------|
| `git clone hexley9k` | Yes (once) | All source, patches, and binary roots are included |
| Installing Xcode 3.x | Yes (once, macOS only) | From developer.apple.com |
| Installing DarwinBuild | Yes (once, macOS only) | From github.com/apple-oss-distributions/darwinbuild |
| Building the Docker image | Yes (once) | Pulls `ubuntu:22.04`, installs apt packages, clones `cctools-port` |
| All compile + assemble steps | **No** | Entirely from local files |

`source/` is committed with all patches applied.  The Darwin 9 SDK headers are assembled from `puredarwin.roots/Roots/pd/xnu.root.tar.gz` and `puredarwin.roots/Roots/9F33pd1/objc4.root.tar.gz` — both committed in this repo; no Apple repositories are cloned.  The `puredarwin.roots/Mirror/` directory bundles upstream source archives for `libdwarf`, `libelf`, and other build dependencies.

---

## 7. Source Changes Reference

The table below documents every change applied to the upstream Apple Darwin source trees in `source/`. All changes are already present in the committed source — this table serves as a reference for what was modified and why.

| Change | Project | Version | Description |
|-----------|---------|-----|-------------|
| `at_cmds` | at_cmds | `at_cmds-54` | Define `_OPEN_SOURCE_` to bypass SystemIntegrity.h |
| `bless` | bless | `bless-63.2` | Xcode project fix for open-source build |
| boot-132 (DFE) | boot-132 (DFE) | n/a — source gone | DFE bootloader; source unavailable; pre-built root used |
| `CF` BuildCFLite | CF | `CF-476.15` | Fix `install_name_tool` install path for CoreFoundation |
| `CF` CFBundle_Resources | CF | `CF-476.15` | CFBundle resource loading fix |
| `configd` dy_framework.h | configd | `configd-212.2` | Dynamic framework loading header |
| `configd` SCDPrivate.c | configd | `configd-212.2` | Comment out `CFStringTransform` call missing in PureFoundation |
| `configd` SCNetworkConnection.c | configd | `configd-212.2` | Network connection API stub |
| `configd` SCNetworkConnectionPrivate.c | configd | `configd-212.2` | Private connection API cleanup |
| `configd` SCPrivate.h | configd | `configd-212.2` | Private header adjustment |
| `configd` SystemConfiguration.h | configd | `configd-212.2` | SC framework public header fix |
| `dtrace` dtrace_1.c | dtrace | `dtrace-48` | Command-line tool build fix |
| `dtrace` dt_ld.m | dtrace | `dtrace-48` | Link-editor Objective-C file fix |
| `dtrace` dt_pid_apple.m | dtrace | `dtrace-48` | PID provider Apple-specific fix |
| `dtrace` libproc.m | dtrace | `dtrace-48` | Process inspection library fix |
| `dtrace` libproc_apple.h | dtrace | `dtrace-48` | Apple libproc header compatibility |
| `dtrace` project.pbxproj | dtrace | `dtrace-48` | Xcode project: add libelf/libdwarf deps |
| `gnutar` common.h | gnutar | `gnutar-442.0.1` | `common.h` build fix |
| `IOAudioFamily` | IOAudioFamily | `IOAudioFamily-169.4.3` | KEXT mixer + Info.plist compatibility fix |
| `iodbc` | iodbc | `iodbc-34` | Makefile build fix for open-source context |
| `IOHIDFamily` IOHIDDeviceClass.cpp | IOHIDFamily | `IOHIDFamily-258.3` | Add `objc/objc.h` include to fix linkage |
| `IOHIDFamily` IOHIDQueueClass.cpp | IOHIDFamily | `IOHIDFamily-258.3` | Same include fix for queue class |
| `IOHIDFamily` IOHIDUPSClass.cpp | IOHIDFamily | `IOHIDFamily-258.3` | Same include fix for UPS class |
| `IOKitUser` IOAccelSurfaceControl.c | IOKitUser | `IOKitUser-388.2.1` | Accelerator surface control fix |
| `IOKitUser` IODisplayLib.c | IOKitUser | `IOKitUser-388.2.1` | Display library fix |
| `IOKitUser` IOGraphicsLib.c | IOKitUser | `IOKitUser-388.2.1` | Graphics library fix |
| `IOKitUser` IOHIDEventSystem.c | IOKitUser | `IOKitUser-388.2.1` | HID event system fix |
| `IOKitUser` IOPMAutoWake.c | IOKitUser | `IOKitUser-388.2.1` | Power management auto-wake |
| `IOKitUser` IOPMEnergyPrefs.c | IOKitUser | `IOKitUser-388.2.1` | Energy preferences |
| `IOKitUser` IOPMLibPrivate.c | IOKitUser | `IOKitUser-388.2.1` | Private PM library |
| `IOKitUser` IOPMPowerNotifications.c | IOKitUser | `IOKitUser-388.2.1` | Power notification fix |
| `IOKitUser` IOPMRepeatingPower.c | IOKitUser | `IOKitUser-388.2.1` | Repeating power event fix |
| `IOKitUser` IOPMUPSPrefs.c | IOKitUser | `IOKitUser-388.2.1` | UPS preferences fix |
| `IOKitUser` IOPowerSources.c | IOKitUser | `IOKitUser-388.2.1` | Power source API |
| `IOKitUser` IOPowerSourcesPrivate.c | IOKitUser | `IOKitUser-388.2.1` | Private power source API |
| `IOKitUser` IOSystemConfiguration.c | IOKitUser | `IOKitUser-388.2.1` | System configuration |
| `IOKitUser` IOKitLib.h + GetSymbolFromPEF.h | IOKitUser | `IOKitUser-388.2.1` | IOKitLib.h + GetSymbolFromPEF.h + HID defs fix |
| `IOKitUser` PEFSupport.c | IOKitUser | `IOKitUser-388.2.1` | PEF binary support |
| `ipv6configuration` | ipv6configuration | `ipv6configuration-27` | IPv6 service library fix |
| `kext_tools` bootcaches.c | kext_tools | `kext_tools-117` | Disable BootCache update checks |
| `kext_tools` globals.h | kext_tools | `kext_tools-117` | Global variable declarations |
| `kext_tools` kextd_main.c | kext_tools | `kext_tools-117` | kextd startup fix for PureDarwin |
| `kext_tools` prelink.c | kext_tools | `kext_tools-117` | Prelink fix |
| `kext_tools` project.pbxproj | kext_tools | `kext_tools-117` | Xcode project fix |
| `kext_tools` update_boot.c | kext_tools | `kext_tools-117` | Boot update fix |
| `kext_tools` watchvol.h | kext_tools | `kext_tools-117` | Volume watch header |
| `launchd` 258.18 launchd.c | launchd | `launchd-258.18` | Remove AppleTalk dependency |
| `launchd` 258.18 launchproxy | launchd | `launchd-258.18` | Proxy fix |
| `launchd` 258.18 main | launchd | `launchd-258.18` | SystemStarter + config.h.in fix |
| `launchd` 258.1 | launchd | `launchd-258.1` | Remove quarantine API dependency (9F33pd1) |
| `libdwarf` pro_alloc.c | libdwarf | Mirror/libdwarf-8.tar.gz | `malloc.h` → `sys/malloc.h` |
| `libsecurity_apple_csp` | libsecurity_apple_csp | `libsecurity_apple_csp-35205` | Xcode project fix |
| `libsecurity_filevault` | libsecurity_filevault | `libsecurity_filevault-28631` | FileVault interface fix |
| `mDNSResponder` daemon.c | mDNSResponder | `mDNSResponder-176.2` | Add `CarbonCore/MacTypes.h` include |
| `mDNSResponder` mDNSEmbeddedAPI.h | mDNSResponder | `mDNSResponder-176.2` | Comment out failing size assertions |
| `mDNSResponder` mDNSMacOSX.c | mDNSResponder | `mDNSResponder-176.2` | macOS-specific daemon fix |
| `mDNSResponder` uDNS.c | mDNSResponder | `mDNSResponder-176.2` | uDNS size assertion fix |
| `mDNSResponder` uds_daemon.c | mDNSResponder | `mDNSResponder-176.2` | UDS daemon size assertion fix |
| `Tokend` MacTypes | Tokend | `Tokend-35209` | Replace `MacTypes.h` include paths in smart card headers |

---

## 8. Binary Roots Reference

Projects that have no patch — and thus no source in this repo — are consumed directly from the pre-built `.root.tar.gz` archives in `puredarwin.roots/Roots/`. `pd_setup` reads `setup/pd_roots` and `setup/pd_roots.extra` to determine which roots to unpack and in what order.

**Key pre-built roots:**

| Root | Location | Purpose |
|------|----------|---------|
| `Voodoo_kernel` | `Roots/pd/` | XNU 1228 patched for non-Apple hardware (no EFI, no ACPI assumptions) |
| `VoodooPS2Controller` | `Roots/pd/` | PS/2 keyboard + mouse IOKit KEXT |
| `ACPIPS2Nub` | `Roots/pd/` | ACPI PS/2 nub KEXT |
| `ApplePS2Controller` | `Roots/pd/` | Original Apple PS/2 KEXT (fallback) |
| `Chameleon-2.0-RC4-r684-bin` | `Roots/pd/` | Stage 1/2 bootloader; installs to MBR + boot partition |
| `PureFoundation` | `Roots/pd/` | Open reimplementation of `Foundation.framework` for non-Apple systems |
| `configd` + `configd_plugins` | `Roots/pd/` | System Configuration daemon (patched build) |
| `CFNetwork` | `Roots/pd/` | CoreFoundation network stack |
| `CFOpenDirectory` | `Roots/pd/` | CF-based Open Directory client |
| `NotApple80211` | `Roots/pd/` | 802.11 stub KEXT (prevents kextd crash with no real Wi-Fi) |
| `MacFUSE` | `Roots/pd/` | FUSE kernel extension |
| `PCSC` | `Roots/pd/` | PC/SC smart card daemon |
| `pam_sessioncreate` | `Roots/pd/` | PAM module for session creation |
| `VMware-Drivers-OpenSource` | `pd_setup_files/` | NullCPUPowerManagement + LegacyPIIXATA KEXTs (ZIP) |
| `VMwareIOFramebuffer` | `pd_setup_files/` | VMware display driver KEXT (ZIP) |
| `boot` | `Roots/9F33pd1/` | DFE boot-132 bootloader (pre-built; source unavailable) |
| `xnu` | `Roots/pd/` | XNU kernel headers root |
| `CarbonHeaders` | `Roots/9J61pd1/` | Carbon framework header root |
| XFree86 + 25 X11 packages | `Roots/X/` | MacPorts-built X.Org + Fluxbox + xterm + fonts + libs |
| tcl 8.5.6 | `Roots/mp/` | MacPorts Tcl runtime |

---

## 9. Repo Contents Detail

### `projects/PureDarwinSettings/`

Configuration files that are copied verbatim into the image by `pd_setup`. The directory structure mirrors the target filesystem root:

```
PureDarwinSettings/
├── etc/
│   ├── bashrc          ← Bash configuration with PureDarwin branding
│   ├── zshrc           ← Zsh configuration
│   ├── profile         ← /etc/profile
│   ├── ttys            ← Terminal configuration (enables getty on tty* devices)
│   └── pam.d/          ← PAM service configurations
│       ├── authorization
│       ├── ftpd
│       ├── login
│       ├── other
│       ├── passwd
│       ├── screensaver
│       ├── su
│       └── sudo
├── Library/Preferences/SystemConfiguration/
│   └── preferences.plist   ← Network + hostname preferences
├── System/Library/LaunchDaemons/
│   └── *.plist             ← LaunchD job definitions
├── PostBootSvc/
│   ├── hajimeru            ← Japanese: "begin" — first-boot setup script
│   ├── install-boot-loader ← Installs Chameleon to MBR
│   ├── relinquish-core-files ← Core dump cleanup
│   └── switch-kernel       ← Switches between vanilla and Voodoo kernels
└── var/db/dslocal/nodes/Default/users/
    └── root.plist          ← Root user's OpenDirectory record
```

To customise the image, edit files here before running `pd_setup`.

### `projects/PureDarwinPackageDatabase/`

A standalone SQLite-based package registry tracking Darwin open-source packages:
- `pdpd` — the SQLite database
- `tools/pdpdmake` — builds/updates the database from text files
- `tools/dbaudit` — audits installed packages against the database
- `tools/dbstats` — prints statistics
- `PackageLists/found.txt` — packages with available binaries
- `PackageLists/missing.txt` — packages that had no binary roots at Xmas time

### `projects/pd_xkp/`

**PureDarwin Xmas Kit Package** — a small Objective-C command-line tool that produces a structured tarball of PureDarwin components. Source files:
- `main.m`, `Scrambler.{h,m}`, `Crash.{h,m}`, `Usage.{h,m}`

Build it on macOS: `make -C projects/pd_xkp`

### `scripts/`

Shell scripts intended to run **inside** the PureDarwin VM, not on the build host. Key ones:

| Script | Purpose |
|--------|---------|
| `pd_installer` | First-boot CLI installer invoked by launchd. Partitions, formats, and installs from the boot media to a target disk. |
| `pd_injectuser` | Injects a user record into the OpenDirectory local node (`/var/db/dslocal/nodes/Default/`) using salted SHA-1 password hashing. Used by `pd_setup` to create the `toor` account. |
| `pd_adduser` | Higher-level user creation via `dscl` and `passwd`. Requires the DS daemon running. |
| `pd_nanoshell` | Minimal `sh`-compatible shell wrapper, used as a fallback when `bash` is unavailable during early boot. |
| `pd_makedmg` | Wraps `hdiutil create` to produce a DMG from a directory or volume. |
| `pd_repairpermissions` | Iterates the `bom` database and calls `chmod`/`chown` to repair permissions. |
| `pd_startx` | Starts the X11 server (XFree86) with Fluxbox as the window manager. |
| `pd_kextviz` | Generates a Graphviz dot graph of loaded kext dependencies from `kextstat` output. |

---

## 10. Key Technical Details

### Bootloaders

Two bootloaders are present:

1. **Chameleon 2.0 RC4** (default) — A community Darwin bootloader derived from Apple's `boot-132`. Handles APM partition maps, HFS+, and loads the XNU kernel with an EFI shim. Installed as:
   - `boot0` → MBR (stage 0, 446 bytes)
   - `boot1h` → HFS+ partition boot record (stage 1)
   - `boot` → `/boot` (stage 2, full bootloader binary)
   
   The `Chameleon-2.0-RC4-r684-bin.root.tar.gz` in `Roots/pd/` contains the pre-built binaries. `pd_setup` also uses the copies in `pd_setup_files/boot/i386/` for direct MBR installation.

2. **DFE boot-132** (alternate, via patch files only) — The Direct From EFI fork of Apple's `boot-132` bootloader. Source was on Google Code (defunct). Pre-built binary root is at `Roots/9F33pd1/boot.root.tar.gz`. The three `boot-132_dfe_*.p0.patch` files are archived for reference but cannot be applied without the source.

### Disk Format

PureDarwin Xmas uses **Apple Partition Map (APM)** — the classic Mac disk format, not GPT. APM is selected because:
- The Chameleon bootloader's `boot0` stage understands APM
- `pdisk` (the partitioning tool) is available as a Darwin open-source binary
- El Torito CD-ROM boot requires specific sector placement that APM handles well

The disk layout created by `pd_setup`:
```
Sector 0:        MBR (Chameleon boot0)
Sectors 1–63:    APM partition map
  partition 1:   Apple_HFS  (main filesystem, HFS+J)
  partition 2:   Apple_Boot (optional, for EFI boot support)
```

### XNU Kernel Variants

Three kernel images are present in `extracted/filesystem/PureDarwinXmas/`:

| File | Description |
|------|-------------|
| `mach_kernel` | Vanilla XNU 1228 (official Apple release) |
| `mach_kernel.voodoo` | XNU with Voodoo patches: removes Apple hardware assumptions, disables `AppleACPIPlatform` dependency, and adds generic CPU power management |
| `mach_kernel.ctfsys` | CTF (Compact Type Format) type information for DTrace |

The Voodoo kernel (`mach_kernel.voodoo`) is what the VM actually boots with. The `switch-kernel` PostBootSvc script can swap between variants.

### PureFoundation

`Foundation.framework` in standard Darwin depends on internal Apple APIs that are not open-source. `PureFoundation.framework` is a from-scratch reimplementation of the Foundation Objective-C runtime classes (NSString, NSArray, NSDictionary, etc.) that works without closed-source components. It is loaded in place of the real framework via `DYLD_FRAMEWORK_PATH`.

### DTrace Integration

DTrace on PureDarwin requires three separately compiled components:
- `dtrace` (the command-line tool) — compiled from `source/apple/dtrace`
- `libdtrace.dylib` — the DTrace library
- `mach_kernel.ctfsys` — kernel CTF type information

The `dtrace-48.project.pbxproj.p1.patch` adds `libelf` and `libdwarf` as explicit build dependencies since they are not installed in /usr on the build host.

### launchd

Two versions of `launchd` are carried:
- `launchd-258.18` (patched) — targets the 9J61 release. Removes `AppleTalk` framework dependency.
- `launchd-258.1` (patched) — targets the older 9F33 release. Removes Quarantine API (private Apple framework not available in open source).

`pd_setup` uses the 9J61pd1 build by default.

---

## 11. Known Limitations and Issues

### macOS build host
The macOS path (DarwinBuild + Xcode 3.x) has only been tested on macOS Leopard/Snow Leopard.  Building on later macOS requires manually installing the MacOSX10.5.sdk; Apple does not ship it with Xcode 4+.

### Windows / Linux cross-compilation (experimental)
The `pd_build_linux` / `docker-build.sh` path cross-compiles Darwin projects using `clang -target i386-apple-darwin9` and `cctools-port`.  Projects that are Objective-C-heavy (CF, configd, IOKitUser) require a full `libSystem.B.dylib` stub that is not yet included; those projects produce placeholder roots.  The assembled image boots via the pre-built roots; cross-compiled roots are supplementary.

### boot-132 source is unavailable
The DFE `boot-132` bootloader source was hosted exclusively on `puredarwin.googlecode.com`, which has been defunct since 2016. The three `boot-132_dfe_*.p0.patch` files are kept for historical reference but cannot be applied. The pre-built `boot.root.tar.gz` in `Roots/9F33pd1/` is used instead.

### Missing source changes for 7 projects
The following projects are listed in `plists/9J61pd1.plist` as having patches, but the corresponding source changes were never recorded and are not present in `source/`:
- `CFNetwork-129.20` — `CFNetwork-129.20.p1.patch.0`
- `JavaScriptCore-5525.26.2` — `JavaScriptCore-5525.26.2.p1.patch.0`
- `Libc-498.1.7` — `Libc-498.1.7.p1.patch.0`
- `efax-28` — `efax-28.p1.patch.{0,1}`
- `emacs-70.1` — `emacs-70.1.p1.patch.{0,1}`
- `libsecurity_ldap_dl-30174` — `libsecurity_ldap_dl-30174.p1.patch.0`
- `security_dotmac_tp-33607` — `security_dotmac_tp-33607.p1.patch.{0,1,2}`

Pre-built binary roots for all of these are available in `puredarwin.roots/Roots/`.

### No network stack in early boot
The PureDarwin Xmas configuration uses `configd` + `mDNSResponder` for network, but DHCP is not always reliable in VMware without the correct VirtioNet or vmxnet driver. The generated `.vmx` uses `vmxnet` (VMware Para-Virtual NIC), which is supported by the `NotApple80211` stub and the included vmxnet KEXT.

### Xmas-era software
All userland dates to late 2008. This is intentional for the current phase; modernisation is a future goal.

---

## 12. Future Goals

hexley9k currently prioritises build reproducibility. Planned future work, roughly in priority order:

1. **Patch `clang` support into the build system** — The DarwinBuild toolchain uses GCC 4.2. Enabling Clang (which Apple was already shipping in Xcode 3.2) would allow newer code to compile.

2. **Update launchd** — Newer launchd versions have better error handling and `launchctl` ergonomics. A port to a more recent Darwin 9 build (9L30 / 10.5.8) is a natural first step.

3. **Replace PureFoundation with a more complete implementation** — PureFoundation covers the common NSObject hierarchy but misses large portions of Foundation needed by real applications. GNUstep or Cocotron could serve as a richer alternative base.

4. **Add a working network stack configuration** — Improve DHCP reliability, address the `configd` assertion failures that appear on some hardware, and add `/etc/resolv.conf` generation.

5. **Package manager** — The `PureDarwinPackageDatabase` scaffolding exists; a proper `pd_install`/`pd_remove` cycle backed by the `.root.tar.gz` format would enable proper package management.

6. **AArch64 / Apple Silicon** — Extremely speculative, but Darwin 22+ (macOS Ventura) XNU source is available for arm64. A future hexley9k could target Darwin 22 on arm64 with a completely different toolchain.

7. **CI / automation** — A GitHub Actions workflow using a macOS runner for full builds and a Linux runner to validate cross-compilation and image assembly on every push.

---

## 13. Licensing

This repository contains code and binaries under multiple licenses:

| Component | License |
|-----------|---------|
| Apple open-source components (`source/`, `puredarwin.roots/Roots/`) | Apple Public Source License 2.0 — see `APPLE_LICENSE.txt` |
| Apple binary drivers and KEXTs (`pd_setup_files/VMware*.zip`, driver roots) | Apple Binary Driver Software License Agreement — see `APPLE_DRIVER_LICENSE.txt` |
| PureDarwin-authored scripts and configuration (`setup/pd_*`, `scripts/pd_*`, `projects/PureDarwinSettings/`) | BSD 2-Clause — see `PUREDARWIN_LICENSE.txt` |
| Chameleon bootloader | Apple Public Source License 2.0 (derived from Apple `boot-132`) |
| XFree86 / X.Org components (`Roots/X/`) | MIT X11 License |
| MacPorts packages (`Roots/mp/`) | Various open-source licenses per package |
| hexley9k additions (this README, `pd_build_source`, `pd_build_linux`, `pd_setup_linux`, `Dockerfile`, `docker-build.sh`) | BSD 2-Clause |

Please read all applicable licenses before redistributing any portion of this software.
