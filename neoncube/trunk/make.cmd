@rem #!%SystemRoot%\cmd.exe
@rem **************************************************************************
@rem Usage:
@rem    .\make debug|release|clean (rebuild|dry-run)
@rem **************************************************************************

@echo off
set ERRORLEVEL=
setlocal

@rem **************************************************************************
@rem Set defaults
set debuglevel=release
set target=all
set MAKE=nmake -nologo
set proj_desc=NeonCube GPL project

@rem **************************************************************************
@rem Accept only rebuild, dry-run or no 2nd parameter
if "%2" == "rebuild" goto trig_rebuild_mode
if "%2" == "dry-run" goto trig_simul_mode
if "%1" == "clean" goto trig_clean_mode
if "%2" == "clean" goto trig_clean_mode
if not "%2" == "" goto bad_cmdspec_arg2
goto trig_lazy_mode

@rem **************************************************************************
:trig_rebuild_mode
set target=clean all
goto trig_lazy_mode

@rem **************************************************************************
:trig_simul_mode
set target=all /n
goto trig_lazy_mode

@rem **************************************************************************
:trig_clean_mode
set target=clean
goto trig_lazy_mode

@rem **************************************************************************
:trig_lazy_mode
if "%1" == "release" goto release
if "%1" == "debug" goto debug
if "%1" == "clean" goto implicit
if not "%1" == "" goto bad_cmdspec_arg1
:implicit
if "%1" == "" echo No configuration specified; defaulting to: _________ %debuglevel% _________
if "%debuglevel%" == "release" goto release
goto debug


@rem **************************************************************************
:release
set debugspec=
goto start_build
@rem **************************************************************************
:debug
set debugspec=DEBUG=Yay

@rem **************************************************************************
:start_build
echo Building %proj_desc% from directory: %~dp0

echo SLN_DIR=%~dp0             > sln.cfg
echo DIR_ZLIB=%~dp0zlib       >> sln.cfg
echo DIR_GRF=%~dp0libgrf        >> sln.cfg
echo DIR_UNRAR=%~dp0unrar     >> sln.cfg
echo DIR_BROWSER=%~dp0browser >> sln.cfg

@rem **************************************************************************
rem Sample
rem @echo %MAKE% /f %proj_mak%  %target%   %debugspec%
rem %MAKE% /f %proj_mak%  %target%   %debugspec%
rem if errorlevel 1 goto make_sad_end
rem goto happy_end

@rem **************************************************************************
for %%D in ( zlib libgrf unrar browser ) do (
	echo.
	echo = Building %%D...
	pushd %%D
	@%MAKE% /f Makefile.msc %target%   %debugspec%
	if errorlevel 1 goto make_sad_end
	popd
)

@rem **************************************************************************
@rem mkdir bin 2> NUL

@rem **************************************************************************
echo.
echo Building NeonCube executable...
rem pushd src
@%MAKE% /f Makefile.msc %target%   %debugspec%
@rem %MAKE% /f Makefile.msc %target%   %debugspec%
if errorlevel 1 goto make_sad_end
rem popd

@rem **************************************************************************
goto happy_end



@rem **************************************************************************
:bad_cmdspec_arg1
echo error: First parameter should be "release", "debug" or "clean"
%ComSpec% /c exit /b 1
goto sad_end

@rem **************************************************************************
:bad_cmdspec_arg2
echo error: Second parameter should be "rebuild", "dry-run" or empty
%ComSpec% /c exit /b 1
goto sad_end

:make_sad_end
echo ** Program has returned with code %ERRORLEVEL%
popd

:sad_end
endlocal
goto real_end

:happy_end
popd
endlocal

:real_end
%ComSpec% /c exit /b %ERRORLEVEL%
