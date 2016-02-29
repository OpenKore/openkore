The idea: 
running around and manually checking prices from other mercs 
is a pain. let a bot do the job. check on a web-site what he found.
when the bot finds very cheap offers (hot-deals) let him buy it.

What it does:
when walked around in a given map with merchants the bot 
checks at 'packet_vender' hook for available merchants. Now
it searches in database table 'shopvisit' for the merchants user ID
to check when the merc was visited the last time. if the last check 
wasn't longer ago than $visitTimeout seconds, the bot will ask RO 
for the mercs shop list and write the present date and time into the 
database. 

at the hook 'packet_vender_store' mercDbFill will be called. it parses  
the venderList and writes it into the mysql table 'shopcont'.

HOT DEALS:
when you put in your config.txt item-names or 'all' after 'merchantDB_shoppinglist'
the bot will buy it, when it is discovered as hot deal. it buys all hot-deals with 'all'.
hot-deals are offered items with a price that is under the average price minus it's
standard deviation. 

the webfrontend is done in php, because i know php better than perl ;)
it shows for all found items and cards the min, max, average price and the standard 
deviation of the price, and the "hot-deal" barrier.
you can search for cards inserted into items, as well as see what merc
offered which items. and so on. should be self explaining.

requirements:
- any, even a new born RO char :)
- openkore cvs
- mysql database (can probably be changed to another database due to DBI)
- webserver with php support (eq: XAMPP - http://www.apachefriends.org/en/)
- perl (windows user might want to choose Active Perl: www.activestate.com)
- perl modules: TimeDate, DBD::mysql, DBI

<quote=tofu_soldier>
so, if any of you intended to get the plugin mercDB.pl running correctly
in win32, get to ppm and have these installed:
install CGI::Enurl (doesnt look like it is needed. if you have problems with win, add it)
(not sure if you need to do this as well)install CGI
install TimeDate
install DBD::mysql
</quote>

here are some tipps for win (xp) users:
i saw many problems with installing the plugin on a WinXp system. so i tried it for my self, 
and had really a hard time. but i got it together. here is what it took me to install 
everything on a winXP SP2 system.

1. install openkore - the cvs isn't needed.
2. install activeperl 5.8.7.813 - http://downloads.activestate.com/ActivePerl/Windows/5.8/ActivePerl-5.8.7.813-MSWin32-x86-148120.msi
3. install with ppm (thats the Perl Package Manager) the following packages:
- install Time-Hires
- install TimeDate
- install dbd-mysql
when you start the ppm, you get a command line interface. just type in (or paste in)
the commands starting with "install...". (dbd-mysql installs also dbi.)

i didn't need any of the other perl-libs.

4. to evoid errors like "Unable to load plugin plugins/mercdb.pl: Can't locate DBI.pm in @INC ..."
add this to openkore.pl at the beginning, after the other lines with "use lib". 
change C:/Perl to where ever you installed Active Perl.

use lib 'C:/Perl/lib/';
use lib 'C:/Perl/site/lib/';

5. for a webserver (win, linux, osx, ...) with mysql, and php look here:
XAMPP - http://www.apachefriends.org/en/

Installation:
- make folder "plugins" in the openkore folder (if it doesn't already exists)
- copy mercdb.pl into the plugin folder of openkore
- create a mysql database ($database)
- create a new mysql-user that can read and write the roshop tables 
  ($dbUser and $dbPassword)
- set up the mysql tables with the roshop.sql file (i.e. with phpmyadmin)
- change the mysql access informations in mercdb.pl and index.php
my $dbUser			= "roshop";				# the name of the mysql user that has read/write access to database $database
my $dbPassword	= "roshop";				# his password
my $database		= "ro_shop";			# the used database
my $dbHostname	= "192.168.6.1";	# mysql server 
my $dbPort			= "3306";					# mysql server port

- put the following into your config.txt
  merchantDB 1
  merchantDB_shoppinglist 
	merchantDB_myHotDeal 0.9

- copy the index.php on your webserver 
- send your char into a city or other place where merchants are
- have it walk around the merchants (i.e. with a macro)
- check index.php for the results

To-do:
- performance problems
- add NPC dealer prices 

Fixed:
- the name of the shop owner and the shops are right. the shop owner
  might be updateted later but should be as good as openkore gives em
  to the plugin
- elemental weapons are recognized
- update existing entries in the database (price changes etc.)
- the number of slots is correct now
- it works with the changed vender store list in cvs (openkore 1.3.0pre)
- updated to work with openkore 1.6.2

Known bugs:
- some items are written multiple times into the DB. same shop, same item, same specs...

Planned features:
- upload a store.txt to the web-frontend and get a version with best / 
  average prices from the database
- check the prices in-game via chat-commands send to the bot

config.txt variables:
- merchantDB (1 or 0) # required
	to switch the usage of the plugin on or off. if not present the plugin will not work
- merchantDB_shoppinglist
  items you wanna buy, must be written like in the Vender Store List,
  separated by comma; make it "all" to buy all hot deals
- merchantDB_myHotDeal (<= 1)
  a modifier for HotDeals; look for cheaper items ie: 0.90 = hotdeal-range * 90% 



Thanks:
- my RO-playing and bot-hateing friends who love the results of what i do with openkore ;)
- the developers of openkore, without i would have stopped playing RO a long time ago
- the members of the openkore-forum for theire support and feedback

Apologies:
this plugin may be a total waste of time for you, because it only checks the 
prices goods are offered for and not the prices of the sales. i offer my 
excuses to you, but i found no way to check the real sales-prices.
and i apologise for my bad english. my english teacher would laugh her ass off
if she could read this ;) 

