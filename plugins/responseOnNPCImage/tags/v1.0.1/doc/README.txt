AUTHOR: abt123
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=1071

What it does:
-------------
You use it for response BotKiller #1 - Method 2: Image Numbers or Texts, working together to the hakore's reactOnNPC plugin.
(http://www.eathena.ws/board/index.php?showtopic=120522)
Version of Openkore tested: Opk 2.0.5.1

How to install:
1) Place this plugin in your plugins folder (see the Plugins FAQ how or macro plugin manual).
2) Don't forget to also download the reactOnNPC plugin and place it at the plugins folder, without it won't work!
3) Place the respImageTable.txt file at your bot control folder.
4) Add a reactOnNPC config block in your config.txt file which defines the command to use and the conditions of the NPC conversation which will trigger Openkore to use the command.
5) Open the respImageTable.txt file and read the syntax and how to add new lines!

How to use:
-----------
1) Edit the respImageTable.txt file to your needs, see below.
2) At config.txt use something like this:

reactOnNPC talkImage num {
       type number
       msg_0 [Antibot]
       msg_1 /.*/
}

How to get an image name and fill in the respImageTable.txt file?
When you got this message on console [responseOnNPCImage] Image name >> "????"
Using GRF Tool, open your data.grf or any *.grf and search for the image name ????.
Then follow to that image path, you will get all images that your server might ask to you!
