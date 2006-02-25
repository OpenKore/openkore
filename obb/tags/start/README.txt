OBB - Openkore Bot Builder

This package was build to allow a full management of Openkore Ragnarok Client.

I found myself trying to find a good way do manage bots. I notice that system
administration abilities should be used to administrate bots. Since that there
is some features that only works in Windows Openkore version, I put pipeling
and all unixhood tools to help Openkore (I hope make this a very goot tool).

To have a fully funcional environment you should have:

	bash 	- To script related things
	make 	- To build all files
	screen 	- To watch bots, and manage them
	swatch 	- To monitor log files, and start triggers
	mpg123 	- To play alarms
	mail 	- To send mail if some trigger is activated
	wget 	- To retrieve some files
	cvs 	- To update sources and files
	expect 	- To do some unix black magic! ;-D (not used yet)
	
If you don't know what I'm talking about, or if you don't know how to
install of configure above tools, please don't send me a mail I will not
answer.

######################################################################
THIS TOOL DIDN'T WORK IN WINDOWS, AND NEVER WILL. PLEASE DON'T ASK ME 
ABOUT THAT OR I'M WILL BURN YOU IN HELL (YES I'M THE DEVIL IN EARTH)
######################################################################

How it works?
=============
This tool is useful to manage a large number of bots, can manage 1 bot too
but isn't useful. You can bot in different servers with different characters.
All that you need is know how to manage the files.

This tool can take some responses when some triggers are activated, everything
that goes to the log files can be watched and triggered. Triggers can do simple
things as "start an alarm", send a mail or sms message, logoff, shutdown the
system, resuming everything that could be possible with normal unix commands.
I really hope use expect in a near future to do some blackmagic as: answer 
something, use some skill, act in a specified manner, and everything that
could be done with console commands.

########################################################################
    TRIGGERS ARE NOT WORKING RIGHT NOW!!! JUST SIMPLE LOGGING!!!
########################################################################


BEGGINING
=======================

Typing 'make ; ./obb.sh', should do everything. But let's take a better view.


make update
	Update cvs source tree, grabbing the latest and hottest Openkore 
features. (You should have internet connection to do that).

make default
	Build kore_default directory, in this direcory stay all default 
configurations, you should not touch here if you want to do a little tweak
in just 1 bot. All configurations here are propagated to ALL bots in restart

make bot
	Build kore-botname directory, where botname is a simple name to your
bot configuration, should't have space or special characters and didn't need
to be the EXACT name of your character. Example, I have a character called:
Legolas Silverleaf, I can use a botname as legolas, my directory will be
called 'kore-legolas'

make manage
	Build screen configuration, based on bots created, the file is stored inopenkore bot builder root dir, with name screen-obb
	
make triggers
	Here we build the triggers to charactes, these triggers can be 
configured individually or globally. More about triggers in trigger.chat and
trigger.items in scripts directory, the triggers are managed by swatch unix system tool.

After you has built your initial environment you should do some tweaks in
default directory. You should have knowledge about Openkore configuration, but
remember all changes in kore_default will be propagated to all your bots. The
individual tweaks should be done in every bot directory.

I recommend to you see these files

config.txt 			- Main configuration file (required)
config_behavior.txt 		- If you want to change normal bot 
				behaviors (optional)
config_autoswitch.txt 		- If you expect change wapons/equips
				based on situation (optional) 
config_item_usage.txt 		- If you want to use itens (optional)
config_npc_buy.txt 		- If you want to buy itens from npc 
				shops (optional)
config_npc_sell.txt 		- If you want to sell itens (optional)
config_storage.txt 		- If you want store some things (optional)
config_nov_skills.txt 		- Novice skills (not needed)
config_swd_skills.txt 		- Swordman skills (not needed)
config_combos.txt 		- If do you use combos (optional)
config_aliases_comms.txt 	- If you want create new commands (not nedded)
config_aliases_friends.txt 	- If you want create aliases to pm your
				friends (not needed)
config_break.txt 		- If you want to change brak time (not nedded)
config_build_hibkni.txt 	- If you want to do auto build (not needed)
config_build_vitkni.txt 	- If you want to do auto build (not needed)
config_relations.txt 		- What to do when someon interacts with 
				you (not needed)
config_server.txt 		- To change server/char configs (not needed)
config_timings.txt 		- Timeouts and disconection times (not needed)


All files that are changed to a specified bot, delete the link and replace
with a normal file. (Copy should help), If you don't do that, all changes
will affect all your bots

To run the OBB you should simply type ./obb.sh

We use some undocumented Openkore feature. These includes:

- !include (to load files in a modular way)
- More will be inserted here

Good booting,
IMP (imp_obb@gmail.com)

