cd ..\..
set BUILDING_WX=1
perlapp --trim Pod::Usage;I18N::Langinfo --icon src\build\openkore.ico --lib src --norunlib --nologo --force --exe wxstart.exe start.pl --add Wx;Wx::RichText;Wx::Grid;Wx::Html;Wx::XRC
pause
