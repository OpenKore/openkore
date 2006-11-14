#!/bin/sh
# This script extracts strings from the OpenKore source code,
# updates openkore.pot and *.po, and compiles *.po to .mo.
set -e

LANGUAGES="tl id pt zh th ko"

echo "Extracting messages from source..."
xgettext -L perl --force-po -o openkore.pot --keyword=T --keyword=TF \
	--add-comments='Translation Comment:' \
	../*.pm \
	../Network/*.pm \
	../Network/Receive/*.pm \
	../Poseidon/EmbedServer.pm \
	../AI/*.pm \
	../../openkore.pl \
	../functions.pl

sed 's/charset=CHARSET/charset=UTF-8/; s/^# SOME DESCRIPTIVE TITLE\.$/# LANGUAGE translation for OpenKore/; s/# This file is distributed under the same license as the PACKAGE package\./# This file is distributed under the same license as OpenKore./' openkore.pot > openkore.pot.2
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
