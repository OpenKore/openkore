All this Project is GPL.
Most Parts done by Mr.Incredible
Some big parts (on the .php and the whole .css) done by Martii
Some minor parts done by "my community"
Scripts developed and tested on euRO/Chaos

This is a copy of my working mercdb2/chardb environment.

Don't use internet explorer with the frontend, cause it sucks!
use any browser with it (firefox works nice)

There is lots of work to do, to make it more install friendly
on various systems, and not only on MY linux box

It works fine on my linux box - and you should get it running
on your linux box, too. But there is a lot of work to do yet,
especially in the chardb, since this is really new.
mercdb2 is nearly feature complete.

so, here is, what to do:

get a linux box!
	- if someone feels the need to get it run on windows:
	  - rewrite mercstart.sh as a perl module
		(i am fine with a bash script, since it gets the job done)
get apache2/mysql/php4 running
get DBD::mysql from perl cpan
create databases mercdb and chardb with the db-schema/*.sql files
create users for mercdb and chardb
create a mercdbadm user with only insert, update and delete rights on mercdb
give mercdbadm select rights on botpos and botcont
set passwords in all .php and .pl files (yes, i should use includes!)
insert users in table users in both dbs!
  (dont use important passwords here, since they are not encrypted yet)
make two subdomains mercdb.yourdomain.com and chardb.yourdomain.com
 - you need the files in the main dir, since there are absolute pathes
   in it somewhere (NOT written by myself)
put the .php files there
adjust mercdb url in chardb .php file (so connection from chardb
  to merchdb works)
test it with a browser - everything should work without errors, even
  there is no data yet. you should get logged in already
  
now get the bot running. the plugins populate data in the databases.
use the playerRecordSql.pl with your xkore1 windows client, too, so
you record everyone you see to the db
start the ./mercstart.sh shell script, which control all the bot
behaviour

send the bot on tour via bot control and view it running via
bot running window

now, search for item names in mercdb - search for % to see all items
search for %% to get a hot-deal-only overview (% and %% consume
much cpu power - so dont give the rights to everyone)
white rows are in shops right now!
klick on the mapname to get a pop-up of the city with a dot,
  where the shop is located

search for every player, guild, party, guildpos, accountid in chardb 
  (all searches work already)
chars with same row color are all known chars from one account

todo:
	implement ajax in the map, so the position of the bot is
	  moved over a fixed map - and not reload the whole .jpg
	  like i do it right now (nearly finished)
    completly rewrite the mercdb.shopcont table, since
	  it is a pain in the ass from a database-design-point-of-view
	  right now, its not normalized - which results in poor performance
	make some screenshots
	kill absolute paths in all .php files
	create multipage search results you can browse through
	  instead of all items on one page (1000s of shops with elus on
	  one page suck)
	improve the chardb frontend in many ways
	  - make the player details nice
	  - add guild and party to seen overview
	improve playerRecordSql.pl like kaliwangan told me
	get an online demo running with data from an pserver
	encrypt the password columns and the password cookies