Copyright (c) 2007-2010 The PureDarwin Project.
All rights reserved.

@LICENSE_HEADER_START@

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@LICENSE_HEADER_END@

Updated on 20100125.

Preliminaries
=============

Before you start, make backups of all your data.
Do not use any production machines.
PLEASE DO NOT IGNORE THESE STEPS!

These instructions are only for technical persons anyway, so they are short.
Developers and testers, please provide feedback via the way you prefer. 

Installation
============

0. Check and edit the "pd_config" configuration file to reflect your needs.

1. Get binary roots and binary drivers with `pd_fetch'.

2. Thin them with `pd_thin'.
   
3. Then see the usage of `pd_setup':

   Set up a bootable PureDarwin system.

   Usage: pd_setup any_output_filename VolumeName

       * Install to physical disk
       pd_setup /Volumes/PureDarwin PureDarwin
       pd_setup /dev/diskX PureDarwin

       * Create an ISO 9660 image (.iso)
       pd_setup /tmp/puredarwin.iso PureDarwin

       * Create a ready-to-run VMware virtual machine (.vmwarevm)
       pd_setup puredarwin.vmwarevm PureDarwin

       * Create a ready-to-run VMware virtual disk (.vmdk)
       pd_setup puredarwin.vmdk PureDarwin

Note
====

Optionally, it is possible to override few variables present in "pd_config" 
by exporting them to the environment, allowing some combination.

By default, PUREDARWIN_RELEASE is set to "" (full release).

The flow below results in a bootstrap release able to deploy a full release:

PUREDARWIN_RELEASE="" ./pd_fetch
PUREDARWIN_RELEASE="" ./pd_thin
PUREDARWIN_RELEASE="bootstrap" ./pd_setup arg1 arg2

Building PureDarwin: full pipeline
====================================

The source trees in source/apple/ and source/third_party/ are already
present in the repository with all patches pre-applied.  There is NO
separate fetch or patch step — go straight to compilation.

─────────────────────────────────────────────────────────────────────
QUICK START (Windows / WSL2 / Linux — one command)
─────────────────────────────────────────────────────────────────────

  Prerequisites: Docker Desktop (Windows/Mac) or Docker Engine (Linux)

    ./docker-build.sh

  This builds the cross-compilation toolchain in a Docker container
  (cctools-port + clang + Darwin 9 SDK headers), compiles all Darwin
  projects in source/, and assembles a bootable VMware image.

  Output: puredarwin.vmwarevm

─────────────────────────────────────────────────────────────────────
STEP-BY-STEP
─────────────────────────────────────────────────────────────────────

Step A.  Build from source — Linux / WSL2 / Windows (Docker)
     Cross-compiles all Darwin projects in source/ using clang targeting
     i386-apple-darwin9 plus cctools-port for the Mach-O linker.

     Option 1 — Docker (recommended, sets up the full toolchain automatically):
       ./docker-build.sh                  # build + assemble in one step
       ./docker-build.sh --build-only     # compile only
       ./docker-build.sh libelf launchd   # build specific projects

     Option 2 — Bare Linux / WSL2 (install toolchain yourself):
       # 1. Install clang and build cctools-port:
       sudo apt-get install clang llvm lld make autoconf automake
       git clone https://github.com/tpoechtrager/cctools-port /opt/cctools-src
       cd /opt/cctools-src/cctools
       ./configure --target=i386-apple-darwin9 --prefix=/opt/cctools
       make -j$(nproc) && sudo make install
       export PATH=/opt/cctools/bin:$PATH
       # 2. Assemble the Darwin 9 SDK headers (see Dockerfile for details):
       export DARWIN_SDK=/opt/darwin9-sdk
       # 3. Run the build:
       ./setup/pd_build_linux

     Both options write compiled roots to puredarwin.roots/Roots/9J61pd1/.

Step A (alternate).  Build from source — macOS (DarwinBuild)
     Leopard (10.5) or Snow Leopard (10.6) with Xcode 3.x and DarwinBuild:
       git clone https://github.com/apple-oss-distributions/darwinbuild
       cd darwinbuild && sudo make install
       sudo ./setup/pd_build_source

     pd_build_source automatically delegates to pd_build_linux when run
     on Linux/WSL, so you can always use pd_build_source regardless of OS.

Step B.  Assemble the bootable disk image

     Linux / WSL2 / Windows:
       Required packages:
         sudo apt-get install parted hfsprogs genisoimage qemu-utils kpartx rsync
       Run:
         sudo ./setup/pd_setup_linux puredarwin.vmwarevm PureDarwin
         sudo ./setup/pd_setup_linux puredarwin.vmdk      PureDarwin
         sudo ./setup/pd_setup_linux puredarwin.iso       PureDarwin

     macOS:
         sudo ./setup/pd_setup puredarwin.vmwarevm PureDarwin

     pd_setup_linux automatically searches puredarwin.roots/Roots/ for
     pre-built roots and newly compiled roots (in 9J61pd1/) alike.

     Tool mapping (macOS → Linux):
       hdid -nomount  →  losetup -f --show
       pdisk (APM)    →  parted mklabel mac
       newfs_hfs      →  mkfs.hfsplus
       mount -t hfs   →  mount -t hfsplus
       gnutar         →  tar (GNU tar)
       ditto          →  rsync -aH
       mkisofs        →  genisoimage
       qemu-img (MO)  →  qemu-img (system)
       vsdbutil        →  mkfs.hfsplus ownership flag
       bless           →  boot1h + Chameleon (BIOS boot needs no bless)
       kextcache       →  touch Extensions/ (Darwin rebuilds on first boot)
       user creation   →  pure POSIX shell (openssl + sed; no chroot)

     WSL2 notes:
       • WSL1 does NOT support loop devices → use WSL2.
       • Add to %USERPROFILE%\.wslconfig:
           [wsl2]
           kernelCommandLine = vsyscall=emulate
       • Load the loop module if needed:  sudo modprobe loop

─────────────────────────────────────────────────────────────────────
SOURCE TREES IN THIS REPOSITORY
─────────────────────────────────────────────────────────────────────

  source/apple/
    at_cmds         bless           CF              configd
    dtrace          gnutar          IOAudioFamily   IOHIDFamily
    IOKitUser       iodbc           ipv6configuration  kext_tools
    launchd_258.1   launchd_258.18  libsecurity_apple_csp
    libsecurity_filevault            mDNSResponder   Tokend

  source/third_party/
    libdwarf-20081013               libelf-3

All patches from plists/9J61pd1.plist are already applied in-tree.

─────────────────────────────────────────────────────────────────────
PRE-BUILT BINARY ROOTS
─────────────────────────────────────────────────────────────────────

puredarwin.roots/Roots/ contains pre-built roots for projects whose
source is not in this repository (drivers, ICU, Libc, etc.).  These
are used automatically by both pd_setup and pd_setup_linux.

Resources
=========

http://opensource.apple.com
https://github.com/apple-oss-distributions          (Darwin source mirror)
https://github.com/apple-oss-distributions/darwinbuild
http://www.puredarwin.org
http://puredarwin.googlecode.com                    (archived; mostly dead)

#puredarwin on irc.freenode.net
contact at puredarwin.org

Additional Licensing Information
================================

IMPORTANT LICENSING INFORMATION:  The Apple-developed portions of the
Source Code and corresponding binary package folders are covered by the
Apple Public Source License that can be found in the file /APPLE_LICENSE.txt.

The Apple binary drivers and kernel extension files are covered by a separate
Apple Binary Driver Software License Agreement that can be found in the file
/APPLE_DRIVER_LICENSE.txt.

The PureDarwin "work" is covered by the BSD License that can be found in the
file /PUREDARWIN_LICENSE.txt.

Other portions of Darwin may be covered by third party licenses.  Please
read these licenses carefully before using any of this software, as your use
of this software signifies that you have read the licenses and that you
accept and agree to their respective terms. 
Please see the respective projects for more information.

Please read all these licenses carefully before using any of this software, 
as your use of this software signifies that you have read the licenses and 
that you accept and agree to their respective terms.
