Quick Guide How to start multiple openkore instances.
Short Summary: This file allows to run many openkore instances on linux envyroment only running one command line on terminal.

How it works?
You can use the same openkore folder to keep space on your hard drive.
Each bot use their own control folder, so you can run every character separately with different configurations.
Finally we use the terminal (yes thats right) to run them all, using a software called "screen"
This creates like a "windows" where openkore will run on background, dont worry you can oppen it at any time you like and see the console in live.

How to use:
1.First all install openkore compiler packages.

2.Install screen:

sudo apt-get install screen

3.Make your control configs. Is highly recomended to use one control folder for each bot and name them simple.
For example if you are running 25 bots, create 25 control folder, control1, control2 ... control25
No matter if the only line you change is the username on config.txt
Place your control folders on the same openkore directory.

4.Modify the file openkore-all, Use notepad or any text editor:
You don't need to have programming skills to do this, just add or remove your lines deppending on how many bots you are planning to run

Note: leave a 10 seconds delay on each bot running to dont stress your CPU.
This affects old machines or slow disk reading on some devices such as raspberry Pi
For faster machine with SSD, you may remove this delay.

5.Run the file using this command

sudo ./openkore-all start




Not working step 5? you need to add admin permission to the folder if you are not root user

You may use chmod 777
sudo chmod -R 777 /<path of openkore folder>/

example:
sudo chmod -R 777 /home/pi/openkore/

Other options, use root user:
sudo su
