#!/bin/bash
PREFIX=/usr/local
BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib"
INCLUDEDIR="$PREFIX/include/libgrf"

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
echo scons -Q
scons -Q

inst gtk/grftool-gtk "$BINDIR"
inst tools/grftool "$BINDIR"
inst tools/spritetool "$BINDIR"
inst tools/libgrf-1.1.pc "$LIBDIR/pkgconfig"
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
