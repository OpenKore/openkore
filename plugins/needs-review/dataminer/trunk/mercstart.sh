#!/bin/bash
export LC_ALL="C"

# run openkore with this unix user
RUNAS="dave"
# wait as many seconds before doing the next tour
WAITSECS=1800

echo "update botruns set brdone='Yes'" | mysql -u mercdbadm mercdb
echo "update botcont set bcdone='Yes'" | mysql -u mercdbadm mercdb
echo "update botpos set bpmap='Connecting'" | mysql -u mercdbadm mercdb

botrun() {
	echo "Calling botrun $1 $2"
	if [ -z "$1" -o -z "$2" -o ! -z "$3" ]; then
		return
	fi
	if [ ! "$2" = "gspot" ]; then
		echo "Unknown BotRun $2! Returning!"
		echo "update botruns set brdone='Yes'" | mysql -u mercdbadm mercdb
		echo "update botcont set bcdone='Yes'" | mysql -u mercdbadm mercdb
		return
	fi
	echo "Inserting running bot"
	echo 'insert into botruns (brdone) values ("No") ' | mysql -u mercdbadm mercdb
#	su -c "perl ./openkore.pl \"$1\"" $RUNAS
	su -c "perl ./openkore.pl --control=/home/dave/openkore-cvs20060227/control.gspot" $RUNAS
	echo "Setting bots to deactive"
	echo "update botruns set brdone='Yes'" | mysql -u mercdbadm mercdb
	echo "update botcont set bcdone='Yes'" | mysql -u mercdbadm mercdb
	echo "update botpos set bpmap='Connecting'" | mysql -u mercdbadm mercdb
}

tour() {
	echo "Doing Tour!"
	echo "Resetting Shops!"
	echo "update shopcont set isstillin = 'No'" | mysql -u mercdbadm mercdb
	echo "Inserting running bot"
	echo 'insert into botruns (brdone) values ("No") ' | mysql -u mercdbadm mercdb
	su -c "perl ./openkore.pl" $RUNAS
	echo "Setting bots to deactive"
	echo "update botruns set brdone='Yes'" | mysql -u mercdbadm mercdb	
	echo "update botcont set bcdone='Yes'" | mysql -u mercdbadm mercdb	
	echo "update botpos set bpmap='Connecting'" | mysql -u mercdbadm mercdb
}

while [ 1 ]; do
	echo "Waiting max $WAITSECS sec at:"
	date
	CURTIME=$(date +%s)
	TIMEMAX=$[ $CURTIME + $WAITSECS ]
	TOURDONE="No"
	
	while [ "$TOURDONE" = "No" -a "$TIMEMAX" -gt "$CURTIME" ]; do
		RES=$(echo 'SELECT bccommand FROM botcont WHERE bcdone = "No" LIMIT 0,1' | mysql -u mercdbadm mercdb | tail -n 1)
		echo "Checking for Commands!" $(date) "Got: " $RES
		if [ "$TOURDONE" = "No" -a ! -z "$(echo $RES | grep tour)" ]; then
			echo "Starting Tour"
			tour
			TOURDONE="Yes"
			TIMEMAX=$[ $CURTIME + $WAITSECS ]
		fi
		if [ "$TOURDONE" = "No" -a ! -z "$(echo $RES | grep macro)" ]; then
			echo "Found Command " $RES
			botrun $RES
		fi
		sleep 5
		CURTIME=$(date +%s)
	done
	
	if [ "$TOURDONE" = "No" ]; then
		tour
	fi
done

#Mr_Incredible kalischool, any idea where to call a propper Command::run from a new --command= option we added ?
#Crypticode automacro initialise {
#Crypticode   mapchange any
#Crypticode   run-once 1
#Crypticode   call {
#Crypticode     do @config(gOnConnectCommand)
#Crypticode   }
#Crypticode }
#Crypticode would be the easiest way when using multiple config.txt's
#Crypticode dont you think too ?
#Mr_Incredible hmm - would work i guess - and wouldnt need changes on the sources ...
#Mr_Incredible mapchange any is triggered allways - even on connect ?
#Crypticode on each and any mapchange (including the first connection to the map(server))
#kalischool X_X this is difficult ... i wish french people don't take too many vacations
#Crypticode but for that you say run-once 1
#Crypticode it just triggers on the first time you connect to any map
#kalischool commands are only parsed during the ai loop
#Mr_Incredible then you have solved my problem Crypticode - thanks again! now i can "plug'n'play" many bot commands
