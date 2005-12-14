#!/bin/sh
# This script extracts strings from the OpenKore source code,
# updates openkore.pot and *.po, and compiles *.po to .mo.
set -e

LANGUAGES="tl"

echo "Extracting messages from source..."
xgettext -L perl --force-po -o openkore.pot --keyword=T --keyword=TF \
	../*.pm \
	../Network/*.pm \
	../../openkore.pl \
	../functions.pl

sed 's/charset=CHARSET/charset=UTF-8/' openkore.pot > openkore.pot.2
mv openkore.pot.2 openkore.pot

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
