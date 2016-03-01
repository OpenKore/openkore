NAME: reactOnNPC v.2.0.2
COMPABILITY: OpenKore SVN 8855 or later
LICENCE: This plugin is licensed under the GNU GPL
COPYRIGHT: Copyright 2006 by hakore [mod by windows98SE and ya4ept]
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=198
DOWNLOAD: http://sourceforge.net/p/openkore/code/HEAD/tree/plugins/reactOnNPC/trunk/

-----------------
- Introduction: -
-----------------
This plugin will make you automatically execute commands on an NPC conversation. 
This is particularly useful on forced NPC conversations such as that which is used 
by the Anti-bot System in AndzRO.


------------
- Example: -
------------
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


-----------------
- Instructions: -
-----------------
1) Place this plugin in your plugins folder (see the Plugins FAQ how).
2) Add a reactOnNPC config block in your config.txt which defines the command 
   to use and the conditions of the NPC conversation which will trigger Openkore to use the command


------------------
- Configuration: -
------------------
# Example (put in config.txt):
#
# reactOnNPC_debug 1
# reactOnNPC talk text @eval(my $color1 = '#1~1';my $color2 = '#3~1';if ($color1 eq $color2@) {return '#3~2'}) {
#	type text
#	useColors 1
#	respIgnoreColor 1
#	delay 2
#	msg_0 /Bot Checking.../
#	msg_1 /Enter the \^([0-9a-fA-F]{6})RED COLOR\^000000 Code./
#	msg_2 /^\s$/
#	msg_3 /\s+\^([0-9a-fA-F]{6})(\S+)\^[0-9a-fA-F]{6}\s+/
# Shared SelfCondition (see http://openkore.com/index.php/Category:Self_Condition):
#	disabled 0
#	whenStatusActive 
#	whenStatusInactive
#	onAction
#	notOnAction
#	inMap
#	notInMap
#	inLockOnly
#	notInTown
#	timeout
#	notWhileSitting
#	manualAI
#	whenIdle
#	hp
#	sp
#	weight
#	zeny
#	spirit
#	amuletType
#	homunculus
#	homunculus_hp
#	homunculus_sp
#	homunculus_dead
#	homunculus_resting
#	mercenary
#	mercenary_hp
#	mercenary_sp
#	mercenary_whenStatusActive
#	mercenary_whenStatusInactive
#	aggressives
#	partyAggressives
#	stopWhenHit
#	whenFollowing
#	monstersCount
#	monsters
#	notMonsters
#	defendMonsters
#	inInventory
#	inCart
#	whenGround
#	whenNotGround
#	whenPermitSkill
#	whenNotPermitSkill
#	onlyWhenSafe
#	whenEquipped
#	whenNotEquipped
#	whenWater
#	equip_leftAccessory
#	equip_rightAccessory
#	equip_leftHand
#	equip_rightHand
#	equip_robe
#	whenFlag
#	whenNotFlag
# }

reactOnNPC_debug (boolean flag)
	This option enables the display of debug messages plugin

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

* useColors (boolean flag)
	By default, matching of NPC messages with the specified patterns on the msg_ attributes excludes the color codes (e.g. ^FF0000).
	If this attribute is set to 1, the pattern matching will include the color codes so you can inspect these codes on the process.

* respIgnoreColor (boolean flag)
	Remove RO color codes <npc response>

* delay (seconds)
	This specifies the number of seconds to wait before executing the command. (Recommended for anti-bot NPCs that marks the time of response.)


* msg_(number) (message|regexp)
	This is a list of attributes that specifies the lines of messages that should be checked on the NPC conversation.
	The number starts from 0 and increases in increments of 1.
	You can specify either a simple message or a regexp.
	
* Shared SelfCondition
	This block uses the shared self conditions (see the openkore manual).
	http://openkore.com/index.php/Category:Self_Condition


----------------------------
- Special command keywords:-
----------------------------

@eval(expression)
	This keyword can be used to evaluate simple expressions (e.g. math equations).


@resp(pattern) v.1.1.0
	This keyword can be used to search the response list for certain patterns and return the index of the found response.
	This is particularly useful for dynamically changing response list.
	The pattern can be a simple string or a regexp.


