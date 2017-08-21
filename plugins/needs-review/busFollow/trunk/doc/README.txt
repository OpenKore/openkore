USE:

busFollow is ideal for a party of master and slave, because it improves a lot the checking of the current place of master
and helps finding him
it doesn't follow him when the slave is autostoraging, or autobuying and that stuff 
VERY RECOMMENDED for party of master and slave


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
loadPlugins_list macro,profiles,breakTime,raiseStat,raiseSkill,map,reconnect,eventMacro,busFollow #add busFollow here

OPTIONAL:
go in timeout.txt in control folder, and insert the following line:

busFollow_sendInfo [number]

Where number represents the number of seconds between each info sended by plugin. Default value is 1.
Ex.: busFollow_sendInfo 2


This plugin needs no more configurations, as soon you do the steps above, it will start work.