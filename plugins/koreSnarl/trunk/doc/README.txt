NAME: koreSnarl (snarl notification support Win32)
COMPABILITY: SVN revision 6464 or higher
AUTHOR: sli
LICENCE:
COPYRIGHT:
TOPIC: http://forums.openkore.com/viewtopic.php?f=34&t=2315



INSTALLATION:
-------------
1) Install Win32::GUI. Check the readme for a super easy install method. Chances are you'll want the 5.8 version as there's no public XSTools.dll for 5.10, yet. (I'd release mine, but it's over 5 megs )
2) Install Win32::Snarl. Change "use Win32::GUI;" to "use Win32::GUI();" in this module before you restart OpenKore!
3) Throw koreSnarl.pl into your plugins dir. (Be sure to check the config help at the bottom of this post as well.)
4) If you want it, here's the openkore.png I use: http://i23.photobucket.com/albums/b374/Malevolyn/openkore.png



CONFIGURATION:
--------------
The new version adds some configuration. But it's pretty simple. Here's mine:

config.txt
koreNotify 1
koreNotify_items Whisper Card, Soldier Skeleton Card
koreNotify_timeout 5

The first option is a simple toggle (1 = on, 0 = off). 
That second option holds a comma-separated list of items you'd like Kore to alert you about when your bot finds one.
To disable, simply comment the line out, or don't set it to anything. As for the timeout in timeouts.txt
if you don't want to use koreNotify_timeout):

notify 5