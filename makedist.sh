#!/bin/bash
# This script creates a source tarball for OpenKore.

PACKAGE=openkore
VERSION=`date +"%Y-%m-%d"`

DIRS=(.
	src
	src/Actor
	src/Actor/Slave
	src/AI
	src/AI/Slave
	src/auto/XSTools
	src/auto/XSTools/darwin/include
	src/auto/XSTools/misc
	src/auto/XSTools/OSL
	src/auto/XSTools/OSL/doc
	src/auto/XSTools/OSL/IO
	src/auto/XSTools/OSL/Net
	src/auto/XSTools/OSL/Net/Unix
	src/auto/XSTools/OSL/Net/Win32
	src/auto/XSTools/OSL/test/unit
	src/auto/XSTools/OSL/Threading
	src/auto/XSTools/OSL/Threading/Unix
	src/auto/XSTools/OSL/Threading/Win32
	src/auto/XSTools/PaddedPackets
	src/auto/XSTools/PaddedPackets/Algorithms
	src/auto/XSTools/PathFinding
	src/auto/XSTools/Translation
	src/auto/XSTools/unix
	src/auto/XSTools/utils
	src/auto/XSTools/utils/c-bindings
	src/auto/XSTools/utils/perl
	src/auto/XSTools/utils/unix
	src/auto/XSTools/utils/win32
	src/auto/XSTools/win32
	src/Base
	src/Base/Ragnarok
	src/Base/Server
	src/Base/WebServer
	src/build
	src/Bus
	src/Bus/Server
	src/deps
	src/deps/Carp
	src/deps/Class
	src/deps/Class/Accessor
	src/deps/Class/Data
	src/deps/Data/YAML
	src/deps/Devel
	src/deps/Devel/StackTrace
	src/deps/Exception
	src/deps/Exception/Class
	src/deps/File
	src/deps/JSON
	src/deps/List
	src/deps/Text
	src/deps/Tie
	src/doc
	src/doc/data
	src/doc/srcdoc
	src/Interface
	src/Interface/Console
	src/Interface/Win32
	src/Interface/Wx
	src/Interface/Wx/DockNotebook
	src/Interface/Wx/List
	src/Interface/Wx/List/ItemList
	src/Interface/Wx/StatView
	src/InventoryList
	src/MediaServer
	src/Network
	src/Network/Receive
	src/Network/Receive/idRO
	src/Network/Receive/iRO
	src/Network/Receive/kRO
	src/Network/Send
	src/Network/Send/idRO
	src/Network/Send/iRO
	src/Network/Send/kRO
	src/Network/XKore2
	src/po
	src/Poseidon
	src/scons-local-3.1.2
	src/scons-local-3.1.2/scons-local-3.1.2
	src/scons-local-3.1.2/scons-local-3.1.2/SCons
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/compat
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Node
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Platform
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Scanner
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Script
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Tool
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Tool/clangCommon
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Tool/docbook
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Tool/MSCommon
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Tool/packaging
	src/scons-local-3.1.2/scons-local-3.1.2/SCons/Variables
	src/Task
	src/test
	src/test/data
	src/test/data/child
	src/test/Utils
	src/Utils
	src/Utils/StartupNotification
)
PACKAGEDIR=$PACKAGE-$VERSION


if [[ "$1" == "--bin" ]]; then
	BINDIST=1
	if [[ "$2" == "-o" ]]; then
		PACKAGEDIR="$3"
	fi
elif [[ "$1" == "--semibin" ]]; then
	SEMIBINDIST=1
	PACKAGEDIR="$2"
	if [[ "$PACKAGEDIR" = "" ]]; then
		echo "No output folder given. See --help"
		exit 1
	elif [[ ! -d "$PACKAGEDIR" ]]; then
		echo "The output folder does not exist. See --help"
		exit 1
	fi
elif [[ "$1" == "--help" ]]; then
	echo "makedist.sh [ --bin | --semibin DIR ]"
	echo " --bin [ -o DIR ] Create a binary distribution archive, including the binaries,"
	echo "                  confpack and tablepack."
	echo " --semibin DIR    Create a binary distribution, excluding binaries, confpack and"
	echo "                  tablepack. Files will be copied to DIR."
	exit 1
else
	echo "unknown option '$1'"
	echo "Try 'makedist.sh --help' for more information."
	exit 1
fi

if [[ "$BINDIST" == "1" ]]; then
	for F in start.exe wxstart.exe NetRedirect.dll XSTools.dll start-poseidon.exe; do
		if [[ ! -f "$F" ]]; then
			echo "Please put $F in the current folder."
			exit 1
		fi
	done
fi

ADDITIONAL=()
if [[ "$BINDIST" != "1" ]]; then
	ADDITIONAL[${#ADDITIONAL[@]}]=SConstruct
	ADDITIONAL[${#ADDITIONAL[@]}]=SConscript
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
mkdir "$PACKAGEDIR/control"  || err
mkdir "$PACKAGEDIR/fields"  || err


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
			echo "  copying $1/$F"
			cp "$1/$F" "$TARGET" || err
		fi
	done

	for F in ${FILES[@]}; do
		echo "  copying $1/$F"
		cp "$1/$F" "$TARGET" || err
	done
}

for D in ${DIRS[@]}; do
	process "$D"
done


#######################################


# Copy the confpack and tablepack files to the distribution's folder
cp -v control/*.txt "$PACKAGEDIR/control/" || err
cp -v fields/*.gz "$PACKAGEDIR/fields/" || err
cp -vr fields/tools "$PACKAGEDIR/fields/" || err
cp -vr tables "$PACKAGEDIR/" || err

# Convert openkore.pl to Unix line format, otherwise Unix users can't execute it directly.
perl src/build/dos2unix.pl "$PACKAGEDIR/openkore.pl" || err
perl src/build/unix2dos.pl "$PACKAGEDIR/README.md" || err

if [[ "$BINDIST" == "1" ]]; then
	# Create binary zipfile
	cp -v XSTools.dll NetRedirect.dll start-poseidon.exe "$PACKAGEDIR/" || err

	# Win32 binary
	cp -v start.exe "$PACKAGEDIR/" || err
	zip -9r "$PACKAGE-$VERSION-win32.zip" "$PACKAGEDIR" || err
	echo "$PACKAGE-$VERSION-win32.zip created"

	# Win32 Wx binary
	cp -v wxstart.exe "$PACKAGEDIR/" || err
	rm -vf "$PACKAGEDIR/start.exe"
	zip -9r "$PACKAGE-$VERSION-win32_WX.zip" "$PACKAGEDIR" || err
	echo "$PACKAGE-$VERSION-win32_wx.zip created"

elif [[ "$SEMIBINDIST" == "1" ]]; then
	# Create tarball
	echo "Creating distribution archive..."
	tar --bzip2 -cf "$PACKAGEDIR.tar.bz2" "$PACKAGEDIR" || err
	echo "$PACKAGEDIR.tar.bz2"
fi

rm -rf "$PACKAGEDIR"
