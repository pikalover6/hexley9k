# PureDarwin Xmas — MASTER STATUS & HANDOVER (2026-06-10)

> One document to orient a fresh agent on the whole effort: the goals, every track, exactly how close
> we are to "100% from source," and a detailed brief to re-attack the one remaining blocker (malloc).
> Read this first, then `RESUME-NOTES.md` (terse live state) and `TRACK3-progress.md` (chronological ledger).

---

## 1. THE GOALS (what the user actually asked for)

**Original request:** Compile and run **"PureDarwin Xmas"** — the Christmas-2008 community proof-of-concept
of **Darwin 9.5.0** (i386, Voodoo XNU; the open-source core of Mac OS X 10.5 Leopard) — **with its GUI**
(XFree86 4.7 / XDarwin → WindowMaker desktop) on the user's **Apple Silicon Mac** (M-series, macOS Sonoma,
Darwin 23.5.0, ARM64).

**Two clarified requirements:**
1. It must run **on this Apple Silicon Mac**, and ideally as a portable **x86 VM that boots on any x86 host**.
2. Delivery order: **GUI from the recovered image first, THEN a genuine from-source build.**

**The multi-track plan** (see `~/.claude/plans/lovely-puzzling-floyd.md` for the full original plan):
- **Track 0** — re-baseline the known-good shell boot under QEMU. ✅ DONE
- **Track 1** — GUI on this Apple Silicon Mac via emulation. ✅ DONE
- **Track 2** — portable x86 VM that boots to desktop on any x86 host. ✅ DONE
- **Track 3** — genuine **100% from-source build** (the research track, milestone-gated). 🚧 IN PROGRESS

**THE FINAL GOAL (Track 3):** Make `hexley9k/`'s "builds from source" claim *real* — build Apple's Darwin 9
sources (libSystem + userland) from scratch with a cross-toolchain, assemble a bootable image that contains
**no binaries copied from the recovered image**, and have it boot to a shell and then the desktop.

---

## 2. HOW CLOSE ARE WE TO "100% FROM SOURCE"? (the headline)

**Very close on the hardest part, blocked on one bug.** The crux of "100% from source" is `libSystem.B.dylib`
(the umbrella every Darwin program links). We have **built it entirely from Apple Darwin-9 source** and it
**links (NOUNDEFS, 3203 exports) and LOADS on real Darwin 9**. Its major subsystems are **verified working
on the actual OS** (not just "it compiled"):

| Subsystem | Status | Evidence |
|---|---|---|
| BSD syscalls (write/read/open/mmap…) | ✅ WORKS | `f4min`/`f4mm2` — mmap returns + region writable |
| Mach userland (vm_allocate/vm_protect/mach_msg/traps) | ✅ WORKS | `f4mach` → `VM_ALLOC_OK`; vm_protect in malloc path OK |
| Commpage (memcpy/memset/bzero/atomic/spinlock) | ✅ WORKS | `f4mem`/`f4atomic`/`f4spin` all OK |
| libc init / environ / getenv | ✅ WORKS | `f4env` returns real `PATH=/usr/bin:/bin:…` |
| pthread (`pthread_self`/`%gs` TSD/`pthread_init`) | ✅ WORKS | `f4tsd` → valid pointer |
| **malloc / free** | ✅ **WORKS (SOLVED 2026-06-10)** | `f4malloc` rc=0: `MALLOC_RET_NONNULL`/`WRITE_OK`/`FREE_OK` |
| **stdio (printf/snprintf/fputs/fwrite/fflush)** | ✅ WORKS | `f4printf2` → PRINTF_OK/SNPRINTF_OK/FWRITE_OK/ALL_STDIO_OK rc=0 |
| signal delivery (`_sigtramp`) | ✅ WORKS | clean "Segmentation fault" → shell (no more hang) |

