#######  PLUGIN WAIT4PARTY #######

Wait4Party v1.5 rev a -- Stick Together Team!
©2008 by Contrad

This software is open source, licensed under the GNU General Public
License, version 3.
Basically, this means that you're allowed to modify and/or distribute
this software. However, if you distribute modified versions, you MUST
also distribute the source code.
See <http://www.gnu.org/licenses/> for the full license.
Copy the plugin to the plugins folder on openkore
open sys.txt (control folder ) and change:


USE:
wait4party is used to make master wait for slave when it stopped for any reason
maybe casting a skill , or sitting, it will wait for slave.
solves most problems of "lose master , calculating route to" and other stuffs
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
loadPlugins_list macro,profiles,breakTime,raiseStat,raiseSkill,map,reconnect,eventMacro,wait4party #add wait4party here

How to use :
<config.txt>
wait4party (<boolean flag>)        
  Wait4Party On or Off

wait4party_sameMapOnly (<boolean flag>)      
  Only activate if the party member are in the same map

wait4party_waitBySitting (<boolean flag>)  
  Don't search, just sit and wait

wait4party_attackOnSearch (0|1|2)
  0 = No; 1 = Retaliate; 2 = Yes
  Attacking monster when searching member

wait4party_followSit (<boolean flag>)      
  Sitting when party is sitting. ATTENTION! Turn OFF 'followSitAuto' on slave or they'll sit forever!

Jan 5, 2010 ~ Blackmail
use AI_pre hooks ^^
Add Features:
wait4party_ignore [<player names>]
  ignore (comma-separated list of) player names if you lost them.

wait4party_timeout [<seconds>]
  If timeout is exceeded and party doesn't appear on screen, master will search for the missing party.

wait4party_cast [<skills>]
  Wait if party cast (comma-separated list of) skills.

Sep 11, 2010 : add sub emulateCmdSit, fix wait4party_followSit
Oct 22, 2010 : change %field into $field


EXAMPLE:

wait4party 1
wait4party_sameMapOnly 0
wait4party_waitBySitting 0
wait4party_attackOnSearch 1
wait4party_followSit 0
wait4party_ignore
wait4party_timeout 1
wait4party_cast Assumptio, Magnificat, Increase Agility, Angelus, Kyrie Eleison

