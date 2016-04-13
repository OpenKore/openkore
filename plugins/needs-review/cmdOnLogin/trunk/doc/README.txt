NAME: cmdOnLogin
COMPABILITY:
LICENCE: This plugin is licensed under the GNU GPL
COPYRIGHT: Copyright 2006 by hakore
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=695



Introduction:
-------------
This plugin executes commands upon login into the server.
Usefull for commands like @autoloot, @alootid, ...



Configuration:
--------------
in config.txt put

-for single command
cmdOnLogin command1

-for multiple commands
cmdOnLogin command1;;command2;;command3;;...

(separator = ;;)



EXAMPLE:
--------
2 commands
cmdOnLogin c @autoloot 1;;c @ali pearl
