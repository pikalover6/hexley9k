# hexley9k — GitHub Copilot Instructions

## What This Project Is

**hexley9k** is a retromod of [PureDarwin Xmas](http://www.puredarwin.org/developers/xmas) — the 2008 Christmas release that demonstrated a bootable Darwin 9 (the open-source core of Mac OS X 10.5.6 Leopard) running in a VMware virtual machine. The project name comes from [Hexley](https://en.wikipedia.org/wiki/Hexley), the Darwin BSD daemon mascot; `9k` refers to Darwin 9 (XNU kernel 1228).

**Primary goal:** a fully self-contained, reproducible build system that produces a bootable PureDarwin Xmas VMware image from source, requiring only `git clone` and no external downloads.

**Secondary goal:** modernise components and improve hardware support incrementally once reproducibility is solid.

The original PureDarwin infrastructure (macosforge.org, Google Code) was shut down around 2016. hexley9k inlines everything that was previously downloaded:
- All patched Darwin source trees are committed under `source/` with patches pre-applied.
- All pre-built binary roots are committed under `puredarwin.roots/Roots/`.
- All third-party source archives are committed under `puredarwin.roots/Mirror/`.
- The Darwin 9 SDK headers needed for cross-compilation are assembled from committed roots — no Apple repos are cloned.

---

## Repository Structure

```
hexley9k/
├── .github/
│   └── copilot-instructions.md   ← this file
├── APPLE_LICENSE.txt             ← Apple Public Source License 2.0
├── APPLE_DRIVER_LICENSE.txt      ← Apple Binary Driver EULA
├── PUREDARWIN_LICENSE.txt        ← PureDarwin BSD 2-Clause
├── README.md                     ← comprehensive project documentation
├── Dockerfile                    ← multi-stage build: cctools-port + Darwin SDK + compiler
├── docker-build.sh               ← one-command wrapper for Docker-based builds
│
├── plists/
│   └── 9J61pd1.plist             ← DarwinBuild project descriptor (Darwin 9/10.5.7)
│
├── projects/
│   ├── pd_xkp/                   ← Obj-C CLI tool: PureDarwin Xmas Kit Package
│   ├── PureDarwinArtworks/       ← Mascot and branding assets
│   ├── PureDarwinPackageDatabase/← SQLite package metadata DB + audit/stats tools
│   └── PureDarwinSettings/       ← Config files deployed verbatim into the image
│       ├── etc/                  ← bashrc, zshrc, profile, ttys, pam.d/
│       ├── Library/Preferences/SystemConfiguration/
│       ├── System/Library/LaunchDaemons/
│       ├── PostBootSvc/          ← First-boot scripts (hajimeru, switch-kernel, …)
│       └── var/db/dslocal/nodes/Default/users/root.plist
│
├── puredarwin.roots/
│   ├── Mirror/                   ← Bundled upstream source archives (libdwarf, libelf, …)
│   └── Roots/
│       ├── 9A581/                ← Darwin 9A581 pre-built roots
│       ├── 9D34/                 ← Darwin 9D34 pre-built roots
│       ├── 9F33pd1/              ← PureDarwin-patched Darwin 9F33 roots (~13 packages)
│       ├── 9G55pd1/              ← PureDarwin-patched Darwin 9G55 roots (~10 packages)
│       ├── 9J61pd1/              ← PureDarwin-patched Darwin 9J61 roots (build output goes here too)
│       ├── mp/                   ← MacPorts-compiled packages (tcl 8.5.6)
│       ├── pd/                   ← PureDarwin-specific roots (Voodoo kernel, Chameleon, PureFoundation, …)
│       └── X/                    ← MacPorts X11 packages (XFree86, Fluxbox, xterm, fonts, libs)
│
├── scripts/                      ← Shell utilities that run INSIDE the PureDarwin VM
│   ├── pd_installer              ← First-boot CLI installer (partitions + installs to disk)
│   ├── pd_injectuser             ← Injects user into OpenDirectory local node
│   ├── pd_adduser                ← Higher-level user creation via dscl/passwd
│   ├── pd_nanoshell              ← Minimal sh wrapper for early-boot environments
│   ├── pd_makedmg                ← Creates a DMG from a directory or volume
│   ├── pd_repairpermissions      ← Repairs permissions via BOM database
│   ├── pd_startx                 ← Starts X11 (XFree86) with Fluxbox
│   ├── pd_kextviz                ← Graphviz dot graph of kext dependencies
│   ├── pd_machviz                ← Visualises Mach-O linkage
│   ├── pd_portviz                ← Visualises Mach port topology
│   ├── pd_dot                    ← Graphviz helper
│   └── pd_ascii_hexley*          ← ASCII art mascot variants
│
├── setup/                        ← Build pipeline scripts — run on the HOST, not the VM
│   ├── pd_config                 ← Global variables: ARCH, DARWIN_RELEASE, ADD_* feature flags
│   ├── pd_build_source           ← macOS: compiles with DarwinBuild + Xcode 3.x / GCC 4.2
│   ├── pd_build_linux            ← Linux/Docker: cross-compiles with clang + cctools-port
│   ├── pd_setup                  ← macOS: assembles HFS+J disk image + VMware bundle
│   ├── pd_setup_linux            ← Linux/WSL2: assembles disk image with Linux tools
│   ├── pd_setup_prebuilt         ← macOS shortcut: packages extracted/filesystem/PureDarwinXmas
│   ├── pd_roots                  ← Package list for full release (~160 packages)
│   ├── pd_roots.bootstrap        ← Package list for bootstrap release (~60 packages)
│   ├── pd_roots.nano             ← Package list for minimal nano release
│   ├── pd_roots.extra            ← Extra PureDarwin-specific packages
│   ├── README.txt                ← Pipeline notes
│   └── pd_setup_files/
│       ├── boot/i386/            ← Chameleon bootloader binaries (boot0, boot1h, boot, cdboot)
│       ├── mkisofs               ← El Torito ISO builder (macOS Mach-O binary)
│       ├── qemu-img              ← VMDK converter (macOS Mach-O binary)
│       ├── startupfiletool       ← Sets the HFS+ startup file
│       └── iofindwholemedia      ← Locates the whole-disk device node
│
├── source/                       ← Pre-patched Apple Darwin source (all patches applied in-tree)
│   ├── apple/                    ← Darwin projects at their exact tagged versions
│   │   ├── at_cmds/              ← at_cmds-54
│   │   ├── bless/                ← bless-63.2
│   │   ├── CF/                   ← CF-476.15 (CoreFoundation)
│   │   ├── configd/              ← configd-212.2
│   │   ├── dtrace/               ← dtrace-48
│   │   ├── gnutar/               ← gnutar-442.0.1
│   │   ├── IOAudioFamily/        ← IOAudioFamily-169.4.3
│   │   ├── iodbc/                ← iodbc-34
│   │   ├── IOHIDFamily/          ← IOHIDFamily-258.3
│   │   ├── IOKitUser/            ← IOKitUser-388.2.1
│   │   ├── ipv6configuration/    ← ipv6configuration-27
│   │   ├── kext_tools/           ← kext_tools-117
│   │   ├── launchd_258.1/        ← launchd-258.1 (9F33pd1 target)
│   │   ├── launchd_258.18/       ← launchd-258.18 (9J61pd1 target, default)
│   │   ├── libsecurity_apple_csp/← libsecurity_apple_csp-35205
│   │   ├── libsecurity_filevault/← libsecurity_filevault-28631
│   │   ├── mDNSResponder/        ← mDNSResponder-176.2
│   │   └── Tokend/               ← Tokend-35209
│   └── third_party/
│       ├── libdwarf-20081013/    ← Extracted from Mirror/libdwarf-8.tar.gz (dtrace dep)
│       └── libelf-3/             ← Extracted from Mirror/libelf-3.tar.gz (dtrace dep)
│
└── extracted/
    └── filesystem/
        └── PureDarwinXmas/       ← Complete extracted Xmas filesystem (reference / shortcut)
            ├── mach_kernel        ← Vanilla XNU 1228 kernel
            ├── mach_kernel.voodoo ← XNU with Voodoo patches (what the VM boots)
            ├── mach_kernel.ctfsys ← DTrace CTF type information
            ├── bin/, sbin/, usr/  ← Standard Darwin userland
            ├── System/            ← Frameworks, KEXTs, LaunchDaemons
            ├── Library/           ← Preferences, StartupItems
            └── private/           ← Symlinks: etc→/etc, var→/var, tmp→/tmp
```

---

## Build Pipeline

The build has two distinct phases:

### Phase 1 — Compile (produces `.root.tar.gz` archives from source)

Only the ~19 patched projects in `source/` need compiling. The majority of packages are covered by pre-built binary roots already committed in `puredarwin.roots/Roots/`.

**Build order (dependency-safe for all projects):**
```
libelf → libdwarf → dtrace → IOKitUser → IOHIDFamily → IOAudioFamily
→ iodbc → kext_tools → at_cmds → bless → configd → gnutar
→ ipv6configuration → launchd → libsecurity_apple_csp
→ libsecurity_filevault → mDNSResponder → Tokend → CF
```

**Output:** `puredarwin.roots/Roots/9J61pd1/<project>.root.tar.gz`

### Phase 2 — Assemble (packs roots into a bootable disk image)

`pd_setup` / `pd_setup_linux`:
1. Creates a zeroed raw disk image
2. Partitions with Apple Partition Map (APM) — **not GPT**
3. Formats the main partition as HFS+J
4. Unpacks binary roots listed in `pd_roots` + `pd_roots.extra`
5. Applies `PureDarwinSettings/` config files
6. Creates the `toor` user account (salted SHA-1 via `pd_injectuser`)
7. Installs the Chameleon bootloader to the MBR + boot partition
8. Runs `kextcache` to rebuild the kext cache
9. Converts the raw image to VMDK via `qemu-img`

**Output:** `puredarwin.vmwarevm` (VMware bundle), `.vmdk`, or `.iso`

---

## Build Paths

### macOS (primary, fully tested)

```sh
sudo ./setup/pd_build_source             # compile all patched projects
sudo ./setup/pd_setup puredarwin.vmwarevm PureDarwin  # assemble image

# Or: rebuild a single project
sudo ./setup/pd_build_source kext_tools

# Or: skip compilation entirely, package the reference filesystem
sudo ./setup/pd_setup_prebuilt extracted/filesystem/PureDarwinXmas puredarwin.vmwarevm PureDarwin
```

**Requirements:** macOS Leopard/Snow Leopard, Xcode 3.x (GCC 4.2 + MacOSX10.5.sdk), DarwinBuild, root.

### Windows / Linux — Docker (experimental, recommended for non-macOS)

```sh
./docker-build.sh                        # full pipeline
./docker-build.sh --build-only           # compile only
./docker-build.sh --assemble-only        # assemble from existing roots
./docker-build.sh libelf launchd         # rebuild specific projects
```

On Windows, invoke from PowerShell or Git Bash with Docker Desktop running.

### Windows / Linux — Bare system (experimental)

```sh
# Compile
./setup/pd_build_linux                   # all projects
./setup/pd_build_linux libelf libdwarf   # specific projects
PD_BUILD_VERBOSE=1 ./setup/pd_build_linux  # full compiler output

# Assemble (requires root)
sudo ./setup/pd_setup_linux puredarwin.vmwarevm PureDarwin
sudo ./setup/pd_setup_linux puredarwin.iso PureDarwin
```

**Requirements:** clang ≥ 11, cctools-port (i386-apple-darwin9 target), Darwin 9 SDK at `$DARWIN_SDK` (default `/opt/darwin9-sdk`), parted, hfsprogs, genisoimage, qemu-utils, rsync, openssl.

---

## Important Files to Know

### `setup/pd_config`

The central configuration file sourced by all other setup scripts. Sets global variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DARWIN_RELEASE` | `"9"` | Darwin major version (9 or 10) |
| `ARCH` | `"i386"` | Target architecture |
| `PUREDARWIN_RELEASE` | `""` | Release flavour: `""` (full), `"nano"`, or `"bootstrap"` |
| `BINARYROOTS_LIST_FILE` | `pd_roots` | Which package list to use |
| `TEMPDIR` | `pd_tmp` | Scratch directory |
| `DESTDIR` | `pd_tmp/Packages_D9_i386` | Where thinned binaryroots are staged |
| `BINVERSION` | `(10C540 … 9A581)` | Ordered list of build versions to search |
| `ADD_CHAMELEON` | `"y"` | Include the Chameleon bootloader |
| `ADD_VOODOO_XNU` | `"y"` | Include the Voodoo-patched XNU kernel |
| `ADD_PUREFOUNDATION` | `"y"` | Include PureFoundation.framework |
| `ADD_X` | `"y"` | Include X11 + Fluxbox |
| `ADD_WMAKER` | `"n"` | Include WindowMaker (alternative WM) |
| `ADD_VMWARE` | `"y"` | Include VMware KEXTs |
| `ADD_MACFUSE` | `"y"` | Include MacFUSE |
| `ADD_DEBUG` | `"y"` | Verbose launchd + persistent syslog |
| `ADD_BASH` | `"y"` | Make bash the default shell |
| `ADD_DEFAULT_USER` | `"y"` | Create the `toor` user (password: `toor`) |
| `ADD_DEVELOPER` | `"y"` | Keep developer headers and libraries |
| `ADD_DTRACE` | `"y"` | Include DTrace |
| `ADD_LAUNCHD` | `"y"` | Use launchd as PID 1 |
| `ADD_LAUNCHD_GETTY` | `"y"` | Launch login prompt via launchd |
| `PREBUILT_FILESYSTEM` | `""` | If set, copy this directory instead of unpacking roots |

The `nano` and `bootstrap` release flavours override these defaults further down in `pd_config`.

### `setup/pd_roots`

A plain-text list (one package name per line) of all ~160 binary roots to unpack when assembling a full PureDarwin image. `pd_setup` reads this file and unpacks each `.root.tar.gz` it finds in `puredarwin.roots/Roots/`. The search order follows `BINVERSION`.

### `setup/pd_build_linux`

Cross-compilation driver. Key environment variables it respects:

| Variable | Default | Description |
|----------|---------|-------------|
| `DARWIN_TARGET` | `i386-apple-darwin9` | Clang target triple |
| `DARWIN_SDK` | `/opt/darwin9-sdk` | Path to Darwin 9 SDK headers |
| `TOOLCHAIN_PREFIX` | `/opt/cctools/bin` | Path to cctools-port binaries |
| `DARWIN_CC` | `darwin9-cc` or `clang` | C compiler (wrapper preferred) |
| `DARWIN_CXX` | `darwin9-c++` or `clang++` | C++ compiler |
| `PD_BUILD_VERBOSE` | `0` | Set to `1` for full compiler output |

Inside Docker, `darwin9-cc` and `darwin9-c++` wrapper scripts embed `-target`/`--sysroot` automatically. Outside Docker, raw `clang` is used with `TARGET_CFLAGS`.

### `plists/9J61pd1.plist`

The DarwinBuild project file that describes every Darwin 9.0 / 10.5.7 package, its version, patches, and dependencies. This is what `darwinbuild` uses on macOS.

---

## Source Changes

All patches are applied in-tree — there are no separate `.patch` files to apply. The `source/` directory contains ready-to-build Darwin source trees.

Key patch categories across the ~19 projects:

- **Objective-C header inclusion fixes** — e.g., adding `#include <objc/objc.h>` to IOHIDFamily C++ files that call ObjC APIs
- **macOS-internal API removal** — e.g., removing `CFStringTransform` (not in PureFoundation), removing `AppleTalk` framework dependency from launchd, removing Quarantine API from older launchd
- **Build system fixes** — Xcode `.pbxproj` adjustments for open-source build contexts (no Apple-private frameworks in search paths)
- **Include path canonicalisation** — e.g., `malloc.h` → `sys/malloc.h` for libdwarf on Darwin
- **Stub/comment-out** — assertions or size checks that fail without the full Apple runtime

Seven projects listed in `9J61pd1.plist` as having patches are missing their source changes (CFNetwork, JavaScriptCore, Libc, efax, emacs, libsecurity_ldap_dl, security_dotmac_tp). Pre-built roots for all seven are committed and used directly.

---

## Binary Roots System

Binary roots are `.root.tar.gz` archives (and some `.tbz2` for MacPorts packages) that contain a complete `DSTROOT` tree — the files exactly as they should be placed on the target filesystem. Unpacking one into the image root typically adds files to `/usr`, `/System/Library`, `/Library`, etc.

**Root search logic** in `pd_setup_linux`: all subdirectories of `puredarwin.roots/Roots/` are searched recursively; the newest match wins. Both `.tar.gz` and `.tar.bz2` extensions are tried.

**Root search logic** in `pd_setup` (macOS): follows `BINVERSION` order to find the most recent version of a root, checking local dirs first then the defunct HTTP paths (which are now dead — all roots must be local).

**Notable pre-built roots:**

| Root | Location | Purpose |
|------|----------|---------|
| `Voodoo_kernel` | `Roots/pd/` | XNU 1228 patched for non-Apple hardware |
| `VoodooPS2Controller` | `Roots/pd/` | PS/2 keyboard + mouse IOKit KEXT |
| `Chameleon-2.0-RC4-r684-bin` | `Roots/pd/` | Stage 1/2 bootloader |
| `PureFoundation` | `Roots/pd/` | Open reimplementation of Foundation.framework |
| `configd` + `configd_plugins` | `Roots/pd/` | System Configuration daemon |
| `NotApple80211` | `Roots/pd/` | 802.11 stub KEXT (prevents kextd crash) |
| `MacFUSE` | `Roots/pd/` | FUSE kernel extension |
| `xnu` | `Roots/pd/` | XNU kernel headers (used to assemble the SDK) |
| `CarbonHeaders` | `Roots/9J61pd1/` | Carbon framework headers |
| XFree86 + 25 X11 packages | `Roots/X/` | X.Org server, Fluxbox, xterm, fonts |
| `boot` | `Roots/9F33pd1/` | DFE boot-132 bootloader (pre-built; source lost) |
| `tcl-8.5.6` | `Roots/mp/` | MacPorts Tcl runtime |

---

## Disk and Boot Architecture

- **Partition table:** Apple Partition Map (APM), **not GPT**. Required by Chameleon `boot0`.
- **Filesystem:** HFS+ with journaling (HFS+J). Configurable via `ADD_HFS_JOURNAL`.
- **Bootloader chain:**
  - `boot0` → MBR (stage 0, 446 bytes)
  - `boot1h` → HFS+ partition boot record (stage 1)
  - `boot` → `/boot` on the HFS+ volume (stage 2, full Chameleon binary)
- **Kernel variants:**
  - `mach_kernel` — vanilla XNU 1228 (official Apple release)
  - `mach_kernel.voodoo` — XNU with Voodoo patches (removes EFI/ACPI Apple assumptions); this is what the VM boots
  - `mach_kernel.ctfsys` — DTrace CTF type information

---

## Key Technical Components

### PureFoundation
`Foundation.framework` in standard Darwin depends on closed-source Apple APIs. `PureFoundation.framework` reimplements the Objective-C class hierarchy (NSObject, NSString, NSArray, NSDictionary, etc.) from scratch for non-Apple systems. It is injected via `DYLD_FRAMEWORK_PATH` at runtime.

### Docker / Cross-Compilation Toolchain
The `Dockerfile` is multi-stage:
1. **Stage `cctools-builder`:** clones and builds [tpoechtrager/cctools-port](https://github.com/tpoechtrager/cctools-port), producing `i386-apple-darwin9-{ld,ar,ranlib,strip,lipo,otool,nm}` in `/opt/cctools/bin/`.
2. **Stage `sdk-builder`:** assembles the Darwin 9 SDK at `/opt/darwin9-sdk` by extracting headers from `xnu.root.tar.gz` (mach/, sys/, libkern/, IOKit/) and `objc4.root.tar.gz` (objc/).
3. **Final stage:** installs the toolchain and runs `pd_build_linux` + `pd_setup_linux`.

Cross-compilation limitations:
- Objective-C-heavy projects (CF, configd, IOKitUser) require a `libSystem.B.dylib` stub that is not yet complete; those produce placeholder roots.
- The assembled image boots via the pre-built roots; cross-compiled roots supplement them.

### launchd
Two versions are committed:
- `launchd-258.18` (default, 9J61pd1 target) — removes AppleTalk framework dependency
- `launchd-258.1` (9F33pd1 target) — removes Quarantine API dependency

### DTrace
Requires three components: `dtrace` CLI tool, `libdtrace.dylib`, and `mach_kernel.ctfsys`. Depends on `libelf` and `libdwarf` (committed under `source/third_party/`).

---

## Coding and Scripting Conventions

### Shell Scripts
- All scripts use `#!/bin/sh` — **POSIX sh only**, not bash. Do not use bash-specific syntax such as `[[ ]]`, `$(( ))` with bash extensions, `local` (except where already used), or arrays in `setup/` scripts.
  - **Exception:** `pd_config` uses `bash` arrays (`BINVERSION=(...)`); it is sourced by scripts that do run under bash.
- Variable names in `pd_config` follow the pattern `ADD_FEATURE="y"` or `"n"`. Feature checks are done as `if [ "$ADD_FOO" = "y" ]`.
- License headers must follow the established `@LICENSE_HEADER_START@` / `@LICENSE_HEADER_END@` pattern for PureDarwin files.
- Changelog entries go at the top of each script file in `# YYYYMMDD - description - author` format.
- `set -e` is used in `pd_build_linux` and `docker-build.sh`; other setup scripts do not always set it — match the existing style.
- Scripts in `scripts/` are intended to run **inside the PureDarwin VM**, not on the host. Scripts in `setup/` run on the **build host**.

### Objective-C (projects/pd_xkp/)
- Written for GCC 4.2 / Objective-C 2.0 on Darwin 9 / macOS 10.5.
- ARC is **not** available. Manual retain/release (`retain`, `release`, `autorelease`) is required.
- Build with: `make -C projects/pd_xkp`

### Binary Roots
- A new binary root is a tar archive packed as: `tar czpf <name>.root.tar.gz -C $DSTROOT .`
- The `-p` flag (preserve permissions) is mandatory. Missing it causes permission errors on extract.
- Roots go into `puredarwin.roots/Roots/9J61pd1/` for newly compiled pd1 targets.

### Darwin SDK Assembly
When adding new projects that need cross-compilation, the SDK at `$DARWIN_SDK` must have the required headers. Assemble from committed roots:
```sh
tar xzf puredarwin.roots/Roots/pd/xnu.root.tar.gz -C "$DARWIN_SDK" --wildcards './usr/include/*'
tar xzf puredarwin.roots/Roots/9F33pd1/objc4.root.tar.gz -C "$DARWIN_SDK" --wildcards './usr/include/objc/*'
```

### Adding a New Patched Package
1. Add the source tree under `source/apple/<project>/` (or `source/third_party/`) with patches applied in-tree.
2. Add a `build_<project>()` function in `setup/pd_build_linux` following the `build_autoconf` or `build_c_files` pattern.
3. Add the project name to the `PROJECTS` list in `pd_build_linux` in dependency order.
4. Add a corresponding `darwinbuild`-compatible entry in `pd_build_source` for the macOS path.
5. If the package should be included in the full image, add its name to `setup/pd_roots` or `setup/pd_roots.extra`.

---

## Known Limitations

| Area | Limitation |
|------|-----------|
| macOS build host | Only tested on macOS Leopard/Snow Leopard; later macOS requires manually installing MacOSX10.5.sdk |
| Cross-compilation | ObjC-heavy projects (CF, configd, IOKitUser) produce placeholder roots; full compilation requires the full `libSystem` stub |
| boot-132 source | DFE boot-132 source is permanently lost (was on puredarwin.googlecode.com); pre-built root is used |
| Missing patches | 7 projects in `9J61pd1.plist` reference patches that were never recorded; pre-built roots are substituted |
| Network | DHCP is unreliable in VMware without the correct NIC driver; `vmxnet` is used in the generated `.vmx` |
| WSL1 | Loop devices are not supported; **WSL2 is required** |
| Userland age | All userland dates to late 2008 — intentional for the current phase |

---

## Future Goals (in priority order)

1. **Clang support in DarwinBuild** — GCC 4.2 is the current toolchain; enabling Clang (Xcode 3.2+) unlocks newer code
2. **Update launchd** — Port to Darwin 9L30 / 10.5.8 release; better error handling
3. **Richer Foundation replacement** — PureFoundation covers common classes but misses large APIs; GNUstep or Cocotron is a candidate
4. **Working network stack** — Fix DHCP reliability, `configd` assertion failures, `/etc/resolv.conf` generation
5. **Package manager** — `pd_install`/`pd_remove` backed by the `.root.tar.gz` format using `PureDarwinPackageDatabase`
6. **CI / GitHub Actions** — macOS runner for full builds; Linux runner to validate cross-compilation + assembly on every push
7. **AArch64 / Apple Silicon** — Darwin 22+ XNU is available for arm64; very speculative, long-term

---

## Licensing

| Component | License |
|-----------|---------|
| Apple open-source (`source/`, `puredarwin.roots/Roots/`) | Apple Public Source License 2.0 (`APPLE_LICENSE.txt`) |
| Apple binary drivers + KEXTs | Apple Binary Driver EULA (`APPLE_DRIVER_LICENSE.txt`) |
| PureDarwin scripts + config (`setup/pd_*`, `scripts/pd_*`, `projects/PureDarwinSettings/`) | BSD 2-Clause (`PUREDARWIN_LICENSE.txt`) |
| Chameleon bootloader | APSL 2.0 (derived from Apple `boot-132`) |
| XFree86 / X.Org (`Roots/X/`) | MIT X11 License |
| MacPorts packages (`Roots/mp/`) | Various open-source licenses per package |
| hexley9k additions (README, `pd_build_linux`, `pd_setup_linux`, `Dockerfile`, `docker-build.sh`) | BSD 2-Clause |

All new code added to this repository should be under BSD 2-Clause unless it is a modification to an existing file, in which case it inherits that file's license.
