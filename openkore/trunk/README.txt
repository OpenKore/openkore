=========================
### OpenKore what-will-become-2.0.0
=========================


﻿=========================
### OpenKore 1.9.4 (beta)
=========================

Credits:
- johnny: Fix for headgear display.
- skseo, gksmf0615: kRO support update.
- piroJOKE: Field updates.
- PetroW: Support for the new eAthena actor movement message.
- Ptica: Socket bug fix in the bus framework.
- Reignh: Fix for Ninja weapon and Missing skills.
- natz: Various contributions.

Important changes:
- kRO support (February 25 2007) has been fixed.
- OpenKore Webstart has been removed. The experiment turned out to be
  unsuccessful.
- mRO server compatibility fixes.
- tRO server compatibility fixes.

Bug fixes:
- Headgears are now detected correctly.
- Ninja weapon are now detected correctly.
- Many crashers have been fixed.

New commands:
- Added more GM Commands
	gmremove : Warp to a player via character name or user name.
	gmrecall : summons a player via character name or user name.

New config options:
- homunculus_intimacyMax 	 : Max value of intimacy, if this value is reached feeding will discontinue till minimum is reached.
- homunculus_intimacyMin 	 : Min value of intimacy, will continue feeding if this value is reached.
- homunculus_hungerTimeoutMax 	 : How long should we wait between feedings? (max)
- homunculus_hungerTimeoutMin 	 : same as above, but min value
- homunculus_autoFeed 		 : turn on/off auto-feeding
- homunculus_autoFeedAllowedMaps : map names where to allow auto-feeding (leave empty for all maps)

New mon_control feature:
- disconnect on monster:<teleport>:
			1 to teleport if the monster is on the screen.
			2 to teleport if the monster attacks you.
			3 to disconnect if the monster is on your screen.
			This is only used in auto-attack mode.
			example :
				Poring 0 3 0 
				this will make kore disconnect for 30 secs when it sees poring.

=========================
### OpenKore 1.9.3 (beta)
=========================

I'm happy to announce the 4th beta release of OpenKore, version 1.9.3. It hasn't been easy - many developers were busy with their real lives. Some new contributors joined us while others left. I'd like to give my thanks to the following people, who have contributed to this release. Without them OpenKore would not be what it is today. :)

- Darkfate: partial servertype 11 support.
- piroJOKE: server information updates and table files updates,
  labels idea, partial servertype 13 support.
- Click: improved shop list randomization.
- Stalker: runFromTarget fix
- raizend: Top 10 packet parsers
- illusionist: Party fix, Guild Messages, top10 command, bRO support
- edeline: help with kRO server fixes.
- skseo: Korean translations and kRO fixes.
- Tatka: help with special character support in the Win32 console.
- heero: servertype 15 (pRO Thor) support.
- littlewens: Traditional Chinese translations.
- PlayingSafe: Fixes for big-endian systems, such as Mac-PPC.
- clarious: Help with vRO support.
- DInvalid: Correctly set character direction upon move, autoSwitch bugfix.
- Anarki: Monster ID support for mon_control.txt
- kanzo: ropp fix for XKoreProxy.
- xcv: Fix calculation of benchmark results and the autobuy AI.
- And of course, everybody in the existing OpenKore team. :) See http://cia.navi.cx/stats/project/openkore

Here's a summary of the major changes in this release:
- When you start OpenKore, it will show you a friendly web interface, 
  in which you can read project news (such as new OpenKore releases).
  You can also use it to open the OpenKore configuration folder, to choose a 
  language and to start OpenKore.
- Lots and lots of bugs have been fixed. Most notably, many crashers, UTF-8 (character set handling) bugs and AI bugs have been fixed.
- Support for the following servers has been restored: vRO (Vietnam), rRO (Russia), euRO (Europe). Note that you need the ropp plugin in order to play on any of these servers.
- Support for new classes, such as Gunslinger and Ninja.
- We now support more platforms. OpenKore should now work correctly on FreeBSD, MacOS X and Sun Sparc.
- OpenKore has been translated to traditional Chinese.
- About 30% performance improvement compared to 1.9.2. This is because debugging has been disabled in this release.


Detailed list of changes follows:

Bug fixes:
- Fixed Party bug where the bot would follow any random player 
  instead of the master
- isSelfSkill now works in monsterSkill blocks.
- Fixed homunculus_tankMode.
- Fixed inability to detect evolved homunculus state.
- Add Slim Pitcher to location skills list
- Skill timeout when runFromTarget is enabled fixed.
- Correctly support UTF-8 BOM characters.
- Correctly load skills.txt and avoid.txt as UTF-8.
- Fix sendQuitToCharSelect
- Fix Korean character encoding support.
- Fix kRO support.
- Fix vRO support.
- Fix support for FreeBSD, MacOS X and other Unix.
- Fix Sun Sparc support.
- Fix chat room creation.
- AutoSwitch will now not lose status effect like Twohand Quicken, when
  switching weapons.

