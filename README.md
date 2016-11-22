# eventMacro
My personal rework of openkore's macro plugin

TODO:

1 - Create more conditions, at least the same number as the old macro plugin had.
2 - Hook AI only when we are sure an automacro is to be activated.
3 - Make slot system for automacros and macros, so in each slot a macro can be run and a group of automacros can be checked (so multiple macros can be run at the same time).
4 - Transfer macro code check to parsing time.
5 - Create a solution for when we get DC'ed during macro runtime (iMike macroStability?).
6 - Create an automacro parameter to determine when the macro should be checked (AI_pre/manual, AI_pre, AI_pos, etc).
7 - Discuss if mainLoop_pre really is the best hook to run macro commands in.
8 - Review macro condition code parsing (old Parser.pm and Script.pm)
9 - Pull request this project to openkore offical github so it can be analyzed by openkore community

1.1 - A list of condition I think of creating and their probable condition types:
Event-type
mapchange - inList
spell - inList
area_spell - inList
pm - simple/double regex +- distance
pub - simple/double regex +- distance
guildmsg - simple/double regex +- distance
partymsg - simple/double regex +- distance
localmessage - simple/double regex +- distance
systemmsg - simple/double regex +- distance



State-type
map - inList
coordinates - Numeric
location - inList + Numeric
spirit - Numeric
zenny - Numeric
equipped - Simplecheck
soldout - inList
status - inList
inventory - inList + Numeric
storage - inList + Numeric
cart - inList + Numeric
shop - inList + Numeric
class - inList
player - simple regex +- distance
npc - simple regex +- distance
monster - simple regex +- distance
whenground - inList
localtime - Numeric?
progress bar - simpleCheck
skilllvl - inList + Numeric
cash - Numeric
config - simpleCheck
quest - Complex
char - simpleCheck
plugin - simpleCheck
