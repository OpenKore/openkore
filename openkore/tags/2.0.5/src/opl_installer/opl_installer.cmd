@echo off

set OKDIR=%PROGRAMFILES%\Openkore
set BINDIR=%OKDIR%\src\opl_installer
set TMPDIR=%OKDIR%\src\opl_installer\tmp
set PLUGDIR=%OKDIR%\plugins

%BINDIR%\hidecmd.exe

IF "%1"=="" %BINDIR%\msgbox.exe -t:"Error !" -i:info "No .opl file specified..." & EXIT

@FOR /F "usebackq" %%a IN (`%BINDIR%\basename.exe %1`) DO SET FILENAME=%%a
@FOR /F "tokens=1* delims=." %%a IN ("%FILENAME%") DO SET PLUGINNAME=%%a
@FOR /F "tokens=1* delims=:" %%a IN ("%~1") DO SET oplpath="%%b"

IF EXIST %PLUGDIR%\%PLUGINNAME% %BINDIR%\msgbox.exe -t:"Error !" -i:info "Plugin '%PLUGINNAME%' already installed..." & EXIT

md %PLUGDIR% >NUL 2>&1
%BINDIR%\wget.exe -q http:%oplpath%

IF NOT EXIST %FILENAME% %BINDIR%\msgbox.exe -t:"Error !" -i:info "Could not download %1" & EXIT

%BINDIR%\7za.exe x -o%TMPDIR% -y %FILENAME% >NUL 2>&1

del %FILENAME% >NUL 2>&1

cd %TMPDIR%
SET INFOFILE=%PLUGINNAME%\info.txt
IF EXIST %INFOFILE% %BINDIR%\msgbox.exe -t:"Success !" -i:info -f:%INFOFILE% ""

move %TMPDIR%\%PLUGINNAME%\plugins\%PLUGINNAME% %PLUGDIR% >NUL 2>&1
move %TMPDIR%\%PLUGINNAME%\control\*.* %OKDIR%\control >NUL 2>&1

SET POSTINST=%TMPDIR%\%PLUGINNAME%\postinst.cmd
if EXIST %POSTINST% call %POSTINST%

rd /S /Q %TMPDIR%\%PLUGINNAME%

cd %OKDIR%
IF EXIST control\%PLUGINNAME%_config.txt GOTO writeconfig
GOTO end

:writeconfig
echo ######## Include %PLUGINNAME% plugin configuration ######## >> control\config.txt
echo !include %PLUGINNAME%_config.txt >> control\config.txt

:ende
