NAME: auto-refine
AUTHOR: Bibian
COMPABILITY: OpenKore v.2.0.6(revision 6400) or later
LICENCE: This plugin is licensed under the GNU GPL
COPYRIGHT: Copyright 2006 by hakore
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=198



What does it do?
----------------
This plugin refines the defined item at the defined NPC to the maxRefine number,
 it also walks to the defined NPC and gets within a 10 block radius.



What does it NOT do?
--------------------
It does not automaticly restock on elunium, oridecon or other metals nor does it auto-restock on items you wish to upgrade.
 You'll have to write a macro for that or use the internal autoGet/Buy/Storage



Are there bugs?
---------------
Im sure there are, i'v tested it in a controlled enviroment and i fixed the bugs i came across...
 so if you come across any, please report them and/or fix them (but rememeber to share).



What improvements are needed?
-----------------------------
Well... i guess the code can be neater, automaticly choosing the correct sequence would be cool too. 
Identifying items that are not yet identified is required, i didnt put that in yet cause i need a break now
At the moment the bot just stands there when its done, out of metal or out of items to refine, 
this should change too. Im not sure to what though

It only accepts 1 block at the moment.
If you specify Muffler [1] it will ONLY upgrade those and NOT +1 Muffer [1], 
this is because the name changes when you upgrade an item making it harder to use getByName.

cause you have to first get a list of all items, then find where this item is located in the menu...
although i MIGHT be able to use the itemType to determine where a particular item will be put...
But for classes that can dualwield or for accessories 
(im not sure if there are any accessories you can upgrade) its harder.


Config:
-------
Code:
autoRefine <item> {
   refineStone <elunium, oridecon, etc>
   refineNpc <npc map x y>
   npcSequence <talk sequence>
   zenny <amount>
   maxRefine <max +>
}



Example:
--------
Code:
autoRefine Shoes [1] {
   refineStone Elunium
   refineNpc prt_in 63 60
   npcSequence c r5 c r0 c w1 c w1 r0 w1 c c n
   zenny 3000
   maxRefine 9
   disabled 0
}

This config block will (attemp to) refine all the mufflers in your inventory to +9
using elunium at the prontera refiner as long as you have 300 zenny.



Appendix:
---------
NOTE: In the latest version you have to add the ENTIRE sequence, 
even the sequence you get when the NPC warns you the item can break!

NOTE 2: put "w1" between each command if the npc does not respond to certain commands, 
like it did on my test server. In this case Kore is sending the commands too fast for the NPC. 
This usually happens when the refiner warns you that the item can break!
