# RESUME (post-compaction) — PureDarwin Xmas from-source, Apple Silicon

## Where we are RIGHT NOW (the live thread)
**MALLOC SOLVED 2026-06-10.** From-source `libSystem.B.dylib` now has WORKING malloc/free/stdio on real
Darwin 9 (f4malloc rc=0; f4printf2 prints PRINTF_OK/SNPRINTF_OK/FWRITE_OK/ALL_STDIO_OK). Root cause was NOT
malloc — two systemic i386 syscall-stub bugs: (1) **missing success-path `ret`**: `RSYSCALL` macro
(`Libc/i386/sys/SYS.h:115`) + inline stubs in `libsystem_stubs.S` ended at label `2:` with no `ret`, so
every *successful* syscall fell through to the next stub (write only "worked" because callers ignore its
return). FIX: RSYSCALL appends `ret`+`END`; inline stubs got `2:\tret`; regenerated `libc-obj/sys/*.o`.
(2) **broken `$UNIX2003` aliases**: `.set _write$UNIX2003,_write` collapses for cross-object externals →
ALL `$UNIX2003` syms landed on `_accept`; SDK headers route normal C (incl malloc.o) through `$UNIX2003`,
so write→accept→crash. FIX: replaced ALL `.set` aliases with real jmp trampolines (`_X$UNIX2003: jmp _X`).
Verified working now: BSD syscalls, mmap, vm_protect, malloc/free, printf/stdio, clean signal delivery.

**RELINK + IMAGE — DONE (tasks #3, #4 COMPLETE).** from-source libSystem = **3258 exports, NOUNDEFS**, and
**ALL 178 from-source userland tools are symbol-compatible** with it (`foundation/_analyze.sh` →
SATISFIED=178/178). Filled the 34 missing libc fns: freopen/getopt/waitpid/system/daemon/opendir/rewinddir/
setpgrp via jmp trampolines to existing `$UNIX2003`/`$1050` impls; lchmod/lchflags from src/Libc/emulated;
`__moddi3` + networking(inet_pton real, rest stub)/utmpx/copyfile stubs in missing_syms.c. (Networking/utmpx/
copyfile are STUBS that link but return errors at runtime — full source trees absent; note as debt.)
Regression-verified malloc+stdio still rc=0 with the 3258-export libSystem.
**ASSEMBLED IMAGE:** `images/puredarwin-100fromsrc.raw` — a bootable image with a self-contained
100%-from-source userland at **/fromsrc** (from-source libSystem.B.dylib + 178 from-source tools). Verified
single-user (logs/f4/assemble/out.png): `DYLD_LIBRARY_PATH=/fromsrc/usr/lib /fromsrc/bin/<tool>` runs real
programs against the from-source libSystem — uname→"Darwin 9.5.0 i386", cat /etc/group|wc -l→76, echo OK.
Rebuild/verify the image: `bash assemble-fromsrc-image.sh`. Analysis harness: `foundation/_analyze.sh`
(+`foundation/_toolcheck/` tool binaries, `_analysis/*.txt`). Probes: f4malloc/f4printf2 (malloc+stdio).
NOT done (open, lower priority): full system libSystem swap (replace /usr/lib for launchd/desktop) — risky,
system daemons need far more symbols + the network/utmpx/copyfile stubs would break those daemons.

F4 probes in hexley9k/: f4min f4malloc f4mm2 f4z f4printf2 f4mem f4env f4tsd f4mach etc (link vs
foundation/lib-system/libSystem.B.dylib; run via DYLD_LIBRARY_PATH=/tmp on throwaway images/f4.raw).
Boot harness: `~/puredarwin/f4run.sh <label>` (single-user, runs payload/cd/go.sh, screendump
logs/f4/<label>/out.png). Rebuild libSystem:
docker run --rm -v "$PWD:/repo" puredarwin-builder sh -c "cd /repo/foundation && sh build-libsystem.sh".


## Key paths / commands
- Working dir `~/puredarwin/`; build repo `~/puredarwin/hexley9k/`.
- GUI (DONE, verified): `./run-gui.sh` — patched `qemu-src/build/qemu-system-i386`, `-vga vmware`,
  normal flags. Mouse fix candidate `-machine pc,vmport=off` (task #7, unverified).
- Build env: colima+docker running; image `puredarwin-builder`; `darwin9-cc` = clang i386-apple-darwin9.
  SDK overlay `hexley9k/puredarwin.roots/darwin9-sdk-libs/usr/include` (mach/ now clean Darwin-9 set).
- Re-link libSystem: `cd hexley9k && docker run --rm -v "$PWD:/repo" puredarwin-builder sh -c 'cd /repo/foundation && sh build-libsystem.sh'` → `foundation/lib-system/libSystem.B.dylib`.
- F4 runtime test harness: stage `f4min`(write-only)/`f4test`(printf+malloc)/`libSystem.B.dylib` into
  `payload/cd/` + a go.sh that runs `DYLD_LIBRARY_PATH=/tmp /tmp/f4...`; boot a throwaway raw
  (`qemu-img convert vmdk->images/f4.raw`, byte-patch offset 818458375 = `-v -s cpus=1`) single-user
  via CD channel; `screendump logs/f4/*.png`. (f4min.c/f4test.c are in hexley9k/.)

## DONE (this session)
- GUI on Apple Silicon (WindowMaker), verified+reproduced. Fix = qemu vmware_vga FIFO caps + topology.
- 177 userland tools from source, runtime-verified, integrated → `images/puredarwin-fromsrc.raw` boots to desktop.
- 12/12 libSystem component libs in `foundation/lib-system/*.a` (libc.a = 1729 syms; 763 libc objs in
  foundation/libc-obj/). F2b syscalls via RSYSCALL/sysenter. F3 umbrella linked (NOUNDEFS, 2837 syms;
  ~84 obscure stubs in missing_syms.c; core fns genuine).

## CAVEATS / where bodies are buried
- libunc = stub (no source); libkvm partial; ~84 missing_syms.c stubs (obscure Mach/ASL).
- mach SDK fully clean (xnu-1228.7.58 static + mig-generated, saved in foundation/mach-darwin9-gen/).
- Agents: tightly-scoped, FORBIDDEN to touch images/ qemu-src/ or boot QEMU (one earlier corrupted the
  GUI image — recovered from pristine vmdk). I do QEMU/F4 verification centrally.

## Full detail
`TRACK3-progress.md` (chronological ledger — read its last ~5 sections), `TRACK3-FOUNDATION-plan.md`,
`HANDOVER-track3-{libc,f3-umbrella,foundation-lib,userland,sdk,build}.md`. Memory file updated.
Tasks: #5 Track3 in_progress, #7 mouse pending.
