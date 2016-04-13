AUTHOR: windows98SE@thaikore
http://forums.openkore.com/viewtopic.php?f=34&t=575

What it does:
-------------
You use it for response BotKiller #1 - Method 4: ASCII number, working together to the hakore's reactOnNPC plugin.
(http://eathena.ws/board/index.php?showtopic=120522)

How to install:
----------------
1) Place this plugin in your plugins folder (see the Plugins FAQ how or macro plugin manual at my signature).
2) Don't forget to also download the reactOnNPC plugin and place it at the plugins folder, without it won't work!
3) Add a reactOnNPC config block in your config.txt which defines the command to use and the conditions of the NPC conversation which will trigger Openkore to use the command.


How to use:
-----------
At config.txt use this:

Code:
ASCIInumberKiller {
	lengthCharNumber 8
	BgColor ^[B-Fb-f][A-Fa-f0-9][D-Fd-f][A-Fa-f0-9]{3}
}

Where:
lengthCharNumber = length of characters at each line of each number
BgColor = background color pattern of your server, you can use other colors like this:
BgColor ^[D-Fd-f][A-Fa-f0-9][D-Fd-f][A-Fa-f0-9]{3}|^FFFFFF|^FFFFFA|code hexcolor you server|color_brabra|..
Just the background color pattern ^[D-Fd-f][A-Fa-f0-9][D-Fd-f][A-Fa-f0-9]{3} will work for most of the servers.
The operator | is the operator or, so you can add other color codes at your will. Don't forget to use the ^ at the begining.
If you tried some codes and you still can't read clearly the numbers, post your console, so I can create another color pattern to your server.

And something like this: (still at config.txt file)

Code:
#Use this when you need to answer a number
reactOnNPC ASCIInumberKiller num {
	type number
	msg_0 /[#=]*/
	msg_1 /[#=]*/
	msg_2 /[#=]*/
	msg_3 /[#=]*/
	msg_4 /[#=]*/
	msg_5 /[#=]*/
	msg_6 /[#=]*/
}

#Use this when you need to answer a text
reactOnNPC ASCIInumberKiller text {
	type text
	msg_0 /[#=]*/
	msg_1 /[#=]*/
	msg_2 /[#=]*/
	msg_3 /[#=]*/
	msg_4 /[#=]*/
	msg_5 /[#=]*/
	msg_6 /[#=]*/
}


Appendix 1:
---------
TIP 1: You can find useful information about HEX code colors at: http://www.drpeterjones.com/colorcalc/
TIP 2: If after all, your bot got the error Error in function 'talk num' (Respond to NPC). You must specify a number, this means that you need to input your server's numbers to the plugin, so there is a mini Tutorial of how input your server numbers to the plugin file.
TIP 3: And if you can't see any number at your console, you probable forgot to add the ASCIInumberKiller block at your config.txt file.
TIP 4: You can find useful information about regexp (the code used to compare the colors) at the quick regexp tutorial or at the complete regexp tutorial. Regexp = Perl Regular Expression.
TIP 5: Beware, during the procedure of inputing your server's numbers to the plugin, you may lost some accounts banned or chars jailed to get the correct number and / or letters.

Appendix 2:
---------
Here we must take into account the peculiarity of the plugin. He is looking for numbers, consisting of 5 lines, and in your NPC is used 7 lines:
1: @@@@@@@@@@@@==@@@@@@@@@@@@@@@@@@@@@
2: @@@@@@@@@@@@==@@@@==@@@@@@@@@@@@@@@
3: ############==####==###############
4: ############==####==###############
5: ############=========##############
6: ##################==###############
7: ##################==###############

1: ############========###############
2: ############==####==###############
3: ################==#################
4: ###############==##################
5: ###############==##################
6: @@@@@@@@@@@@@@@==@@@@@@@@@@@@@@@@@@
7: @@@@@@@@@@@@@@@==@@@@@@@@@@@@@@@@@@

But you can use a trick! You can cut our numbers up to 5 lines (above, below or one line from above and one line from below - it does not matter):
3: ############==####==###############
4: ############==####==###############
5: ############=========##############
6: ##################==###############
7: ##################==###############

1: ############========###############
2: ############==####==###############
3: ################==#################
4: ###############==##################
5: ###############==##################

Then need to select our number consisting of 5 lines and 9 characters:
3: 			   ==####==#
4: 			   ==####==#
5: 			   =========
6: 			   ######==#
7: 			   ######==#

1: 			   ========#
2: 			   ==####==#
3: 			   ####==###
4: 			   ###==####
5: 			   ###==####

Then convert that number in one line:
'==####==#==####==#=========######==#######==#' => 4,
'========#==####==#####==######==#######==####' => 7,