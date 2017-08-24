README made by Nipodemos

This software is open source, licensed under the GNU General Public
License, version 3.
Basically, this means that you're allowed to modify and/or distribute
this software. However, if you distribute modified versions, you MUST
also distribute the source code.
See <http://www.gnu.org/licenses/> for the full license.


Use:
 
You can send console commands to other openkore clients open.
You can specify char name or send to all, or send to all there is in a specific field.

 
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
loadPlugins_list macro,profiles,breakTime,raiseStat,raiseSkill,map,reconnect,eventMacro,busCommands #add busCommands here


How to use:

in console type:
bus (charName|all|field) (command)

OR

busmsg (charName|all|field) (message)

When you use bus, it will send the console command and execute.
When you use busmsg, it will send the message that can be handled in macros.
 
Example 1:
Make all bots in prt_fild08 store:
bus prt_fild08 autostorage 

Example 2:
Make all your bots change lockMap:
bus all conf lockMap pay_fild08

Example 3:
Make a specific char talk to kafra:
bus charName talknpc 151 29 c r1
bus nipodemos talknpc 151 29 c r1

Ps: it can be any console command


Example 4:
Send a message to all your bots that GM is close:
busmsg all GM near

Example 5:
Make bots activate a macro that deal to merchant and gives all loot:
busmsg all give it to me

 
Handling busCommands messages in macros:
 
If you are using macro plugin, it can be done that way:
automacro testBus {
    hook bus_received
    save message
    call {
        #The message has to be treated here, to knows which message are and what to do with it
        #More complicated in my opinion (especially if you set up multiple messages)
        log just received message $.hookSave0 from busCommands 
        if ($.hookSave0 = GM near) do quit
		if ($.hookSave0 = give it to me) call giveItens
    }
}

If you are using eventMacro plugin, it can be done that way:
automacro testBusEvent {
    BusMsg /GM near/ #or any other message, this way you can do one automacro per message, much better
    call {
        log Just received message $.BusMsgLastMsg from busCommands
        do quit # example
    }
}

Limitation:

Windows has a limit of 60 +- to bus, which means you can run "only" 60 bots using bus.

