##########################

Folk for support ROEXE

https://github.com/OpenKore/openkore

###########################

install tutorial

1. modify your C:\Windows\System32\driver\etc\hosts add this to the end

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

2. run UniServerZ/UniController.exe and
2.1 Apache -> Apache SSL -> Server Certificate and Key generator
2.2 start apache you should see popup windows pointing to this
http://localhost/index.php

3. copy all dll in folder Client_Side into your ro folder (hooktest.dll, NetRedirect.dll)
and following how-to.txt guide.