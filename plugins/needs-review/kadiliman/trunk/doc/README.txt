AUTHOR: kaliwanagan & Mucilon
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=22


INSTALLATION:
---------------
1) Download the 2 files.
2) Copy the kadiliman.pl file to openkoreroot\plugins directory.
3) Create a directory named Chatbot at openkoreroot\src directory.
4) Copy the Kadiliman.pm file to this Chatbot directory.
5) At config.txt see below at how to use.



EXAMPLE:
--------
chatBot Kadiliman {
       inLockOnly 1      # (0|1) Just answer to public chat at lockmap, pm will be answered normally
       scriptfile lines.txt   # Name of the file where all sentences are storage, it will be create at openkore root directory
       replyRate 80      # (0..100) Rate to answer, 80 means: answer 80% of chats and don't answer 20%
       onPublicChat 1      # (0|1) Enable to answer any plublic chat
       onPrivateMessage 1   # (0|1) Enable to answer any private message
       onSystemChat 1      # (0|1) Enable to answer any system message
       onGuildChat 1      # (0|1) Enable to answer any guild chat
       onPartyChat 1      # (0|1) Enable to answer any party chat
       wpm 65      # Don't need to change - words per minute, simulate typing speed
       smileys ^_^,xD,^^,:),XD   # Smileys that may end your sentences on chat (separeted by commas)
       smileyRate 20      # Rate to add smiley to the sentences, means: add smileys to 20% of messages
       learn 1      # This plugin can "learn" every sentence read by the bot, this sentences are storage at the scriptfile
       noPlayers , ,      # Name of the players (supported by regexp) you don't want to answer any thing, like party members (separeted by commas)
       noWords  , , ,       # Words (supported by regexp) at the chats you don't want to answer, like "bot", "heal", "buffs" or something like this (separeted by commas)
       timesToBlockPM 10   # Number of times of pms received by each player to ignore him, work just to pm
       timeToResetCount 300   # Number of seconds to reset the count to ignore any player, with zero it won't reset
}
