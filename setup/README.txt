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

Building from Source (new pipeline)
====================================

The original pd_fetch / pd_thin steps download pre-compiled binary roots
from macosforge, which is long gone.  The repository now includes a
source-based pipeline that fetches Darwin open-source component source
directly from Apple's GitHub mirror and applies the PureDarwin patches.

Step A.  Fetch source (any OS, only needs git + tar)
     cd <repo-root>
     ./setup/pd_fetch_source

     This clones each patched Darwin project from apple-oss-distributions at
     the exact tagged version targeted by the patches, populating source/.
     Third-party sources (libdwarf, libelf) are extracted from the bundled
     archives in puredarwin.roots/Mirror/.

Step B.  Apply patches (any OS, only needs the patch(1) utility)
     ./setup/pd_patch_source

     Applies every patch from patches/ to the corresponding source tree.
     The --forward flag makes this idempotent; re-running is safe.

Step C.  Build (macOS only -- Leopard/Snow Leopard recommended)
     sudo ./setup/pd_build_source

     Uses DarwinBuild to compile each patched project and writes the
     resulting .root.tar.gz files to puredarwin.roots/Roots/9J61pd1/.
     DarwinBuild must be installed first:
       git clone https://github.com/apple-oss-distributions/darwinbuild
       cd darwinbuild && sudo make install

     You can build a single project:
       sudo ./setup/pd_build_source kext_tools

Step D.  Assemble the image (macOS only, same as before)
     sudo ./setup/pd_setup puredarwin.vmwarevm PureDarwin
     -- or, using the pre-extracted filesystem already in the repo:
     sudo ./setup/pd_setup_prebuilt ../extracted/filesystem/PureDarwinXmas \
          puredarwin.vmwarevm PureDarwin

Binary roots for projects that have no patches (and thus no source in this
repo) remain available as pre-built archives under puredarwin.roots/Roots/.
They are used automatically by pd_setup.

Source-to-patch mapping
-----------------------

The following Darwin projects are fetched and patched by Steps A-B:

  Project               Tag                    Patches
  at_cmds               at_cmds-54             at_cmds-54.p1.patch
  bless                 bless-63.2             bless-63.2.p1.patch
  CF                    CF-476.15              CF-476.15.*.p1.patch
  configd               configd-212.2          configd-212.2.*.p1.patch
  dtrace                dtrace-48              dtrace-48.*.p1.patch
  gnutar                gnutar-442.0.1         gnutar-442.0.1.p1.patch
  IOAudioFamily         IOAudioFamily-169.4.3  IOAudioFamily-169.4.3.p1.patch.0
  iodbc                 iodbc-34               iodbc-34.p1.patch
  IOHIDFamily           IOHIDFamily-258.3      IOHIDFamily.*.p1.patch
  IOKitUser             IOKitUser-388.2.1      IOKitUser-388.2.1.*.p1.patch
  ipv6configuration     ipv6configuration-27   ipv6configuration-27.p1.patch
  kext_tools            kext_tools-117         kext_tools-117.*.p1.patch
  launchd (9J61pd1)     launchd-258.18         launchd-258.18.*.p1.patch
  launchd (9F33pd1)     launchd-258.1          launchd-258.1.p1.patch
  libdwarf              20081013 (from Mirror)  libdwarf-20081013.*.p1.patch
  libsecurity_apple_csp libsecurity_apple_csp-35205
  libsecurity_filevault libsecurity_filevault-28631
  mDNSResponder         mDNSResponder-176.2    mDNSResponder-176.2.*.p1.patch
  Tokend                Tokend-35209           Tokend-35209.MacTypes.patch

  boot-132 (DFE): source is unavailable (Google Code, defunct).  The
  binary root at puredarwin.roots/Roots/9F33pd1/boot.root.tar.gz is used.

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