#(line number)~(match index)
	If you use capturing parenthesis in the regexp you specified on a msg_# attribute, 
	this keyword will be resolved to the value of the captured string. 
	The line number corresponds to the number of the msg_# attribute where the regexp is used, 
	while the match index corresponds to the index of the captured string.


-----------------------------
- Nesting command keywords: -
-----------------------------
As of version 1.1.0, you can nest keywords like @resp(@eval(...)). 
Note however that the characters "@" and ")" are metacharacters and cannot be used normally inside the keywords. 
If you need to include such metacharacters in your keyword, escape them by preceding these characters with the "@" character (e.g. "@@, "@)").


-------------
- Examples: -
-------------

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
	[reactOnNPC] NPC message saved (0): "[Bot Check]".
	Unknown #110012575: [Bot Check]
	[reactOnNPC] NPC message saved (1): "^000000^FFFFFF^000000Type: ^FFFFFF72033163522^0000007961^FFFFFF014582^000000".
	Unknown #110012575: Type: 720331635227961014582
	[reactOnNPC] NPC message saved (2): "^000000^FFFFFF^000000^FFFFFFType: ^FFFFFF247034^000000^FFFFFF993222^000000^FFFFFF412873^000000^FFFFFF^000000".
	Unknown #110012575: Type: 247034993222412873
	NPC message saved (3): "^000000^FFFFFF^FFFFFF^FFFFFFType: ^FFFFFF392540^000000^FFFFFF588942^000000^FFFFFF672816^000000^FFFFFF^000000".
	Unknown #110012575: Type: 392540588942672816
	[reactOnNPC] NPC message saved (4): "^000000^FFFFFF^FFFFFFType: ^FFFFFF772995^000000^FFFFFF672463^000000^FFFFFF398865^000000^FFFFFF^000000".
	Unknown #110012575: Type: 772995672463398865
	NPC Exists: OnPCLoginEvent (313, 179) (ID 110012575) - (1)
	[reactOnNPC] onNPCAction type is: number.
	[reactOnNPC] Matching "[Bot Check]" to "You need to enter the code below:" (0)... doesn't match.
	[reactOnNPC] One or more lines doesn't match for "reactOnNPC_0" (0).
	OnPCLoginEvent: Type 'talk num <number #>' to input a number.
	Calculating lockMap route to: Vally of Gyoll(nif_fild02)
	On route to: Vally of Gyoll(nif_fild02): , 
	CalcMapRoute - initialized.

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

------------
- Appendix:-
------------
TIP1: To know how regexp works, search in here: (perldoc.perl.org is my perl bible)
	Quick regexp tutorial
	http://perldoc.perl.org/perlrequick.html
	Complete regexp tutorial
	http://perldoc.perl.org/perlretut.html

TIP2: Search at the old forum, there are a lot of made configs in there.
	If you think the plugin does not respond to your NPC, 
	you may have misconfigured your reactOnNPC block. 
	Set debug to 1 in your config.txt and read how the reactOnNPC 
	plugin works whenever you talk to the NPC.

--------------
- DISCLAIMER -
--------------
THIS PLUGIN IS DISTRIBUTED "AS IS" AND WITHOUT WARRANTIES AS TO PERFORMANCE OF MERCHANTABILITY OR ANY OTHER WARRANTIES WHETHER EXPRESSED OR IMPLIED. NO WARRANTY OF FITNESS FOR A PARTICULAR PURPOSE IS OFFERED.
THE USER MUST ASSUME THE ENTIRE RISK OF USING THE PLUGIN. 


