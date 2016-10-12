@echo off
cls
COLOR B0
mode con:cols=60 lines=10
TITLE UNIFORM SERVER - Enable SSL in Apache config

rem #################################################################
rem # Name: Apache_enable_ssl.bat
rem # Created By: The Uniform Server Development Team
rem # Edited Last By: Mike Gleaves (ric)
rem # V 1.0 19-3-2013
rem # This script enables ssl in Apache's configuration file. 
rem # It changes the following line in httpd.conf
rem # From: #LoadModule ssl_module modules/mod_ssl.so
rem #   To: LoadModule ssl_module modules/mod_ssl.so
rem #################################################################

rem ### working directory current folder 
pushd %~dp0

CD ../../utils
usua.exe sslEnable
echo.
echo  SSL has been enabled in Apache configuration file.
echo.
pause

popd
exit
