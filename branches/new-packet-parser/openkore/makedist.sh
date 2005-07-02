#!/bin/bash
# This script creates a source tarball.

PACKAGE=openkore
VERSION=1.6.3
TYPE=bz2
# Uncomment the next line if you want a tar.gz archive
# TYPE=gz

DIRS=(.
	src
	src/build
	src/Actor
	src/Base
	src/IPC
	src/IPC/Manager
	src/Interface
	src/Interface/Console
	src/Interface/Console/Other
	src/Interface/Wx
	src/Interface/Wx/DockNotebook
	src/Network
	src/Network/Receive
	src/Utils
	src/auto/XSTools
	src/auto/XSTools/build
	src/auto/XSTools/misc
	src/auto/XSTools/pathfinding
	src/auto/XSTools/unix
	src/auto/XSTools/win32
)
PACKAGEDIR=$PACKAGE-$VERSION


if [[ "$1" == "--help" ]]; then
	echo "makedist.sh [--bin]"
	echo " --bin    Create a binary distribution."
	exit 1
elif [[ "$1" == "--bin" ]]; then
	BINDIST=1
	if [[ "$2" == "-o" ]]; then
		PACKAGEDIR="$3"
	fi
fi

ADDITIONAL=(Makefile Makefile.win32 Makefile.in)
if [[ "$BINDIST" != "1" ]]; then
	ADDITIONAL[${#ADDITIONAL[@]}]=Distfiles
	ADDITIONAL[${#ADDITIONAL[@]}]=makedist.sh
fi

export GZIP=--best
export BZIP2=-9


# Bail out on error
err() {
	if [ "x$1" != "x" ]; then
		echo "*** Error: $1"
	else
		echo "*** Error"
	fi
	exit 1
}

# Preparation: create the dist folder
rm -rf "$PACKAGEDIR" || err
mkdir "$PACKAGEDIR"  || err


# Copy the files to the dist folder
process() {
	local TARGET="$PACKAGEDIR/$1/"
	local IFS=$'\n'
	local FILES=`cat "$1/Distfiles" 2>/dev/null | sed 's/\r//g'`

	echo "# Processing $1 :"
	if ! [ -d "$TARGET" ]; then
		mkdir -p "$TARGET" || err
	fi
	for F in "${ADDITIONAL[@]}"; do
		if [ -f "$1/$F" ]; then
			echo "Copying $1/$F"
			cp "$1/$F" "$TARGET" || err
		fi
	done

	for F in ${FILES[@]}; do
		echo "Copying $1/$F"
		cp "$1/$F" "$TARGET" || err
	done
}

for D in ${DIRS[@]}; do
	process "$D"
done

# Stop if this is going to be a binary distribution
if [[ "$BINDIST" == "1" ]]; then
	rm -f "$PACKAGEDIR/Makefile"
	unix2dos "$PACKAGEDIR/News.txt"
	echo
	echo "====================="
	echo "Directory '$PACKAGEDIR' created. Please add (wx)start.exe and NetRedirect.dll."
	exit
fi

# Create tarball
echo "Creating distribution archive..."
if [ "$TYPE" = "gz" ]; then
	tar -czf "$PACKAGEDIR.tar.gz" "$PACKAGEDIR" || err
	echo "$PACKAGEDIR.tar.gz"
else
	tar --bzip2 -cf "$PACKAGEDIR.tar.bz2" "$PACKAGEDIR" || err
	echo "$PACKAGEDIR.tar.bz2"
fi

rm -rf "$PACKAGEDIR"
