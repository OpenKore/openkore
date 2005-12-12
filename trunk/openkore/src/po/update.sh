#!/bin/sh
set -e

LANGUAGES="tl"

echo "Extracting messages from source..."
xgettext -L perl --force-po -o openkore.pot --keyword=T \
	../*.pm \
	../Network/*.pm \
	../functions.pl

for LANG in $LANGUAGES; do
	FILE="$LANG.po"
	if [[ ! -f "$FILE" ]]; then
		echo "Creating new language file $FILE..."
		sed 's/CHARSET/UTF-8/' openkore.pot > "$FILE"
	else
		echo "Updating $FILE..."
		msgmerge -Uv "$FILE" openkore.pot
		msgfmt "$FILE" -o "$LANG.mo"
	fi
done
