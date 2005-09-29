#!/bin/bash

> swatch.chat

while read LINE ; do

	REGEX=`echo "$LINE" | cut -f 1`
	EVENT=`echo "$LINE" | cut -f 2`
	echo "watchfor $REGEX" >> swatch.chat
	
	OLDIFS="$IFS"
	IFS=","
	for x in $EVENT; do
		echo "	$x" >> swatch.chat
	done
	IFS=$OLDIFS
	
done < trigger.chat
