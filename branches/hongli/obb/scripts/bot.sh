#!/bin/bash

while :; do
	echo -n "Insert botname (left blank to exit): "
	read BOTNAME
	BOTNAME=`echo $BOTNAME | tr "[A-Z]" "[a-z]" | tr -d "!@#$%^&*()~;:<>?,. "`
	[ ! "$BOTNAME" ] && exit 0
	[ -d kore-$BOTNAME ] && exit 1

	mkdir kore-$BOTNAME
	lndir -silent ../kore_default kore-$BOTNAME
	rm -rf kore-$BOTNAME/control/config.txt
	rm -rf kore-$BOTNAME/plugins/example.pl
	rm -rf kore-$BOTNAME/plugins/example2.pl
	cp examples/config* kore-$BOTNAME/control/
	mkdir kore-$BOTNAME/logs
	touch kore-$BOTNAME/logs/{items,chat}.txt
	cat > kore-$BOTNAME/run.sh << EOF
#!/bin/bash

cd kore-$BOTNAME

while :; do
	./openkore.pl --interface=Console::Curses
	sleep 15
done
EOF
	chmod 755 kore-$BOTNAME/run.sh
done
