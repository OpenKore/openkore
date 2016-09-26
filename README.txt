##########################

Folk for support ROEXE

https://github.com/OpenKore/openkore

###########################

we do not provide the EAC module just search in TRO mega thread... 
https://github.com/OpenKore/openkore/issues/221

install tutorial

1. modify your "C:\Windows\System32\drivers\etc\hosts" add this to the end

######## C:\Windows\System32\driver\etc\hosts #############
127.0.0.1		api.easyanticheat.net
127.0.0.1		client.easyanticheat.net
127.0.0.1		client-front.easyanticheat.net
127.0.0.1		cdn.exe.in.th
######## C:\Windows\System32\driver\etc\hosts #############

try pinging these website

start-> run -> cmd  -> ping xxxx 
it should return 127.0.0.1 to you.
this mean you modify hosts file correctly

or you can use UniController.exe -> Extra -> Edit Win hosts file

2. run UniServerZ/UniController.exe

2.1 Create a server certificate:
   From UniController: Apache >  Apache SSL > click "Server Certificate and Key generator"  
   Server Certificate and Key generator form opens click "Generate" button
   A confirmation pop-up displayed, click "OK" button

2.2 Click "Start Apache" if nothing wrong you should see green status
"View www" and "View ssl" would clickable
2.3 copy "prevent_update/wow64.bin" into "ROEXEOpenkore\UniServerZ\ssl\eac\82\"

********** CRITICAL STEP **********
********** FAIL TO FOLLOW THIS YOU MAY GET DETECTED BY EAC ****************
3. copy all dll in folder "to_syswow64&inject yourself" into "C:\Windows\SysWOW64" if x64 or "C:\Windows\System32" if your system is x32 (hooktest.dll, NetRedirect.dll)
* remove (hooktest.dll, NetRedirect.dll) in ragnarok folder if you had it.

3.1 go download CFF Explorer from here "http://www.ntcore.com/exsuite.php"
and get - "CFF Explorer (x86 Version, stand-alone, Zip Archive) "
3.2 for "x64" goto "C:\Windows\SysWOW64" or "x32" goto "C:\Windows\System32"
3.3 look for "AudioSes.dll" we need to change file owner 
right click "AudioSes.dll" -> "Properties" -> "Security" -> "Advance" 
look for owner click "change" -> "Advance" -> "Find Now"
Select "Administrators" and then click "OK" -> "OK" 
3.4 add permission 
right click "AudioSes.dll" -> "Properties" -> "Security" -> "Edit" 
Select "Administrators" and then click "Allow" at "Full control" -> "OK" ->"OK"
3.5 Do backup of "AudioSes.dll" e.g. copy and rename it to "AudioSes_original.dll"
3.5 copy that "AudioSes.dll" out of system folder
3.6 open the "AudioSes.dll" that you had been copy it with "CFF Explorer"
Select "Import Adder" -> "Add" Browse to "hooktest.dll" in "C:\Windows\SysWOW64" if x64 or "C:\Windows\System32" if your system is x32

Select "00000001-_FuckEAC@0" -> "Import By Name" -> "Rebuild Import Table" -> "Save" and close it
3.7 replace edited  "AudioSes.dll" into "C:\Windows\SysWOW64" or "C:\Windows\System32"

#note: if in doubt try rename the "AudioSes.dll" before copy it back.



4. Start "ragnarok.exe" patcher normally
after "ragexe.exe" is running there will be messagebox popup tell you about the port 2xxx 
don't run any openkore before this step.

5. run "start.exe" or "wxstart.exe" as "other user" and enter Xkoreport you got.


*************************************************************************************
now you are fine with it...

6. do login the game

7. do repeat step 4. - 7. if you want more bot.

Happy botting

p.s. you must check the patch server too. if there any update.
since this will redirect cdn.exe.in.th to localhost

for update in future just update the hooktest.dll and Netredirect.dll into RO folder
and wow64.bin into ROEXEOpenkore\UniServerZ\ssl\eac\82\