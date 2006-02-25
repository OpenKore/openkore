#!/bin/bash
# Installation script for Unix.
PREFIX=/usr/local
BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib"
INCLUDEDIR="$PREFIX/include/libgrf"
PKGDATADIR="$PREFIX/share/grftool"

if test "$1" = "--help"; then
	echo "GRF Tool Unix installation script."
	echo
	echo "To install GRF Tool:"
	echo "	./install.sh"
	echo
	echo "To uninstall GRF Tool:"
	echo "	./install.sh --uninstall"
	exit
fi

uninstall=0
if test "$1" = "--uninstall"; then
	uninstall=1
fi

function inst()
{
	local base=`basename "$1"`
	if test $uninstall = 1; then
		echo "Deleting $2/$base"
		rm -f "$2/$base"
	else
		echo "Installing $1 -> $2/$base"
		mkdir -p "$2"
		install "$1" "$2"
	fi
}

set -e
if test "$uninstall" = 0; then
	echo scons -Q
	scons -Q
fi

inst gtk/grftool-gtk "$BINDIR"
inst gtk/grftool.glade "$PKGDATADIR"
inst tools/grftool "$BINDIR"
inst tools/spritetool "$BINDIR"
inst tools/gxtool "$BINDIR"
inst tools/libgrf-1.2.pc "$LIBDIR/pkgconfig"
inst lib/static/libstatic-grf.a "$LIBDIR"
inst lib/grf.h "$INCLUDEDIR"
inst lib/grfcrypt.h "$INCLUDEDIR"
inst lib/grfsupport.h "$INCLUDEDIR"
inst lib/grftypes.h "$INCLUDEDIR"
inst lib/rgz.h "$INCLUDEDIR"
inst lib/sprite.h "$INCLUDEDIR"

if test $uninstall = 1; then
	rmdir "$INCLUDEDIR" "$LIBDIR/pkgconfig" 2> /dev/null
fi
