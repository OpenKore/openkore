##########################

Folk for support ROEXE

https://github.com/OpenKore/openkore

###########################

we do not provide the EAC module
just search in TRO mega thread... 
https://github.com/OpenKore/openkore/issues/221

**** install tutorial * XKore 1 **** for XKore 0.5 read below ****
******** You need 2 PC or VMware(Run RO in VM) ***********
EAC Detect Openkore in ring1

********** CRITICAL STEP **********
********** FAIL TO FOLLOW THIS YOU MAY GET DETECTED BY EAC ****************
1. copy "hooktest.dll" + netredirect.dll in folder "to_syswow64&inject yourself" to...
if x64
"C:\Windows\SysWOW64" 
if x32
"C:\Windows\System32"
* remove (hooktest.dll, NetRedirect.dll) in ragnarok folder if you had it.

1.1 Download CFF Explorer "http://www.ntcore.com/exsuite.php"
get "CFF Explorer (x86 Version, stand-alone, Zip Archive)"

1.2 look for "AudioSes.dll"
if x64
goto "C:\Windows\SysWOW64"
if x32
goto "C:\Windows\System32"

1.3  we need to change file owner 
 - right click "AudioSes.dll" -> "Properties" -> "Security" -> "Advance" 
 - look for "Owner:" then click "Change" -> "Advance" -> "Find Now"
 - Select "Administrators" and click "OK" -> "OK" 
1.4 add permission
 - right click "AudioSes.dll" -> "Properties" -> "Security" -> "Edit" 
 - Select "Administrators" and click "Allow" at "Full control" -> "OK" ->"OK"
 
1.5 Do backup of "AudioSes.dll" 
e.g. copy and rename it to "AudioSes_original.dll"

1.6 copy "AudioSes.dll" out of system folder

1.7 Open the "AudioSes.dll" that you had been copy it with "CFF Explorer"
 - Select "Import Adder" -> "Add" Browse to "hooktest.dll" in 
 
if x64
goto "C:\Windows\SysWOW64"
if x32
goto "C:\Windows\System32"

 - Select "00000001-_FuckEAC@0" -> "Import By Name" -> "Rebuild Import Table" -> "Save" and close it
1.8 replace edited  "AudioSes.dll" into 

if x64
goto "C:\Windows\SysWOW64"
if x32
goto "C:\Windows\System32"

#note: if in doubt try rename the "AudioSes.dll" before copy it back.

2. Start "ragnarok.exe" patcher normally
"ragexe.exe" is running there will be messagebox popup tell you about the port 2xxx - 4xxx
take note this port number you need it..
 

*************************************************************************************
now you are fine with it...

3. run "start.exe" or "wxstart.exe" at "another PC" or "outside Vmware" and enter "XKoreport" you got from client.

4. do repeat step 2 and 3. if you want more bot.

#######################################################################

install tutorial * XKore 0.5 *
******** You need 2 PC or VMware(Run RO in VM) ***********
EAC Detect Openkore in ring1

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
3. copy "hooktest.dll" in folder "to_syswow64&inject yourself" to...
if x64
"C:\Windows\SysWOW64" 
if x32
"C:\Windows\System32"
* remove (hooktest.dll, NetRedirect.dll) in ragnarok folder if you had it.

3.1 Download CFF Explorer "http://www.ntcore.com/exsuite.php"
get "CFF Explorer (x86 Version, stand-alone, Zip Archive)"

3.2 look for "AudioSes.dll"
if x64
goto "C:\Windows\SysWOW64"
if x32
goto "C:\Windows\System32"

3.3  we need to change file owner 
 - right click "AudioSes.dll" -> "Properties" -> "Security" -> "Advance" 
 - look for "Owner:" then click "Change" -> "Advance" -> "Find Now"
 - Select "Administrators" and click "OK" -> "OK" 
3.4 add permission
 - right click "AudioSes.dll" -> "Properties" -> "Security" -> "Edit" 
 - Select "Administrators" and click "Allow" at "Full control" -> "OK" ->"OK"
 
3.5 Do backup of "AudioSes.dll" 
e.g. copy and rename it to "AudioSes_original.dll"

3.5 copy "AudioSes.dll" out of system folder

3.6 Open the "AudioSes.dll" that you had been copy it with "CFF Explorer"
 - Select "Import Adder" -> "Add" Browse to "hooktest.dll" in 
 
if x64
goto "C:\Windows\SysWOW64"
if x32
goto "C:\Windows\System32"

 - Select "00000001-_FuckEAC@0" -> "Import By Name" -> "Rebuild Import Table" -> "Save" and close it
3.7 replace edited  "AudioSes.dll" into 

if x64
goto "C:\Windows\SysWOW64"
if x32
goto "C:\Windows\System32"

#note: if in doubt try rename the "AudioSes.dll" before copy it back.

4. Start "ragnarok.exe" patcher normally
after zombie "ragexe.exe" is running there will be messagebox popup tell you about the port 2xxx 

*************************************************************************************
now you are fine with it...

5. run "start.exe" or "wxstart.exe" at other PC or outside Vmware and enter "IP Address of RO Client PC" and "XKoreport" you got from zombie client.

6. do repeat step 4 and 5. if you want more bot.

p.s. you must check the patch server too. if there any update.
since this will redirect cdn.exe.in.th to localhost
we do not need NetRedirect.dll anymore...

#################################################
Happy botting
for update in future please re read this guide again..