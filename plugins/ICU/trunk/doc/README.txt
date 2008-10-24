NAME: ICU 0.2.3
COMPABILITY: OpenKore v.2.0.5 (revision 6079) or later
LICENCE: This plugin is licensed under the GNU GPL
COPYRIGHT: Copyright 2008 by Bibian
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=1180



IMPORTANT
---------
This plugin is designed to detect forced teleports by GM's (for now), at the moment this is all it does. 
It still detects that going through a portal or using an NPC to warp is an unauthorized teleport. 
This will be fixed (hopefully) soon.



CONFIGURATION
-------------
open your config.txt and add

icu {
   teleportDetect 0 / 1
   teleportCommands command 1, command 2, etc
   teleportSound <path to .wav>

   skillOnSelfDetect 0 / 1
   groundSkillDistance <int> (blockDistance a ground skill has to be to trigger the commands)
   skillOnSelfCommands command 1, etc
   skillOnSelfSound <sound>

   commandTimeout <int> (Wait X seconds before executing next command)
   log 0 / 1
}


Example:
--------

icu {
   teleportDetect 1
   teleportCommands ai off, c wth?, e hmm
   teleportSound C:\sounds\TeleportAlert.wav

   skillOnSelfDetect 1
   groundSkillDistance 4
   skillOnSelfCommands ai off, c uhm?
   skillOnSelfSound C:\sounds\SkillAlert.wav

   commandTimeout 2
   log 1
}

The above config will detect heals on YOU, YOU being teleported,
 Groundskills being cast NEAR you and run the commands it is configed to.



Why?
----
Cause someone said, and i quote, "not that you that skilled as you think"...
 well guess what? i am Very Happy


