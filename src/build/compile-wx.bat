@echo off
cd /d "%~dp0\..\.."
set "OPENKORE_WX_BUILD_ROOT=%CD%"
set "OPENKORE_WX_BUILD_EXE=%TEMP%\openkore-wxstart-%RANDOM%.exe"
set "PERL5LIB=%CD%\src;%CD%\src\deps;%PERL5LIB%"
for /f "delims=" %%i in ('perl -MAlien::wxWidgets -e "print Alien::wxWidgets->shared_library_path"') do set "PATH=%%i;%PATH%"
cd /d "%~dp0"
perl -Mpp -e "pp->go()" -- -o "%OPENKORE_WX_BUILD_EXE%" -M Wx -M Wx::RichText -M Wx::Grid -M Wx::Html -M Wx::XRC -M XSTools -M Interface::Wx -M Network::Receive -M Network::Send -M Settings -M Modules -M ErrorHandler -M Plugins -M Utils::PerlLauncher -M IO::Socket::INET -M Win32::Console -M Win32::Process -M Digest::MD5 -M Storable -M Encode -M Encode::Byte -M Encode::KR -M Encode::TW -M Encode::JP -M Encode::CN -M Compress::Zlib -M HTML::Entities -M File::Path -M Text::Balanced -M Math::BigInt -M Math::BigInt::FastCalc -M Math::BigInt::Trace -M Math::BigFloat -M Math::BigFloat::Trace -M Math::BigRat -M Math::Complex -M Math::Trig -l wxbase330u_gcc_custom.dll -l wxbase330u_net_gcc_custom.dll -l wxbase330u_xml_gcc_custom.dll -l wxmsw330u_core_gcc_custom.dll -l wxmsw330u_adv_gcc_custom.dll -l wxmsw330u_richtext_gcc_custom.dll -l wxmsw330u_html_gcc_custom.dll -l wxmsw330u_xrc_gcc_custom.dll -l libgcc_s_dw2-1.dll -l libstdc++-6.dll "%OPENKORE_WX_BUILD_ROOT%\src\build\wxstart-par.pl"
if errorlevel 1 exit /b %errorlevel%
if not exist "%OPENKORE_WX_BUILD_EXE%" exit /b 1
move /y "%OPENKORE_WX_BUILD_EXE%" "%OPENKORE_WX_BUILD_ROOT%\wxstart.exe" >nul
exit /b %errorlevel%
