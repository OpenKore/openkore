@echo off
cls
COLOR B0
:mode con:cols=65 lines=20
TITLE UNIFORM SERVER - Certificate details

rem ###################################################
rem # Name: view_cert_details.bat
rem # Created By: The Uniform Server Development Team
rem # Edited Last By: Mike Gleaves (ric)
rem # V 1.0 21-3-2013
rem ##################################################

rem ### working directory current folder 
pushd %~dp0
CD ../../
set HOME=%CD%

if exist %HOME%\core\apache2\server_certs\server.crt goto CRT_EXIST

echo.
echo  Server Certificate and Key do not exist.
echo.
goto END


:CRT_EXIST
set OPENSSL_CONF=%HOME%\core\openssl\openssl.cnf

rem --- Set new path environment variable.openssl apache\bin
set PATH=%CD%\core\openssl;%CD%\core\apache2\bin;%PATH%

echo.
Rem --- Other display options
:openssl x509 -in server.crt -noout -text
:openssl x509 -in csr.txt -noout -text
:openssl req -in csr.txt -noout -text
:openssl rsa -in server.key -noout -text
:openssl version

openssl x509 -in %HOME%\core\apache2\server_certs\server.crt -noout -subject -issuer -startdate -enddate

set OPENSSL_CONF=

echo.

:END
pause
rem ### restore original working directory
popd


