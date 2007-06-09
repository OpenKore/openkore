@echo off
rem --------------------------------------------------------------------------------
rem setupregistry.cmd should be called by the installer with the
rem openkore installation folder as parameter.
rem Example: call setupregistry.cmd C:\Program Files\OpenKore
rem --------------------------------------------------------------------------------
hidecmd.exe

@FOR /F "tokens=1* delims=" %%a IN ("%~1") DO SET OKDIR="%%b"

IF "%b"=="" msgbox.exe -t:"Error !" -i:info "No valid OpenKore installation specified !" & EXIT
IF NOT EXIST %~1\start.exe msgbox.exe -t:"Error !" -i:info "No valid OpenKore installation found in (%1%2%3) !" & EXIT

SET KEY="HKCR\opl"
REG ADD %KEY% /ve /t REG_SZ /d "URL:Openkore plugin installer" /f
REG ADD %KEY% /v "URL Protocol" /t REG_SZ /d "" /f

REG ADD %KEY%\DefaultIcon /ve /t REG_EXPAND_SZ /d "%1\start.exe" /f
REG ADD %KEY%\shell\open\command /ve /t REG_EXPAND_SZ /d "cmd.exe /E:ON /C call %1\src\opl_installer\opl_installer.cmd %%1" /f

REG ADD %KEY%\ParentDir /ve /t REG_SZ /d "URL:Openkore plugin installer" /f
