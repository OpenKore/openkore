NAME: reactOnNPC v.2.0.0
COMPABILITY: OpenKore v.2.0.5.1 or later
LICENCE: This plugin is licensed under the GNU GPL
COPYRIGHT: Copyright 2006 by hakore
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=198

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


*delay (seconds) v.2.0.0
This specifies the number of seconds to wait before executing the command. (Recommended for anti-bot NPCs that marks the time of response.)


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

Harder example:
PROBLEM:
[Jan 15 09:20:26 2008.38] [reactOnNPC] NPC message saved (0): "[Bot Check]".
[Jan 15 09:20:26 2008.40] Unknown #110012575: [Bot Check]
[Jan 15 09:20:26 2008.42] [reactOnNPC] NPC message saved (1): "^000000^FFFFFF^000000Type: ^FFFFFF72033163522^0000007961^FFFFFF014582^000000".
[Jan 15 09:20:26 2008.44] Unknown #110012575: Type: 720331635227961014582
[Jan 15 09:20:26 2008.46] [reactOnNPC] NPC message saved (2): "^000000^FFFFFF^000000^FFFFFFType: ^FFFFFF247034^000000^FFFFFF993222^000000^FFFFFF412873^000000^FFFFFF^000000".
[Jan 15 09:20:26 2008.48] Unknown #110012575: Type: 247034993222412873
[Jan 15 09:20:26 2008.50] [reactOnNPC] NPC message saved (3): "^000000^FFFFFF^FFFFFF^FFFFFFType: ^FFFFFF392540^000000^FFFFFF588942^000000^FFFFFF672816^000000^FFFFFF^000000".
[Jan 15 09:20:26 2008.52] Unknown #110012575: Type: 392540588942672816
[Jan 15 09:20:26 2008.54] [reactOnNPC] NPC message saved (4): "^000000^FFFFFF^FFFFFFType: ^FFFFFF772995^000000^FFFFFF672463^000000^FFFFFF398865^000000^FFFFFF^000000".
[Jan 15 09:20:26 2008.86] Unknown #110012575: Type: 772995672463398865
[Jan 15 09:20:26 2008.89] NPC Exists: OnPCLoginEvent (313, 179) (ID 110012575) - (1)
[Jan 15 09:20:26 2008.91] [reactOnNPC] onNPCAction type is: number.
[Jan 15 09:20:26 2008.94] [reactOnNPC] Matching "[Bot Check]" to "You need to enter the code below:" (0)... [Jan 15 09:20:26 2008.97] doesn't match.
[Jan 15 09:20:26 2008.12] [reactOnNPC] One or more lines doesn't match for "reactOnNPC_0" (0).
[Jan 15 09:20:26 2008.13] OnPCLoginEvent: Type 'talk num <number #>' to input a number.
[Jan 15 09:20:27 2008.73] Calculating lockMap route to: Vally of Gyoll(nif_fild02)
[Jan 15 09:20:27 2008.73] On route to: Vally of Gyoll(nif_fild02): , 
[Jan 15 09:20:28 2008.39] CalcMapRoute - initialized.

SOLUTION:
reactOnNPC talk num @eval(my $color1 = #1~1;my $color2 = #2~1;my $color3 = #3~1;my $color4 = #4~1;my $number1 = #1~2;my $number2 = #2~2;my $number3 = #3~2;my $number4 = #4~2;my $numberout = 0; if ($color1 eq '^000000'@) {$numberout = $number1;} if ($color2 eq '^000000'@) {$numberout = $number2;} if ($color3 eq '^000000'@) {$numberout = $number3;} if ($color4 eq '^000000'@) {$numberout = $number4;} my @@colors = split /\^/,$numberout; my $anwser = ''; foreach my $number (@@colors@) { if ($number eq /000000(\d+@)/@) {$anwser .= $1;}} return $anwser;){
        type number
        useColors 1
        msg_0 [Bot Check]
        msg_1 /(\^[0-9a-fA-F]{6})Type: (.+)/i
        msg_2 /(\^[0-9a-fA-F]{6})Type: (.+)/i
        msg_3 /(\^[0-9a-fA-F]{6})Type: (.+)/i
        msg_4 /(\^[0-9a-fA-F]{6})Type: (.+)/i
}



Appendix:
---------
TIP1: to know how regexp works, search in here: (perldoc.perl.org is my perl bible)

Quick regexp tutorial
http://perldoc.perl.org/perlrequick.html
Complete regexp tutorial
http://perldoc.perl.org/perlretut.html

TIP2:Search at the old forum, there are a lot of made configs in there.

If you think the plugin does not respond to your NPC, 
you may have misconfigured your reactOnNPC block. 
Set debug to 1 in your config.txt and read how the reactOnNPC 
plugin works whenever you talk to the NPC.



DISCLAIMER
----------
THIS PLUGIN IS DISTRIBUTED "AS IS" AND WITHOUT WARRANTIES AS TO PERFORMANCE OF MERCHANTABILITY OR ANY OTHER WARRANTIES WHETHER EXPRESSED OR IMPLIED. NO WARRANTY OF FITNESS FOR A PARTICULAR PURPOSE IS OFFERED.
THE USER MUST ASSUME THE ENTIRE RISK OF USING THE PLUGIN. 

