#!/bin/bash

cat > screen-obb << EOF
escape "^N!"
bind 'w' windowlist -b
bind 'W' windows
caption always "%{Yb} %D %Y-%02m-%02d %0c:%s %{k}|%{G} %l %{k}|%{W} %-w%{+u}%n %t%{-u}%+w"

screen -t chat 0 swatch -p "tail -f -q -n0 kore-*/logs/chat.txt 2> /dev/null"
screen -t items 1 swatch -p "tail -f -q -n0 kore-*/logs/items.txt 2> /dev/null"
EOF


for x in kore-*; do
	echo screen -t ${x#*-} ${x}/run.sh >> screen-obb
done


