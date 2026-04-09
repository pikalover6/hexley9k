# xbs-compatible wrapper Makefile for libdwarf
#

PROJECT=libdwarf

SHELL := /bin/sh

# Sane defaults, which are typically overridden on the command line.
SRCROOT=$(shell pwd)
OBJROOT=$(SRCROOT)
SYMROOT=$(OBJROOT)
DSTROOT=/usr/local

LIBDWARF_SRC=dwarf/libdwarf
DWARFDUMP_SRC=dwarf/dwarfdump

CFLAGS=-O2 -I$(SRCROOT)/$(LIBDWARF_SRC) $(RC_CFLAGS)
DD_CFLAGS=-O0 -I$(SRCROOT)/$(LIBDWARF_SRC) -pipe -no-cpp-precomp

# Configuration values we customize
#

PROJECT_NAME=libdwarf
OS_VER=20081013
LIBDWARF_TAR_GZ=libdwarf-$(OS_VER).tar.gz

LIBDWARF_BUILD_DIR=/libdwarf/dwarf-$(OS_VER)
USR_LOCAL=/usr/local
USR_BIN=/usr/bin
TEMP_DIR=/Temp_Dir

# Get our host arch
HOST_ARCH := $(shell arch)

# libdwarf config
#

LIBDWARF_CONFIG=
DWARFDUMP_CONFIG=

# These includes provide the proper paths to system utilities
#

include $(MAKEFILEPATH)/pb_makefiles/platform.make
include $(MAKEFILEPATH)/pb_makefiles/commands-$(OS).make

default:: make_libdwarf make_dwarfdump

install :: make_libdwarf_install make_dwarfdump_install

clean :
	$(SILENT) ($(CD) "$(SRCROOT)/$(LIBDWARF_SRC)" && make clean)
	$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && make clean)

installhdrs :
	$(SILENT) $(ECHO) "----- Make Install headers -----"
	$(SILENT) $(CP) "$(SRCROOT)/$(LIBDWARF_SRC)/dwarf.h" "$(DSTROOT)/include"
	$(SILENT) $(CP) "$(SRCROOT)/$(LIBDWARF_SRC)/libdwarf.h" "$(DSTROOT)/include"

installsrc :
	
make_libdwarf :
	$(SILENT) $(ECHO) "------ Make libdwarf -----"
	$(SILENT) ($(CD) "$(SRCROOT)/$(LIBDWARF_SRC)" && ./configure $(LIBDWARF_CONFIG))
	$(SILENT) ($(CD) "$(SRCROOT)/$(LIBDWARF_SRC)" && make CFLAGS="$(CFLAGS)")

make_libdwarf_install :
	$(SILENT) $(ECHO) "----- Make Install libdwarf -----"
	$(SILENT) ($(CD) "$(SRCROOT)/$(LIBDWARF_SRC)" && ./configure $(LIBDWARF_CONFIG))
	$(SILENT) ($(CD) "$(SRCROOT)/$(LIBDWARF_SRC)" && make CFLAGS="$(CFLAGS)")

	# Create install directories
	install -d -m 0755 "$(DSTROOT)/$(USR_LOCAL)/lib"
	install -d -m 0755 "$(DSTROOT)/$(USR_LOCAL)/include"

	# process the archive with ranlib.  This splits the archive into two fat archives
	# containing thin obj files, instead of a single archive containing fat obj files.
	# Failure to perform this step will result in an unusable library.
	#
	# This should be replaced in the future by creating the archive via 'libtool -static'
	# 
	# Here we do the ranlib before copying the file to it's destination, so that
	# dwarfdump can find it where it expects it (../libdwarf)
	ranlib "$(SRCROOT)/$(LIBDWARF_SRC)/libdwarf.a"

	# Install & strip binaries
	install -m 0755 "$(SRCROOT)/$(LIBDWARF_SRC)/libdwarf.a" "$(DSTROOT)/$(USR_LOCAL)/lib"
	
	# Install headers
	$(SILENT) $(CP) "$(SRCROOT)/$(LIBDWARF_SRC)/dwarf.h" "$(DSTROOT)/$(USR_LOCAL)/include"
	$(SILENT) $(CP) "$(SRCROOT)/$(LIBDWARF_SRC)/libdwarf.h" "$(DSTROOT)/$(USR_LOCAL)/include"

	# Install man pages
	install -d -m 0755 "$(DSTROOT)/usr/share/man/man4"
	#install -m 0755 "$(SRCROOT)/$(LIBDWARF_SRC)/libdwarf2.1.mm"  "$(DSTROOT)/usr/share/man/man4/libdwarf2.4"
	#install -m 0755 "$(SRCROOT)/$(LIBDWARF_SRC)/libdwarf2p.1.mm" "$(DSTROOT)/usr/share/man/man4/libdwarf2p.4"

