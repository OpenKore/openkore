#!/bin/bash
# This script creates a source distribution.

PACKAGE=openkore-packet-extractor
VERSION=1.1.0

DIRS=(.
	objdump
	objdump/bfd
	objdump/include
	objdump/include/aout
	objdump/include/coff
	objdump/include/elf
	objdump/libiberty
	objdump/opcodes
	scripts
	ui
	wz
	wz/unix
	wz/win
	doc
)
PACKAGEDIR=$PACKAGE-$VERSION

ADDITIONAL=(SConstruct SConscript LICENSE.TXT README.TXT Distfiles makedist.sh)

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

unix2dos "$PACKAGEDIR/LICENSE.txt"
echo
echo "====================="
echo "Directory '$PACKAGEDIR' created. Please add:"
echo "objdump.exe, openkore-packet-extractor.exe, mgwz.dll, mingwm10.dll, wxbase26u_gcc.dll, wxmsw26u_core_gcc.dll"
