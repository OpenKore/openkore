Posted by kaliwanagan
I've modified Joseph's plugin.
The latest version is in SVN. Please do not ask how to get SVN - learn how to use search and look at the documentation.

https://openkore.svn.sourceforge.net/sv ... xchange.pl

itemExchange - the item you wish to be exchanged
npc - the complete npc location who does the exchange
distance - distance from the npc
steps - talk sequence (look up the manual for a list of those sequences)
requiredAmount - how many of the item is needed for a successful exchange
triggerAmount - automatically do an exchange once item reaches this amount in inventory
respawnFirst - respawn first before routing to the npc

Additionally, you can force an item exchange by typing
Quote:
itemexchange

at the console.

Last edited by kaliwanagan on Sat Mar 04, 2006 12:27 pm; edited 9 times in total