New config options:
- dealAuto_names <list of player names>
	If non-empty and dealAuto is set to 2 or 3, then bot will only deal with
	players on the list. (Other players will be treated as dealAuto 0.)
- route_escape_shout <Message>
	Makes kore look "human like" during bot checks which involves warping people to
	maps without portals.
- pauseCharServer <seconds>
	similar to pauseMapServer, pause for a number of seconds before connecting to
	the char server
- shop_random <flag>
	<flag> may now be 1 (for the old behavior) or 2 (for improved shop
	list randomization). When set to 2, the shop list will first be mixed,
	then the list of items to sell will be generated. When set to 1, the
	the list of items to sell will first be generated, and then that
	list will be mixed.


New features:
- Basic support for rRO (serverType 13) (Without attack, sit, stand and skill use)
- Basic support for pRO Thor (serverType 12) (Without attack, sit, stand and skill use)
- Basic support for euRO (serverType 11) (Without attack, sit, stand and skill use)
- Added route_escape_shout <Message> to somewhat avoid gm bot check.
- It is now possible to enter special characters into the OpenKore console on Windows.
- It is now possible to use simple block labels in "conf" command.
- It is now possible to use monster IDs in mon_control.txt

New commands:
- top10 <b|a|t|p> | <black|alche|tk|pk> | <blacksmith|alchemist|taekwon|pvp>
	Displays the top 10 Blacksmiths, Alchemists, Taekwon and PVP ranks
- GM commands:
	gmb : Broadcast a global message.
	gmbb : Broadcast a global message in blue.
 	gmnb : Broadcast a nameless global message.
	gmlb : Broadcast a local message.
	gmlbb : Broadcast a local message in blue.
	gmnlb : Broadcast a nameless local message.
	gmmapmove : Move to the specified map.
	gmcreate : Create items or monsters.
	gmhide : Toggle perfect GM hide.
	gmwarpto : Warp to a player.
	gmsummon : Summon a player to you.
	gmdc : Disconnect a player AID.
	gmresetskill : Reset your skills.
	gmresetstate : Reset your stats.
	gmmute : Increase player mute time.
	gmunmute : Decrease player mute time.
	gmkillall : Disconnect all users.

Internal:
- Changed bRO server to use Secure Login
- Implemented Guild Kick / Guild Leave messages
- A new, object-oriented framework for message sending has been implemented.
- The beginning of a new, object-oriented task framework has been implemented.
  This will eventually replace the old AI framework.
- The IPC framework has been entirely replaced by the OpenKore bus system.


=========================
### OpenKore 1.9.2 (beta)
=========================

*** INCOMPATIBLE CHANGES ***:
- You need to download the latest responses.txt (in the config pack)
  to use the new 'exp' and 'version' chat commands.

Credits:
- Molag: Ayothaya portals contributions.
- DarkShado: XileRO server information updates.
- johnny: Homunculus skills.
- piroJOKE: field file contributions.
- cloud2squall: server information contributions.
- n0rd: support for compressed field files.
- Darkfate: partial serverType 11 (euRO) support
- natz: updated Receive.pm guild info

