cd ..\..
set BUILDING_WX=1
perlapp --clean --trim Pod::Usage;I18N::Langinfo;Wx::build::**;XSTools --icon src\build\openkore.ico --lib src --norunlib --nologo --force --exe wxstart.exe start.pl --add List::Util;File::Path;Text::Balanced;Wx::Perl::Packager;Wx;Wx::**
pause
