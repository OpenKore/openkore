AUTHOR: abt123
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=1071


What it does:
-------------
You use it for response BotKiller #1 - Method 2: Image Numbers or Texts, working together to the hakore's reactOnNPC plugin.
(http://www.eathena.ws/board/index.php?showtopic=120522)


How to install:
-------------
1) Place this plugin in your plugins folder (see the Plugins FAQ how or macro plugin manual).
2) Don't forget to also download the reactOnNPC plugin and place it at the plugins folder, without it won't work!
3) Add a reactOnNPC config block in your config.txt file which defines the command to use and the conditions of the NPC conversation which will trigger Openkore to use the command.
4) Open the "responseOnNPCImage.pl" file and read the syntax and how to add new lines!
	# Syntax:
	# '<image name>' => '<response>',
	# <image name> - if you got following message 
	#	[responseOnNPCImage] Image name >> "????"
	# then the ???? is a <image name>.
	#
	# <response> - Any text that contained in NPC response choice(s) or number.
	my %imageTable = (
		'cbot_1' => 'poring'
		'cbot_2' => 'lunatic'
		'cbot_3' => 'fabre'
		'cbot_4' => 'drops'
	);


How to use:
-----------
1) Edit the "responseOnNPCImage.pl" file to your needs, see below.
2) At config.txt use something like this:

reactOnNPC talkImage num {
	type number
	msg_0 [Bot Check]
	msg_1 /.*/
}

How to get an image name and fill in the "responseOnNPCImage.pl" file?
	When you got this message on console [responseOnNPCImage] Image name >> "????"
	Using GRF Tool, open your data.grf or any *.grf and search for the image name ????.
	Then follow to that image path, you will get all images that your server might ask to you!

Some server use image name as a response.
	put in config.txt:
	responseOnNPCImage_equal < num | text | resp | or leave blank for disable >