NAME: reactOnNPC v.1.1.1
COMPABILITY: Openkore v.1.6.6 or later
LICENCE: This plugin is licensed under the GNU GPL
COPYRIGHT: Copyright 2006 by hakore
TOPIC: http://bibian.ath.cx/openkore/viewtopic.php?t=19973

Introduction:
-------------
This plugin will make you automatically execute commands on an NPC conversation. 
This is particularly useful on forced NPC conversations such as that which is used 
by the Anti-bot System in AndzRO.



Example:
--------
You are now: Auto Berserk
You are now: Gloria
You are now: Angelus
You are now: Kyrie Eleison
You are now: Endure
You are now: Auto Guard
You are now: Kaite
Unknown #110009789: [Anti-bot System]
: 10 WRONG ANSWERS WILL RESULT IN BAN!
: 10 respostas erradas resultarão em ban!
: 10 respuestas equivocadas resultaran en ban!
: Auto-continuing talking
: ANSWER THIS CORRECTLY OR BANNED!
: 8
: + (PLUS)
: 5
: = ?
: Auto-continuing talking
NPC Exists: Unknown 110009789 (104, 122) (ID 110009789) - (0)
Unknown 110009789: Type 'talk num <number>' to input a number.
[reactOnNPC] Reacting to NPC. Executing command "talk num 13".
You are no longer: Auto Berserk
You are no longer: Gloria
You are no longer: Angelus
You are no longer: Kyrie Eleison
You are no longer: Endure
You are no longer: Auto Guard
You are no longer: Kaite
AntiBot: [Anti-bot System]
AntiBot: Thanks for cooperation.
AntiBot: Done talking



Instructions:
-------------
1) Place this plugin in your plugins folder (see the Plugins FAQ how).
2) Add a reactOnNPC config block in your config.txt which defines the command 
   to use and the conditions of the NPC conversation which will trigger Openkore to use the command



Configuration:
--------------
reactOnNPC (command)
This option specifies the command to use if all conditions are met for this block.
Special keywords can be used on the specified commands (see below)


Attribute definitions:
* type (close|continue|number|responses|text)

This attribute specifies what type of NPC conversation will trigger this block.
1. close - The NPC message box has the "close" button.
2. continue - The NPC message box has the "next" button.
3. number - The NPC shows a number input box.
4. responses - The NPC shows a list of responses.
5. text - The NPC shows a text input box.

Note: If this option is not specified, the block will be triggered on any type of NPC conversation.


* msg_(number) (message|regexp)

This is a list of attributes that specifies the lines of messages that should be checked on the NPC conversation. The number starts from 0 and increses in increments of 1.

You can specify either a simple message or a regexp.


*useColors (boolean flag) v.1.1.0

By default, matching of NPC messages with the specified patterns on the msg_ attributes exclues the color codes (e.g. ^FF0000). If this attribute is set to 1, the pattern matching will include the color codes so you can inspect these codes on the process.


*Shared self conditions

This block uses the shared self conditions (see the openkore manual).



Special command keywords:
-------------------------

@eval(expression)
This keyword can be used to evaluate simple expressions (e.g. math equations).


@resp(pattern) v.1.1.0
This keyword can be used to search the response list for certain patterns and return the index of the found response. This is particularly useful for dynamically changing response list.

The pattern can be a simple string or a regexp.


#(line number)~(match index)
If you use capturing parenthsis in the regexp you specified on a msg_# attribute, 
this keyword will be resolved to the value of the captured string. 
The line number corresponds to the number of the msg_# attribute where the regexp is used, 
while the match index corresponds to the index of the captured string.



Nesting command keywords: v.1.1.0
-------------------------
As of version 1.1.0, you can nest keywords like @resp(@eval(...)). 
Note however that the characters "@" and ")" are metacharacters and cannot be used normally inside the keywords. 
If you need to include such metacharacters in your keyword, escape them by preceding these characters with the "@" character (e.g. "@@, "@)").



examples:
---------
If you think the plugin does not respond to your NPC, 
you may have misconfigured your reactOnNPC block. 
Set debug to 1 in your config.txt and read how the reactOnNPC 
plugin works whenever you talk to the NPC.


DISCLAIMER

THIS PLUGIN IS DISTRIBUTED "AS IS" AND WITHOUT WARRANTIES AS TO PERFORMANCE OF MERCHANTABILITY OR ANY OTHER WARRANTIES WHETHER EXPRESSED OR IMPLIED. NO WARRANTY OF FITNESS FOR A PARTICULAR PURPOSE IS OFFERED.
THE USER MUST ASSUME THE ENTIRE RISK OF USING THE PLUGIN. 


The following example is the currently used NPC conversation of the AndzRO Anti-bot System.
Use type number because the NPC asks for a numeric input. 
The 5 lines of messages are specified on the msg_# attributes with the 2nd and 4th lines using a regexp to 
capture the numbers. The command that will be used contains the keyword @eval() to add the captured numbers.

Code: 
reactOnNPC talk num @eval(#1~1 + #3~1) {
	type number
	msg_0 ANSWER THIS CORRECTLY OR BANNED!
	msg_1 /^(\d+)$/
	msg_2 + (PLUS)
	msg_3 /^(\d+)$/
	msg_4 = ?
}
 