**THE MALLOC BLOCKER IS SOLVED.** It was NEVER malloc — it was two systemic bugs in the from-source i386
syscall layer (see §6, now a post-mortem): (1) every syscall stub was **missing its success-path `ret`** and
fell through into the next stub; (2) all **`$UNIX2003` aliases** were broken (`.set` to cross-object externals
collapsed them onto `_accept`), so the SDK headers routed normal C — incl. malloc.o's `write` — to the wrong
function. Fixes: `ret` added to the `RSYSCALL` macro + inline stubs (regenerated `libc-obj/sys/*.o`); all
`.set` aliases replaced with real `jmp` trampolines. From-source libSystem = **3218 exports, NOUNDEFS**, with
working syscalls/mmap/malloc/stdio/signals on real Darwin 9.

**Remaining path to a 100%-from-source bootable image:** of the 178 from-source userland tools, **120 are
already fully symbol-compatible** with the from-source libSystem; 58 need ~34 more libc functions
(`freopen`/`getopt`/`waitpid`/`daemon`/`system` + a networking/utmpx/copyfile tail) that were never compiled
into libc-obj — being filled in. Then: stage from-source libSystem + tools into the image and boot-verify.

**Rough completeness estimate:** GUI/portability tracks 100% done. From-source: userland ✅, all 12 libSystem
component libs ✅, libSystem.B.dylib links+loads+~85% of subsystems verified ✅, malloc + final
image-from-source-libSystem assembly ❌. Call it ~90% of the foundation, with malloc as the gate.

---

## 3. WHAT IS DONE (with how to reproduce / verify)

### Track 1 — GUI on Apple Silicon ✅
- `~/puredarwin/run-gui.sh` boots the recovered image to the **WindowMaker desktop** under a **patched QEMU**.
- The fix: `~/puredarwin/qemu-src/hw/display/vmware_vga.c` (+169 lines: SVGA FIFO capability bits +
  display-topology registers). Binary at `qemu-src/build/qemu-system-i386`. Rebuild:
  `ninja -C qemu-src/build qemu-system-i386`.
- Press Enter at the Chameleon prompt; ~110s to desktop. (Mouse doesn't work yet — task #7, candidate fix
  `-machine pc,vmport=off`, unverified.)
- The "bug" that requires the patched QEMU is a **QEMU vmware-svga incompleteness, NOT a PureDarwin bug** —
  on real VMware the stock image boots to desktop in ~10s.

### Track 2 — Portable x86 VM ✅
- `~/puredarwin/dist/` — VMware bundle + README + a QEMU-on-x86 recipe (boots to desktop on any x86 host).

### Track 3 / F0 — From-source userland ✅
- **177 userland tools** built from Apple Darwin-9 source (text_cmds, file_cmds, shell_cmds, etc.),
  runtime-verified on Darwin 9, integrated into `~/puredarwin/images/puredarwin-fromsrc.raw` which **boots
  to the WindowMaker desktop**. Roots at `hexley9k/puredarwin.roots/Roots/9J61pd1/`.

### Track 3 / F1 — All 12 libSystem component libs from source ✅
In `hexley9k/foundation/lib-system/`: `libc.a` (1729 text syms, 763 objects) + `libm libinfo
libcommonCrypto libdyldapis libnotify libmacho liblaunch libkeymgr libstreams libkvm libunc`.
- Syscall stubs generated via Libc's RSYSCALL mechanism (`SYSCALL-LIST` + per-syscall `.S` → sysenter).
- Caveats: `libunc` is an honest no-op stub (Apple never published `unc.subproj`); `libkvm` partial
  (kvm_file/kvm_proc need kernel structs).

### Track 3 / F2-F3 — From-source libSystem.B.dylib ✅ (links+loads)
- `hexley9k/foundation/lib-system/libSystem.B.dylib` — NOUNDEFS, 3203 exports, **loads on Darwin 9**.
- Built by `hexley9k/foundation/build-libsystem.sh` (re-ars `libc.a` from `libc-obj/**/*.o` excluding a few
  dup/conflicting objects, then links the umbrella with raw `ld64 -all_load` over the 12 libs).
- The **real Mach userland** is xnu-1228.7.58 `libsyscall` (copied to `hexley9k/foundation/src/libsyscall`,
  built by `build-libsyscall.sh`): `mach_init.c`, `mach_msg.c`, `mach_traps.s`, + MIG-generated user stubs
  for mach_vm/vm_map/mach_port/task/thread_act/host/etc.