make_dwarfdump :
	$(SILENT) $(ECHO) "----- Make dwarfdump -----"
	$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && ./configure $(DWARFDUMP_CONFIG))
	$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && make CFLAGS="$(CFLAGS)")

make_dwarfdump_install :
	#
	# dwarfdump won't build fat without some considerable help...
	#
	# This is because it uses the -E flag to gcc, which can't be mixed with multiple -arch flags.
	#

	# For now, we only build dwarfdump for ppc,i386
	(if test "$(HOST_ARCH)" = "x86_64"; then \
		HOST_ARCH=i386;			 \
	fi;)
	(if test "$(HOST_ARCH)" = "ppc64"; then \
		HOST_ARCH=ppc;			\
	fi;)

	# If we're only building for one architecture, skip the extra steps
	(if test "$(HOST_ARCH)" != "$(RC_ARCHS)"; then										\
		if test "$(HOST_ARCH)" = "i386"; then										\
			$(SILENT) $(ECHO) "----- Make Install dwarfdump (i386) -----";						\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && ./configure $(DWARFDUMP_CONFIG));			\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && make CFLAGS="$(DD_CFLAGS)");				\
			$(SILENT) $(CP) "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump" "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump.i386";	\
																\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && make clean);						\
																\
			$(SILENT) $(ECHO) "----- Make Install dwarfdump (ppc) -----";						\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && CC="gcc" ./configure $(DWARFDUMP_CONFIG)		\
									  --host=powerpc-apple-darwin9 --build=i686-darwin-9);	\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && make CFLAGS="$(DD_CFLAGS)");				\
			$(SILENT) $(CP) "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump" "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump.ppc";	\
		else														\
			$(SILENT) $(ECHO) "----- Make Install dwarfdump (ppc) -----";						\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && ./configure $(DWARFDUMP_CONFIG));			\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && make CFLAGS="$(DD_CFLAGS)");				\
			$(SILENT) $(CP) "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump" "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump.ppc";	\
																\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && make clean);						\
																\
			$(SILENT) $(ECHO) "----- Make Install dwarfdump (i386) -----";						\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && CC="gcc -arch i386" HOST_CC="gcc" ./configure $(DWARFDUMP_CONFIG)	\
								--target=i686-apple-darwin9 --host=i686-apple-darwin9);	\
			$(SILENT) ($(CD) "$(SRCROOT)/$(DWARFDUMP_SRC)" && make CFLAGS="$(DD_CFLAGS)");				\
			$(SILENT) $(CP) "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump" "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump.i386";	\
		fi;														\
		lipo -create "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump.i386" "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump.ppc"		\
		     -output "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump";								\
	fi;)

	# Create install directories
	install -d -m 0755 "$(DSTROOT)/$(USR_BIN)"

	# Install & strip binaries
	install -m 0755 "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump" "$(DSTROOT)/$(USR_BIN)"
	
	# Install man pages
	install -d -m 0755 "$(DSTROOT)/usr/share/man/man1"
	install -m 0755 "$(SRCROOT)/$(DWARFDUMP_SRC)/dwarfdump.1" "$(DSTROOT)/usr/share/man/man1/dwarfdump1."

#.PHONY:

