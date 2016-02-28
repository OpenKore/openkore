AUTHOR: windows98SE@thaikore

What it does:
-------------
You use it for response BotKiller #1 - Method 4: ASCII number, working together to the hakore's reactOnNPC plugin.
(http://www.eathena.ws/board/index.php?showtopic=120522)
Version of Openkore Required: OpenKore 1.9.x (tested in Opk 2.0.5.1)



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
BgColor ^[D-Fd-f][A-Fa-f0-9][D-Fd-f][A-Fa-f0-9]{3}
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
      msg_0 /.*/
      msg_1 /.*/
      msg_2 /.*/
      msg_3 /.*/
}

#Use this when you need to answer a text
reactOnNPC ASCIInumberKiller text {
   type text
      msg_0 /.*/
      msg_1 /.*/
      msg_2 /.*/
      msg_3 /.*/
}



Appendix:
---------
TIP 1: You can find useful information about HEX code colors at: http://www.drpeterjones.com/colorcalc/
TIP 2: If after all, your bot got the error Error in function 'talk num' (Respond to NPC). You must specify a number, this means that you need to input your server's numbers to the plugin, so there is a mini Tutorial of how input your server numbers to the plugin file.
TIP 3: And if you can't see any number at your console, you probable forgot to add the ASCIInumberKiller block at your config.txt file.
TIP 4: You can find useful information about regexp (the code used to compare the colors) at the quick regexp tutorial or at the complete regexp tutorial. Regexp = Perl Regular Expression.
TIP 5: Beware, during the procedure of inputing your server's numbers to the plugin, you may lost some accounts banned or chars jailed to get the correct number and / or letters.
