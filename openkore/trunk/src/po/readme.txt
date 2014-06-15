Update translation texts
README by windhamwong 9/4/2014

For Windows:
Installation Requirement:
GNU-Win32 (http://gnuwin32.sourceforge.net/packages/gettext.htm)
cygwin


Run command below (For windows, please run it in cygwin):
xgettext --from-code=utf-8 -L Perl --force-po -o openkore.pot --keyword=T --keyword=TF ../../openkore.pl ../Actor/*.pm ../AI/*.pm ../AI/Slave/*.pm ../Interface/Wx/List/ItemList/*.pm ../Interface/Wx/List/*.pm ../Interface/Wx/StatView/*.pm ../Interface/Wx/*.pm ../Interface/*.pm ../Network/Receive/kRO/*.pm ../Network/Receive/*.pm ../Network/Send/kRO/*.pm ../Network/Send/*.pm ../Network/*.pm ../Poseidon/*.pm ../Task/*.pm ../Misc.pm ../functions.pl
sed 's/charset=CHARSET/charset=UTF-8/; s/^# SOME DESCRIPTIVE TITLE\.$/# LANGUAGE translation for OpenKore/; s/# This file is distributed under the same license as the PACKAGE package\./# This file is distributed under the same license as OpenKore./' openkore.pot > openkore.pot.2
mv openkore.pot.2 openkore.pot

msgmerge -Uv "<LANG>.po" openkore.pot
msgfmt "<LANG>.po" -o "<LANG>.mo"

*Please read update.sh as reference
Currently there are some missing translations in ../*.pm