======================
= Example (CasperRO) =
======================
	NPC Exists: Gold Room (143, 169) (ID 111267256) - (2)
	----------Responses-----------
	#  Response
	0  Proceed
	1  Ignore
	2  Cancel Chat
	-------------------------------
	Gold Room: Type 'talk resp #' to choose a response.
	Gold Room: READ CAREFULLY
	Gold Room: This is the antiBot login
	Gold Room: Please enter the input number correctly ###### << if you see that .. and what is it color...enter the input number same as the ##### color
	Gold Room: Auto-continuing talking
	Gold Room: For Example
	Gold Room: ^ffff001021177^000000
	Gold Room: ^5500001009311^000000
	Gold Room: ^0000ff1014758^000000
	Gold Room: ^550000##########^000000
	Gold Room: So the answer would be
	Gold Room: 1009311, Because they are in the same color of ######
	Gold Room: So lets now Proceed to the anti-BOT
	Gold Room: Auto-continuing talking
	Gold Room: ^F8F8FF4355750^000000^FFA5007154336^000000^F7F7FF1581^000000^F5F9FD683^000000
	Gold Room: ^FFF9EE5010961^000000^A52A2A7489013^000000^F5F9FD1581^000000^FFF9EE683^000000
	Gold Room: ^F5F9FD9730339^000000^FF00007896091^000000^F7F7FF1581^000000^FFF9EE683^000000
	Gold Room: ^F8F8FF8184673^000000^0000FF1536013^000000^F5F9FD1581^000000^F5F9FD683^000000
	Gold Room: ^FFF9EE2116097^000000^0080001429644^000000^F5F9FD1581^000000^FFF9EE683^000000
	Gold Room: ^F5F9FD3373750^000000^9400D38887188^000000^F7F7FF1581^000000^F5F9FD683^000000
	Gold Room: 0#^FFF9EE###^0000FF #####^F8F8FF######^F5F9FD#^FFF9FA#^F7F7FF##
	Gold Room: Auto-continuing talking
	Gold Room: Type 'talk num <number #>' to input a number.
	Reacting to NPC. Executing command "talk num 1536013".
	Gold Room: Auto-continuing talking
	Gold Room: ^4233F4zxcv33^000000!
	Gold Room: Thanks For Entering the Number Correctly....
	Gold Room: Auto-continuing talking
	Map Change: force_1-1.gat (100, 100)

SOLUTION:
	reactOnNPC talk num @eval(my $color = '#6~1';$color = 'FF8C00' if($color eq 'FFA500'@);my @@array = ('#0~1','#0~2','#0~3','#0~4','#1~1','#1~2','#1~3','#1~4','#2~1','#2~2','#2~3','#2~4','#3~1','#3~2','#3~3','#3~4','#4~1','#4~2','#4~3','#4~4','#5~1','#5~2','#5~3','#5~4'@);my $answer = 1;for($i = 0; $i <= 24; $i++@) {if (@@array[$i] eq $color@) {$answer = @@array[$i+1]}}return $answer) {
		type number
		useColors 1
		delay 2
		msg_0 /\^[0-9a-fA-F]{6}\d+\^000000\^([0-9a-fA-F]{6})(\d+)\^000000\^([0-9a-fA-F]{6})(\d+)\^000000/
		msg_1 /\^[0-9a-fA-F]{6}\d+\^000000\^([0-9a-fA-F]{6})(\d+)\^000000\^([0-9a-fA-F]{6})(\d+)\^000000/
		msg_2 /\^[0-9a-fA-F]{6}\d+\^000000\^([0-9a-fA-F]{6})(\d+)\^000000\^([0-9a-fA-F]{6})(\d+)\^000000/
		msg_3 /\^[0-9a-fA-F]{6}\d+\^000000\^([0-9a-fA-F]{6})(\d+)\^000000\^([0-9a-fA-F]{6})(\d+)\^000000/
		msg_4 /\^[0-9a-fA-F]{6}\d+\^000000\^([0-9a-fA-F]{6})(\d+)\^000000\^([0-9a-fA-F]{6})(\d+)\^000000/
		msg_5 /\^[0-9a-fA-F]{6}\d+\^000000\^([0-9a-fA-F]{6})(\d+)\^000000\^([0-9a-fA-F]{6})(\d+)\^000000/
		msg_6 /0.*\^(0000FF|A52A2A|9400D3|FFA500|008000|FF0000)\s?#/
	}

=====================
= Example (VitalRO) =
=====================
	Gold Room: Do you want to go to Gold room ?
	Gold Room: It Will Cost You 1,000,000 Zeny
	----------Responses-----------
	#  Response
	0  Yes
	1  No
	2  Cancel Chat
	-------------------------------
	Gold Room: Type 'talk resp #' to choose a response.
	Gold Room: Auto-continuing talking
	Gold Room: Bot Checking...
	Gold Room: Enter the ^FF0000RED COLOR^000000 Code..
	Gold Room:
	Gold Room: ^0055FFiFO ^FF0000dq5C@xCmV^0055FF f*^000000
	Gold Room: Type 'talk text' (Respond to NPC)
	[reactOnNPC] Reacting to NPC. Executing command "talk text dq5C@xCmV".
	Gold Room: Auto-continuing talking
	Gold Room: Done,..you may proceed into Gold Room by paying ^FF00001000000 zeny.
	Gold Room: Done talking

