#!/bin/bash
# This script creates a source tarball. Unfortunately I can't
# figure out a way to simulate 'make dist' with SCons :(

PACKAGE=dataserver
VERSION=0.1
TYPE=bz2
# Uncomment the next line if you want a tar.gz archive
# TYPE=gz

DIRS=(. main plugin)
PACKAGEDIR=$PACKAGE-$VERSION
ADDITIONAL=(Distfiles)
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