Bug fixes:
- Fixed a crash when unequipping items (bug #16)
- Fixed an auto-completion crash bug (bug #24)
- Fixed the "Can't store CODE items" bug (bug #37)

New features:
- Added AI::Homunculus module for homunculus AI support with automated
	homunculus feeding, following, and attacking (see new config options and
	commands).
- Support for homunculus skills in skills.txt (use normal skill blocks to use
	them).
- Add support for new vRO. Use serverType 10.
- Added teleportAuto_lostTarget, teleport when target is lost.
- Added a mob-training control. Use attack flag 3 in mon_control.txt to
	activate this. More details are available at:
	http://forums.openkore.com/viewtopic.php?p=134002
- Added command chaining, preform multiple commands in 1 line. the " ; "
	character is used to delimit the command.s
	Example: c watch out im using an item now;is 0;c see, i used it!
- Added Aegis 10.4 new classes support.
- Added Taekwon mission support.
- Added manualAI Where autoskills could be executed in ai manual mode.
	for more information : http://forums.openkore.com/viewtopic.php?t=24513

New config options:
- attackChangeTarget <boolean flag>
	automatically change target to an aggressive monster if the target monster
	is not yet reached or damaged. This prevents you from continuously routing
	to your target while dragging a mob of aggressive monsters behind you.
- homunculus_followDistanceMax <distance>
- homunculus_followDistanceMin <distance>
	Kore and the homunculus will always try to keep within these distances from
	each other.
- homunculus_attackAuto <flag>
- homunculus_attackAuto_party <flag>
- homunculus_attackAuto_notInTown <boolean flag>
- homunculus_attackAuto_onlyWhenSafe <boolean flag>
- homunculus_attackDistance <distance>
- homunculus_attackMaxDistance <distance>
- homunculus_attackMaxRouteTime <seconds>
- homunculus_attackMinPlayerDistance <distance>
- homunculus_attackMinPortalDistance <distance>
- homunculus_attackCanSnipe <boolean flag>
- homunculus_attackCheckLOS <boolean flag>
- homunculus_attackNoGiveup <boolean flag>
	same as the attackAuto* counterparts.
- homunculus_attackChangeTarget <boolean flag>
	same as attackChangeTarget.
- homunculus_route_step <number>
	this option is required or your homunculus will not be able to move.
- homunculus_runFromTarget <boolean flag>
- homunculus_runFromTarget_dist <distance>
	these will mostly be not needed but they are still included for posterity.
- homunculus_tankMode <boolean flag>
- homunculus_tankModeTarget <player name>
	same as the tankMode* counterparts. You can use this so that your
	homunculus can tank you. Set homunculus_tankModeTarget to your character
	name.
- homunculus_teleportAuto_deadly <boolean flag>
- homunculus_teleportAuto_dropTarget <boolean flag>
- homunculus_teleportAuto_dropTargetKS <boolean flag>
- homunculus_teleportAuto_hp <percent hp>
- homunculus_teleportAuto_maxDmg <damage>
- homunculus_teleportAuto_maxDmgInLock <damage>
- homunculus_teleportAuto_totalDmg <damage>
- homunculus_teleportAuto_totalDmgInLock <damage>
- homunculus_teleportAuto_unstuck <boolean flag>
	same as the teleportAuto* counterparts.
- Shared Block Attributes: homunculus_hp <hp>[%] and homunculus_sp <sp>[%]
	same as the hp/sp block attributes. These are useful for using homunculus
	skills on your skill blocks.
- teleportAuto_lostHomunculus <boolean flag>
    instead of routing back to your lost homunculus (default), Kore will
	teleport to get the homunculus back.
- Shared Block Attribute: homunculus_dead <boolean flag>
	triggers the config block only if your homunculus died.
- teleportAuto_lostTarget <boolean flag>
	Makes the bot (attempt to) teleport after it lost its target, this to
	prevent it from locking onto the same target over and over in some cases.
- ignoreServerShutdown <boolean flag>
	Ignores the "server shutting down" error wich some servers tend to send
	(iRO for example).
	Don't use this unless you're 100% sure the errors are "fake".
- Shared Block Attribute: manualAI <flag>
	flag 0    auto only
	flag 1    manual only
	flag 2    auto or manual

New sys.txt options:
- sendAnonymousStatisticReport <boolean flag>
    tells whether OpenKore will report an anonymous usage report. Note that
	none of your sensitive information will be sent. More info is available at:
	http://www.openkore.com/statistics.php

New commands:
- homun <s|status|feed|move|standby|ai|aiv|skills>
	homun s       : displays homunculus status.
	homun feed    : manually feeds homunculus.
	homun move    : basic homunculus move command (similar to 'move' command).
	homun standby : basic homunculus standby command.
	homun ai      : homunculus AI management (similar to 'ai' command).
	homun aiv     : displays homunculus AI sequences.
	homun skills  : homunculus skills management (similar to 'skills' command).

New chat commands:
- exp [item|monster]
	behaves like the 'exp' console command, but it is used as a chat
	command.
	exp         : shows exp gain.
	exp item    : shows items gain.
	exp monster : shows killed monsters.
- version
	shows the OpenKore version.

Incompatible Changes:
- ; command separator replaced with ;;, so you can now use semicolons
	in chat (as long as they're not two in a row).

Internal:
- Updated $config{gameGuard} '2' behavior to adapt to bRO server.
- The Console::Other interface has been removed in favor of the Console::Unix
	interface. This only affects OpenKore when running on a Unix, such as
	Linux.
- Item has been renamed to Actor::Item for consistency.
- Receive.pm : monk_spirits is now known as revolving_entity
- Added Bullet support
- New 'disconnected' plugin hook, called when you get disconnected
	from the map server

--------------------------

For older news, please read:
http://www.openkore.com/misc/OldNews.txt
