#!/usr/bin/env bash
# This script extracts strings from the OpenKore source code,
# updates raiseskill.pot and *.po, and compiles *.po to .mo.
set -e

LANGUAGES="tl id pt zh_CN zh th ko ru de"


echo "Extracting messages from source..."
xgettext --from-code=utf-8 -L Perl --force-po -o raiseskill.pot --keyword=translate --keyword=translatef \
	--add-comments='Translation Comment:' \
	../raiseSkill.pl
sed 's/charset=CHARSET/charset=UTF-8/; s/^# SOME DESCRIPTIVE TITLE\.$/# LANGUAGE translation for OpenKore/; s/# This file is distributed under the same license as the PACKAGE package\./# This file is distributed under the same license as OpenKore./' raiseskill.pot > raiseskill.pot.2
mv raiseskill.pot.2 raiseskill.pot

for LANG in $LANGUAGES; do
	FILE="$LANG.po"
	if [[ ! -f "$FILE" ]]; then
		echo "Creating new language file $FILE..."
		sed 's/CHARSET/UTF-8/' raiseskill.pot > "$FILE"
	else
		echo "Updating $FILE..."
		msgmerge -Uv "$FILE" raiseskill.pot
		msgfmt "$FILE" -o "$LANG.mo"
	fi
done
