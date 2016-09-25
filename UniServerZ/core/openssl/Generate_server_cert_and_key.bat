@echo off
cls
COLOR B0
:mode con:cols=80 lines=20
TITLE UNIFORM SERVER - Server Certificate and Key gen

rem ###################################################
rem # Name: Generate_server_cert_and_key.bat
rem # Created By: The Uniform Server Development Team
rem # Edited Last By: Mike Gleaves (ric)
rem # V 1.0 22-3-2013
rem # This script automatically generates a self-signed 
rem # server certificate and key for localhost with no
rem # user intervention. A user may be using their own
rem # ca or real signed certificates hence do not
rem # overwrite.
rem ##################################################

rem ### working directory current folder 
pushd %~dp0

rem ### Move up two levels. CD now points to server root-folder
CD ../../
set HOME=%CD%
set OPENSSL_CONF=%HOME%\core\openssl\openssl.cnf

rem --- Set new path environment variable.openssl apache\bin
set PATH=%CD%\core\openssl;%CD%\core\apache2\bin;%PATH%

rem ### Check for ca or certificate exit if found
if exist %HOME%\core\apache2\server_certs\ca.crt goto CA_FOUND
if exist %HOME%\core\apache2\server_certs\server.crt goto CRT_EXIST

rem ### If folder does not exist create it
if not exist %HOME%\core\apache2\server_certs mkdir %HOME%\core\apache2\server_certs

rem ### Generate certificate and key
CD %CD%\core\apache2\bin
openssl req -newkey rsa:2048 -batch -nodes -out server.csr -keyout server.key -subj "/C=US/ST=Cambs/L=Cambridge/O=UniServer/emailAddress=me@fred.com/CN=localhost"
openssl x509 -in server.csr -out server.crt -req -signkey server.key -days 3650
set OPENSSL_CONF=

rem ### Delete certificate signing request and move certificate and key to server
del server.csr
move /y server.crt %HOME%\core\apache2\server_certs
move /y server.key %HOME%\core\apache2\server_certs

rem ### Enable ssl in Apache config
%HOME%\utils\usua.exe sslEnable

cls
echo.
echo  === Created ===============================================
echo.
echo  Server certificate and Key created and copied to server.
echo  Folder: UniServerZ\core\apache2\server_certs
echo.
echo  === Enabled ===============================================
echo.
echo  Enabled ssl in Acache config file httpd.conf:
echo  UniServerZ\core\apache2\conf\httpd.conf
echo.
echo  Original line : #LoadModule ssl_module modules/mod_ssl.so
echo  Changed to    : LoadModule ssl_module modules/mod_ssl.so
echo.
echo  === Note ==================================================
echo.
echo  For changes to take effect please restart Apache server.
echo. 
pause
goto END

:CA_FOUND
echo.
echo  === CA Found ===
echo.
echo  It looks like you are using your own CA.
echo.
echo  To avoid overwriting your current server certificate and key
echo  this script has terminated.
echo.
echo  To create a new server certificate and key use the CA script.
echo.
pause
goto END

:CRT_EXIST
echo.
echo  === Certificate Found ===
echo.
echo  A server certificate was found.
echo.
echo  To avoid overwriting your current server certificate and key
echo  this script has terminated.
echo.
pause
goto END

:END
popd
exit

