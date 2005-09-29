#!/bin/bash

function help() {
	echo "Usage: ./obbed.sh <conf_file> [char_name]"
	echo "If char name is ommited all chars are open"
	echo "It uses the shell variable EDITOR"

	exit 1
}

# Wrong number of arguments
[ $# -gt 2 -o $# -eq 0 ] && help

[ "$EDITOR" = "" ] && EDITOR="/usr/bin/vim"

if [ $# -eq 1 ]; then
	$EDITOR kore-*/control/*${1}*
else
	$EDITOR kore-${2}/control/*${1}*
fi

exit 0
