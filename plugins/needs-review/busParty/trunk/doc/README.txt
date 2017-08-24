USE:
busParty is to improves the information openkore has of the others players of the party (that are also using openkore)
because it's using bus system, it cannot dectect players that are using normal ragnarok client.
VERY RECOMMENDED in partys bigger than 2, it is also useful for master and slave party

How to Install:
Copy the plugin to the plugins folder on openkore
open sys.txt (control folder ) and change:

###### Bus system settings ######
# Whether to enable the bus system.
bus 1   # MAKE SURE IT'S 1 


also, in sys.txt file, change:
loadPlugins 2

# loadPlugins_list <list>
#   if loadPlugins is set to 2, this comma-separated list of plugin names (filename without the extension)
#   specifies which plugin files to load at startup or when the "plugin load all" command is used.
loadPlugins_list macro,profiles,breakTime,raiseStat,raiseSkill,map,reconnect,eventMacro,busParty #add busParty here


This plugin needs no more configurations, as soon you do the steps above, it will start work.