- The **libSystem initializer** is `hexley9k/foundation/src/libsyscall/mach/mach_init_libSystem_local.c`
  (a `__attribute__((constructor))` that calls `mach_init()` + `pthread_init()` + `__libc_init(&pv)` where
  `pv` is a `ProgramVars` built from the constructor's argc/argv/envp). This is what makes `mach_task_self_`,
  `environ`, and the main-thread pthread get set up at load.

---

## 4. THE ENVIRONMENT (paths, toolchain, commands a fresh agent needs)

- **Working dir** `~/puredarwin/`; **from-source build repo** `~/puredarwin/hexley9k/`.
- **Host**: Apple Silicon, macOS Sonoma. `colima` + `docker` provide an x86_64 Linux container image
  **`puredarwin-builder`** that holds the cross-toolchain: **`darwin9-cc`** = `clang -target
  i386-apple-darwin9 --sysroot /opt/darwin9-sdk` (compiles/links i386 Mach-O **natively, no x86 emulation**),
  plus `cctools-port` (`/opt/cctools/bin/i386-apple-darwin9-{ld,ar,nm,otool,ranlib,as}`). Run anything in it:
  `docker run --rm -v "$PWD:/repo" puredarwin-builder sh -c '...'` from `~/puredarwin/hexley9k`.
- **SDK overlay** `hexley9k/puredarwin.roots/darwin9-sdk-libs/usr/include` (Darwin-9 headers; the `mach/`
  subdir is a clean Darwin-9 set assembled from xnu-1228.7.58 static + MIG-generated headers).
- **Host MIG**: `/usr/bin/mig` works (`mig -arch i386 -cc clang -isysroot $(xcrun --show-sdk-path) -Iosfmk …`).
  Host `rpcgen` works too.
- **xnu source** at `/tmp/xnu` (sparse-checkout; has `osfmk/`, `bsd/`, `libsyscall/`). Libc at `/tmp/Libc`
  (Libc-498.1.7) — also copied into `hexley9k/foundation/src/Libc`.
- **Rebuild the from-source libSystem** (the inner loop):
  ```
  cd ~/puredarwin/hexley9k && docker run --rm -v "$PWD:/repo" puredarwin-builder \
    sh -c 'cd /repo/foundation && sh build-libsystem.sh'
  ```
  → `hexley9k/foundation/lib-system/libSystem.B.dylib`. (`build-libsyscall.sh` rebuilds the Mach userland
  objects first if you touched libsyscall.)

### The F4 runtime test harness (how to test the from-source libSystem on real Darwin 9)
Because the from-source dylib has `install_name /usr/lib/libSystem.B.dylib`, you load it at runtime via
**`DYLD_LIBRARY_PATH=/tmp`** so dyld picks **ours** from `/tmp` instead of the guest's system one. Pattern:
1. Compile a tiny test in docker: `darwin9-cc -nostdlib <crt1.10.5.o> test.o <…/libSystem.B.dylib> -o test`
   (crt1 at `puredarwin.roots/darwin9-sdk-libs/usr/lib/crt1.10.5.o`).
2. Stage `test` + `libSystem.B.dylib` into `~/puredarwin/payload/cd/` with a `go.sh` that does
   `cp /mnt/* /tmp; DYLD_LIBRARY_PATH=/tmp /tmp/test`.
3. Boot a **throwaway** raw image single-user and run it:
   - `qemu-img convert -O raw images/puredarwinxmas.vmdk images/f4.raw` (vmdk is the pristine source — NEVER edit it)
   - byte-patch the boot flags at raw offset **818458375** to `'-v -s cpus=1'` (single-user)
   - `hdiutil makehybrid -iso -joliet -o payload/payload.iso payload/cd`
   - boot `qemu-src/build/qemu-system-i386 -M pc -cpu Penryn -m 1024 -drive file=images/f4.raw,if=ide -cdrom
     payload/payload.iso -vga std -display none -monitor telnet:127.0.0.1:4455,server,nowait -no-reboot -boot c`
   - at the Chameleon prompt: monitor `sendkey ret`; wait ~25s for single-user `:/ root#`
   - inject keystrokes via `bash type.sh "/sbin/mount -uw /; mkdir -p /mnt; /sbin/mount_cd9660 /dev/disk1s0
     /mnt; sh /mnt/go.sh" --enter` (type.sh talks to the QEMU monitor on telnet 127.0.0.1:4455)
   - `screendump $PWD/logs/f4/out.png -f png`; `Read` the PNG to see the output.
- **CRITICAL: test output must go to fd 1 (stdout).** fd 2 (stderr) does NOT appear on this console — a whole
  debugging detour was wasted on stderr breadcrumbs. Use `write(1, …)`.
- Existing probes in `hexley9k/`: `f4min`(write-only) `f4mem`(commpage) `f4env`(getenv) `f4tsd`(pthread_self)
  `f4atomic`/`f4spin`/`f4mach`(Mach) `f4malloc`/`f4test`(malloc) `f4sig`(SIGBUS handler — note: the handler
  hangs, likely `_sigtramp` is also broken). Their `.c` sources are in `hexley9k/`.

---

## 5. CAVEATS / TECHNICAL DEBT (things that are stubbed or hacked, to revisit for true 100%)
- **~84 stubs** remain in `hexley9k/foundation/src/Libc/gen/missing_syms.c` (obscure ASL/`asl_*`,
  `_vprocmgr_*`, `_res_*`, `_old_*` legacy DB iterators, fenv `fe*`, etc.). The Mach stubs were already
  REPLACED with real libsyscall; the pthread-internal stubs (`__pthread_getspecific/_mutex_*`) are still
  present but malloc compiled with `-Os` uses the inline `%gs` TSD accessor, not these (so they're likely
  not malloc's problem — but verify).
- The final link uses `-weak_library /opt/darwin9-sdk/usr/lib/libSystem.B.dylib` to satisfy the cctools
  linker's platform check (it does NOT pull symbols — `-all_load` of our libs wins — but it's a smell).
- `libunc` = no-op stub; `libkvm` partial; `_sigtramp` (signal delivery) appears broken (f4sig hangs).
- The from-source userland tools (177) currently link the **prebuilt** libSystem; for true 100% they must be
  relinked against the from-source `libSystem.B.dylib` once malloc works.

---

## 6. THE MALLOC BLOCKER — ✅ SOLVED 2026-06-10 (post-mortem; brief below is OBSOLETE)

> **RESOLUTION:** It was never malloc. Two systemic from-source i386 syscall-stub bugs:
> 1. **Missing success-path `ret`** — the `RSYSCALL` macro (`Libc/i386/sys/SYS.h`) and the inline `__`/`___`
>    stubs in `libsystem_stubs.S` ended at label `2:` with no `ret`, so every *successful* syscall fell
>    through into the next stub. `write` only "worked" because callers ignore its return value; `mmap`
>    succeeded then fell into a chain of garbage syscalls → hang/SIGBUS. Fix: append `ret`+`END` to
>    `RSYSCALL`; add `2:\tret` to the inline stubs; regenerate `libc-obj/sys/*.o`.
> 2. **Broken `$UNIX2003` aliases** — `.set _write$UNIX2003,_write` silently collapses for cross-object
>    externals (all landed on `_accept`). SDK headers route normal C (incl. malloc.o's `write`) through the
>    `$UNIX2003` variants → `write`→`accept`→crash. Fix: replace ALL `.set` aliases with real `jmp`
>    trampolines (`_X$UNIX2003: jmp _X`).
> **The decisive technique was NOT a debugger** — it was `otool -arch i386 -tV` disassembly (diff vs prebuilt
> `_malloc`/`_write`; spotted `write` calling `_accept$UNIX2003`) + breadcrumb probes with NO stack arrays
> (f4mm2/f4z, to avoid the SSP confounder). Everything below is the pre-solution guesswork — ignore it.

---

**Symptom:** A program linked against the from-source libSystem prints fine via `write()`, then `malloc(64)`
**SIGBUSes**. Breadcrumb tracing (a `write(1,"…")` as the literal first statement of the public `malloc()`
in `foundation/src/Libc/gen/malloc.c:633`, and inside `_malloc_initialize`) proved **malloc's body is NEVER
entered** — not even the first statement runs. So the fault is in the **call into malloc / its prologue**,
before any malloc logic.

**DECISIVE CONTROL (run it first to anchor yourself):** the SAME `f4malloc` binary, on Darwin 9:
- against the **PREBUILT** system libSystem (no DYLD override): `MALLOC_RET_NONNULL`→`MALLOC_WRITE_OK`→
  `FREE_OK`, rc=0 — **works perfectly**.
- against **OUR** from-source libSystem (`DYLD_LIBRARY_PATH=/tmp`): SIGBUS, rc=138.
⇒ `f4malloc`, crt1, and the whole harness are **proven sound**; the bug is **100% in our from-source malloc
code**. (go.sh: run `/tmp/f4malloc` then `DYLD_LIBRARY_PATH=/tmp /tmp/f4malloc`; proof `logs/f4/control.png`.)

**What's already RULED OUT (don't repeat these):**
- Mach/`vm_allocate` — works (`VM_ALLOC_OK`). - Commpage memcpy/memset/atomic/spinlock — work.
- `getenv`/environ — works (returns real PATH after wiring `__libc_init` in the initializer).
- pthread `%gs`/`pthread_self`/`pthread_init` — work. - 64-bit div helpers — correct + unused by malloc.
- **Lazy binding** — `-Wl,-bind_at_load` (eager) still crashes. - **Prologue stack realign** —
  `-mstackrealign` on malloc.c+scalable_malloc.c did NOT help. - **Stack-protector** —
  `-fno-stack-protector` on malloc.c+scalable_malloc.c did NOT help (so it's NOT the SSP `%gs:0x14` canary).
- It's not that `malloc_zones` is NULL (it's a static `initial_malloc_zones[8]` array).
- f4malloc itself is sound (control above) — so NOT crt1, NOT the test, NOT the linkage.

**The mystery:** `write` (asm syscall stub) binds and calls fine; `malloc` (complex C) faults before its
first instruction, independent of binding mode and stack-realign. Other complex-ish C (`getenv`) works.

**Most promising next moves (in rough priority order):**
1. **Get a real debugger into the guest.** The screenshot/breadcrumb harness can't see *inside* the faulting
   instruction. Options: (a) is there a `gdb` in the recovered image? check `/usr/bin/gdb` — if so, run
   `DYLD_LIBRARY_PATH=/tmp gdb /tmp/f4malloc`, `run`, and on SIGBUS get `info registers`, `x/i $pc`, `bt`.
   (b) Use QEMU's own gdbstub (`-s -S`, connect a cross-gdb to `:1234`) and break at the malloc symbol
   address (resolve it from `nm` + the dyld load slide) to single-step the prologue and see which instruction
   and address faults. **This is the highest-value step — it turns guesswork into the exact faulting insn.**
2. **Compare our `_malloc` disassembly vs the prebuilt** `/opt/darwin9-sdk/usr/lib/libSystem.B.dylib`'s
   `_malloc` (`i386-apple-darwin9-otool -tV`). If our prologue has an instruction the prebuilt doesn't
   (an SSE `movaps`/`movdqa` spill, an `-mstackrealign` `and $-16,%esp`, a stack-protector `%gs:0x14` read
   with a different TSD offset than the kernel set up), that's the smoking gun. Note `_PTHREAD_TSD_OFFSET`
   is `0x60` vs `0x48` behind a `#if` in `pthread_machdep.h` — if the stack-protector/TSD canary read uses
   the wrong offset vs what the kernel's `thread_fast_set_cthread_self` established, `%gs:offset` could fault.
3. **Stack-protector canary.** Modern clang may emit `mov %gs:0x14,%eax` (the SSP canary) in malloc's
   prologue. If `%gs:0x14` isn't a valid/initialized TSD slot on this kernel, that read faults *before* the
   first statement — exactly matching the symptom. **Try compiling malloc.c (and ideally all of libc) with
   `-fno-stack-protector`** and re-test. (The F2c handover already used `-fno-stack-protector` for some libc;
   confirm malloc.o/scalable_malloc.o were built with it — the gen2 rebuild may NOT have.) This is cheap and
   a strong suspect given "crashes before first statement, reads %gs."
4. **`__guard_setup`.** `__libc_init` calls `__guard_setup()` (sets the SSP guard). Verify it actually runs
   and writes the canary to the right `%gs` slot; if it's a stub or writes the wrong offset, every
   stack-protected function faults on entry. (Cross-ref with #3 — they're the same root if SSP is the issue.)
5. If all else fails / for a pragmatic functional malloc: build a **minimal mmap-based allocator** and alias
   `malloc/free/calloc/realloc` to it (sidesteps scalable_malloc), to unblock the rest of the 100%-from-source
   image while scalable_malloc is debugged separately.

**WHERE TO START NOW (the cheap hypotheses are exhausted):** Go straight to **#1 — a real debugger** (#3
`-fno-stack-protector` is RULED OUT). The fastest path is QEMU's gdbstub: boot with `-s -S`, connect a
cross-gdb, resolve our `_malloc` runtime address (its dylib offset `nm` + the DYLD load slide; or just
break at the dyld_stub_binder return), and **single-step from the call site into our malloc** to capture the
exact faulting instruction + address + registers. That one observation will likely end the hunt — every
guess-level hypothesis (binding, align, SSP) is already eliminated, so you need to *see* the faulting insn.
Then compare it against the prebuilt `_malloc` prologue (which the control proves works) to spot the
divergent instruction. If the debugger path is too costly, fall back to #5 (drop-in mmap allocator) to
unblock the rest of the 100%-from-source image.

---

## 7. FRESH-AGENT QUICKSTART

1. Read this file, then `RESUME-NOTES.md`, then the last ~8 sections of `TRACK3-progress.md`.
2. Confirm the environment: `colima status` / `docker images | grep puredarwin-builder`. If docker is down,
   `colima start` (NOTHING else about colima).
3. Rebuild the current libSystem (command in §4) and reproduce the malloc crash with the F4 harness (§4) —
   establish the baseline before changing anything.
4. Attack malloc via §6 (do #3 `-fno-stack-protector` first — cheap; then #1 a real debugger).
5. **HARD CONSTRAINTS (a prior agent corrupted a protected asset):** NEVER edit `~/puredarwin/images/*.vmdk`
   (pristine, irreplaceable) — always work on a throwaway `images/f4.raw` regenerated from it. NEVER modify
   `~/puredarwin/qemu-src/` or rebuild the docker image or `colima stop`. Only QEMU-boot throwaway images.
   Keep all work under `~/puredarwin/hexley9k/foundation/**` and the SDK overlay. Test output to **fd 1**.
6. When malloc works: rebuild the 177 userland tools against the from-source libSystem, then drive the
   image-assembly path toward a 100%-from-source bootable image, and finally re-verify GUI on it.

---

## 8. KEY FILE INDEX
- `run-gui.sh`, `qemu-src/` (patched QEMU), `images/puredarwinxmas.vmdk` (PRISTINE), `images/puredarwin-fromsrc.raw`
- `hexley9k/foundation/lib-system/` (the 12 libs + `libSystem.B.dylib`), `…/libc-obj/**` (763+ libc objects)
- `hexley9k/foundation/src/{Libc,libsyscall,Libsystem,Libinfo,…}` (sources), `…/build-libsystem.sh`, `build-libsyscall.sh`
- `hexley9k/foundation/src/Libc/gen/{malloc.c,scalable_malloc.c,missing_syms.c}` (malloc + the stubs)
- `hexley9k/foundation/src/libsyscall/mach/mach_init_libSystem_local.c` (the initializer constructor)
- Handovers: `HANDOVER-track3-{libc,f3-umbrella,libsyscall,foundation-lib,userland,sdk,build}.md`
- `payload/` (CD channel), `type.sh` (QEMU keystroke injector), `logs/f4/*.png` (test screenshots)
- `TRACK3-progress.md` (full ledger), `RESUME-NOTES.md` (terse live state), `~/.claude/plans/lovely-puzzling-floyd.md` (original plan)