SOLUTION:
	reactOnNPC talk text @eval(my $color1 = '#1~1';my $color2 = '#3~1';if ($color1 eq $color2@) {return '#3~2'}) {
		type text
		useColors 1
		delay 2
		msg_0 /Bot Checking.../
		msg_1 /Enter the \^([0-9a-fA-F]{6})RED COLOR\^000000 Code./
		msg_2 /^\s$/
		msg_3 /\s+\^([0-9a-fA-F]{6})(\S+)\^[0-9a-fA-F]{6}\s+/
	}

=======================
= Example (SpartanRO) =
=======================
	BotKiller Guard: For security reasons we must to interrogate you, please find a safe place. [5 sec.]
	Unknown #118383673: [Kafra]
	Unknown #118383673: >>> Who doesn't lie? <<<
	Unknown #118383673:
	Unknown #118383673: 1) udigurs: 'Your Job Level is 60'
	Unknown #118383673: 2) cafaju: 'Your Level is 255'
	Unknown #118383673: 3) rilitst: 'Your Max SP is 1468'
	Unknown #118383673: 4) fafele: 'Your Max HP is 51789'
	Unknown #118383673: Auto-continuing talking
	----------Responses-----------
	# Response
	0 fafele
	1 rilitst
	2 cafaju
	3 udigurs
	4 Cancel Chat
	-------------------------------
	Unknown #118383673: Type 'talk resp #' to choose a response.
	[reactOnNPC] Reacting to NPC. Executing command "talk resp 2".
	You are no longer: look: GM Perfect Hide
	You are no longer: look: Ruwach
	You are no longer: look: Orc Head
	[Guild] 100% of effectiveness.
	You are now: Increase Agility (Duration: 300s)

SOLUTION:
	reactOnNPC talk resp @resp(@eval(my @@a = ('#3~2','#4~2','#5~2','#6~2'@);my @@b = ('#3~6','#4~6','#5~6','#6~6'@);my @@c = ('#3~1','#4~1','#5~1','#6~1'@);my $anwser = 'error';for (my $z = 0; $z <= 3; $z++@) {if (@@a[$z] eq 'Level' && @@b[$z] == $::char->{lv}@) {$anwser = @@c[$z];}elsif (@@a[$z] eq 'Job Level' && @@b[$z] == $::char->{lv_job}@) {$anwser = @@c[$z];}elsif (@@a[$z] eq 'Max HP' && @@b[$z] == $::char->{hp_max}@) {$anwser = @@c[$z];}elsif (@@a[$z] eq 'Max SP' && @@b[$z] == $::char->{sp_max}@) {$anwser = @@c[$z];}}return $anwser;)) {
		type responses
		respIgnoreColor 1
		delay 5
		msg_0 /\[Kafra\]/
		msg_1 />>> Who doesn't lie\? <<</
		msg_2 /.*/
		msg_3 /\d\) (\w+): 'Your (Level|(Job Level)|(Max HP)|(Max SP)) is (\d+)'/
		msg_4 /\d\) (\w+): 'Your (Level|(Job Level)|(Max HP)|(Max SP)) is (\d+)'/
		msg_5 /\d\) (\w+): 'Your (Level|(Job Level)|(Max HP)|(Max SP)) is (\d+)'/
		msg_6 /\d\) (\w+): 'Your (Level|(Job Level)|(Max HP)|(Max SP)) is (\d+)'/
	}
	reactOnNPC talk resp @resp(@eval(my @@a = ('#3~2','#4~2','#5~2','#6~2'@);my @@b = ('#3~6','#4~6','#5~6','#6~6'@);my @@c = ('#3~1','#4~1','#5~1','#6~1'@);my $anwser = 'error';for (my $z = 0; $z <= 3; $z++@) {if (@@a[$z] eq 'Level' && @@b[$z] != $::char->{lv}@) {$anwser = @@c[$z];}elsif (@@a[$z] eq 'Job Level' && @@b[$z] != $::char->{lv_job}@) {$anwser = @@c[$z];}elsif (@@a[$z] eq 'Max HP' && @@b[$z] != $::char->{hp_max}@) {$anwser = @@c[$z];}elsif (@@a[$z] eq 'Max SP' && @@b[$z] != $::char->{sp_max}@) {$anwser = @@c[$z];}}return $anwser;)) {
		type responses
		respIgnoreColor 1
		delay 5
		msg_0 /\[Kafra\]/
		msg_1 />>> Who lies\? <<</
		msg_2 /.*/
		msg_3 /\d\) (\w+): 'Your (Level|(Job Level)|(Max HP)|(Max SP)) is (\d+)'/
		msg_4 /\d\) (\w+): 'Your (Level|(Job Level)|(Max HP)|(Max SP)) is (\d+)'/
		msg_5 /\d\) (\w+): 'Your (Level|(Job Level)|(Max HP)|(Max SP)) is (\d+)'/
		msg_6 /\d\) (\w+): 'Your (Level|(Job Level)|(Max HP)|(Max SP)) is (\d+)'/
	}

