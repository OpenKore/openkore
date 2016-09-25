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

or you can use UniController.exe -> Extra -> Edit Win hosts file

2. run UniServerZ/UniController.exe

2.1 Create a server certificate:
   From UniController: Apache >  Apache SSL > click "Server Certificate and Key generator"  
   Server Certificate and Key generator form opens click "Generate" button
   A confirmation pop-up displayed, click OK button

2.2 Click Start Apache if nothing wrong you should see green status
and View www and View ssl would clickable

3. copy all dll in folder Client_Side into your ro folder (hooktest.dll, NetRedirect.dll)
and following how-to.txt guide. or find any tutorial

4. Start ragnarok patcher normally
after ragexe is running there will be messagebox popup tell you about the port 2xxx 

5. goto control/config.txt and change XKore_port to any port you got.

6. run start.exe or wxstart.exe

7. do login the game

Happy botting
