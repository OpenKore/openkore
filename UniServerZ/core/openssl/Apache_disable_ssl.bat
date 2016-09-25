@echo off
cls
COLOR B0
mode con:cols=60 lines=10
TITLE UNIFORM SERVER - Disable SSL in Apache config

rem #################################################################
rem # Name: Apache_disable_ssl.bat
rem # Created By: The Uniform Server Development Team
rem # Edited Last By: Mike Gleaves (ric)
rem # V 1.0 19-3-2013
rem # This script disables ssl in Apache's configuration file. 
rem # It changes the following line in httpd.conf
rem # From: LoadModule ssl_module modules/mod_ssl.so
rem #   To: #LoadModule ssl_module modules/mod_ssl.so
rem #################################################################

rem ### working directory current folder 
pushd %~dp0

CD ../../utils
usua.exe sslDisable

echo.
echo  SSL has been disabled in Apache configuration file.
echo.

pause

popd
exit

