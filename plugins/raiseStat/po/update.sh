#!/usr/bin/env bash
# This script extracts strings from the OpenKore source code,
# updates raisestat.pot and *.po, and compiles *.po to .mo.
set -e

LANGUAGES="tl id pt zh_CN zh th ko ru de"


echo "Extracting messages from source..."
xgettext --from-code=utf-8 -L Perl --force-po -o raisestat.pot --keyword=translate --keyword=translatef \
	--add-comments='Translation Comment:' \
	../raiseStat.pl
sed 's/charset=CHARSET/charset=UTF-8/; s/^# SOME DESCRIPTIVE TITLE\.$/# LANGUAGE translation for OpenKore/; s/# This file is distributed under the same license as the PACKAGE package\./# This file is distributed under the same license as OpenKore./' raisestat.pot > raisestat.pot.2
mv raisestat.pot.2 raisestat.pot

for LANG in $LANGUAGES; do
	FILE="$LANG.po"
	if [[ ! -f "$FILE" ]]; then
		echo "Creating new language file $FILE..."
		sed 's/CHARSET/UTF-8/' raisestat.pot > "$FILE"
	else
		echo "Updating $FILE..."
		msgmerge -Uv "$FILE" raisestat.pot
		msgfmt "$FILE" -o "$LANG.mo"
	fi
done
