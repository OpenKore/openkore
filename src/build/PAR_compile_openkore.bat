Rem this script generate a .exe with support to all interfaces
cd ..\..
wxpar -lib src -o openkore.exe start.pl --module Wx::Perl::Packager --module Wx --module Wx:: --module Win32::GUI --module Win32::GUI::Constants --module Tk --module Tk:: --module Win32::API
pause

Rem --icon src\build\openkore.ico