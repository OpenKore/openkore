#!/bin/sh

export DIR=../../../../openkore/trunk/src
[ ! -d $DIR ] && export DIR=../../src
[ ! -d $DIR ] && export DIR=../../../src
if [ ! -d $DIR ]; then
  echo "cannot find OpenKore directory"
  exit 1
fi

perl -I$DIR -I$DIR/deps unittests.pl