===========================
= Example (bbs.xy-ro.com) =
===========================
	You are now: state: Frozen
	You are now: look: GM Perfect Hide
	Unknown #110004319: If A1 is U, what is:J4(Uppercase)
	Unknown #110004319:    A B C D E F G H I J
	Unknown #110004319:  ---------Antibot---------
	Unknown #110004319: 1| U X J S M B T S W T
	Unknown #110004319: 2| V Y H W I V D V R E
	Unknown #110004319: 3| N O S Y C O M F Y C
	Unknown #110004319: 4| B M A F O E L V U W
	Unknown #110004319: Auto-continuing talking
	NPC Exists: Unknown #110004319 (153, 96) (ID 110004319) - (13)
	Unknown #110004319: Type 'talk text' (Respond to NPC)
	[reactOnNPC] Reacting to NPC. Executing command "talk text W".
	Unknown #110004319:  ---------Antibot---------
	Unknown #110004319: Congratulations, I wish you a happy game.
	You are no longer: state: Frozen
	You are no longer: look: GM Perfect Hide
	Unknown #110004319: Done talking

SOLUTION:
	reactOnNPC talk text @eval(my $a = '#0~1'; my $b = #0~2-1; my @@A =('#3~1', '#4~1', '#5~1', '#6~1'@); my @@B =('#3~2', '#4~2', '#5~2', '#6~2'@); my @@C =('#3~3', '#4~3', '#5~3', '#6~3'@); my @@D =('#3~4', '#4~4', '#5~4', '#6~4'@); my @@E =('#3~5', '#4~5', '#5~5', '#6~5'@); my @@F =('#3~6', '#4~6', '#5~6', '#6~6'@); my @@G =('#3~7', '#4~7', '#5~7', '#6~7'@); my @@H =('#3~8', '#4~8', '#5~8', '#6~8'@); my @@I =('#3~9', '#4~9', '#5~9', '#6~9'@); my @@J =('#3~10', '#4~10', '#5~10', '#6~10'@); my @@answer; if ($a eq 'A'@) {@@answer = @@A} elsif ($a eq 'B'@) {@@answer = @@B} elsif ($a eq 'C'@) {@@answer = @@C} elsif ($a eq 'D'@) {@@answer = @@D} elsif ($a eq 'E'@) {@@answer = @@E} elsif ($a eq 'F'@) {@@answer = @@F} elsif ($a eq 'G'@) {@@answer = @@G} elsif ($a eq 'H'@) {@@answer = @@H} elsif ($a eq 'I'@) {@@answer = @@I} elsif ($a eq 'J'@) {@@answer = @@J} return @@answer[$b]) {
		type text
		delay 2
		msg_0 /..A1..\w,......:(\w)(\d)\(..\)/
		msg_1 /. A.B.C.D.E.F.G.H.I.J/
		msg_2 /---------.......---------/
		msg_3 /1\| (\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w)/
		msg_4 /2\| (\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w)/
		msg_5 /3\| (\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w)/
		msg_6 /4\| (\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w).(\w)/
	}
