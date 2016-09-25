@echo off
cls
COLOR B0
mode con:cols=80 lines=20
TITLE UNIFORM SERVER Zero - Install Perl

rem ###########################################################################
rem # Name: extract_install_perl.bat
rem # Created By: The Uniform Server Development Team
rem # Edited Last By: MPG (ric)
rem # V 1.0 16-4-2013
rem # All paths are relative to folder UniServerZ making script generic.
rem ###########################################################################
echo.

rem working directory current folder 
pushd %~dp0

rem === Move up tree to get path to UniServerZ. Restore working dir
pushd..\..
set uz_path=%cd%
popd

rem === Check for any msi file in folder tmp
if NOT exist %uz_path%\tmp\Active*.msi goto NOT_FOUND_MSI 

rem -- Get msi file name
cd %uz_path%\tmp
FOR /F "tokens=*" %%i in ('dir /B Active*.msi') do SET perl_msi=%%i

rem -- Full path to msi
set full_msi=%uz_path%\tmp\%perl_msi%

rem === Check Perl already installed
if NOT exist %uz_path%\core\perl\bin goto EXTRACT_INSTALL

echo.
echo  Perl already installed:
echo  Would you like to delete existing version and install new version?
echo.
echo  Enter Yes or No and press return.
echo  Alteratively to accept default [Yes] press return 
echo.

rem -- SET /P prompts for user input and sets a variable
SET Choice=
SET /P Choice= INSTALL enter Yes [Default] or No and press enter: 
echo.

If '%Choice%'=='' Set Choice=Yes
IF Not '%Choice%'=='Yes' GOTO END

rem -- Delete existing Installation

echo  Deleting existing installation %uz_path%\core\perl\bin
rmdir /s /q %uz_path%\core\perl\bin
echo  Deleting existing installation %uz_path%\core\perl\lib
rmdir /s /q %uz_path%\core\perl\lib

rem === Extract and install Perl
:EXTRACT_INSTALL

mkdir %uz_path%\perl_temp
echo  Extracting files to temp folder %uz_path%\perl_temp
msiexec /a %full_msi% /qb TARGETDIR=%uz_path%\perl_temp


rem -- Copy directories 
echo  Copying to target %uz_path%\core\perl\bin
xcopy %uz_path%\perl_temp\Perl\bin %uz_path%\core\perl\bin /i /q /s
echo  Copying to target %uz_path%\core\perl\lib
xcopy %uz_path%\perl_temp\Perl\lib %uz_path%\core\perl\lib /i /q /s 

rem -- Delete Temp folder
echo  Deleting folder %uz_path%\perl_temp
rmdir /s /q %uz_path%\perl_temp

rem -- Delete Perl Installation file
echo  Deleting file %full_msi%
del %full_msi%

echo.
echo  Installation Complete
echo.

goto END

rem ====================================================

:NOT_FOUND_MSI
echo.
echo  Problem:
echo  Perl MSI installation file not found.
echo  No action taken.
echo.

:END
pause

rem === restore original working directory
popd
EXIT