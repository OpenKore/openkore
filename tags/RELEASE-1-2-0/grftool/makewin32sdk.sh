#!/bin/bash
# Create a Win32 SDK for libgrf

VERSION=1.2.0
NAME=libgrf-win32-sdk
DIR=$NAME-$VERSION

set -ev
scons -Q
rm -rf "$DIR"
mkdir "$DIR"
mkdir "$DIR/dll"
mkdir "$DIR/headers"
cp lib/dll/{grf.dll,grf.lib,grf.exp} "$DIR/dll/"
cp lib/dll/grf.gccdef "$DIR/dll/grf.def"
cp lib/*.h "$DIR/headers/"
cp LICENSE.txt SDK-README.txt "$DIR/"
