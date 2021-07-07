cd ..\..
set BUILDING_WX=3
perlapp --clean --trim Pod::Usage;I18N::Langinfo;XSTools --icon src\build\openkore.ico --lib src --norunlib --gui --nologo --force --exe winguistart.exe start.pl --add List::Util;File::Path;Text::Balanced;Digest::MD5;Math::BigInt;Math::BigInt::Calc;Math::BigInt::CalcEmu;Math::BigInt::FastCalc;Math::BigInt::Trace;Math::BigFloat;Math::BigFloat::Trace;Math::BigRat;Math::Complex;Math::Trig;Win32::GUI;Win32::GUI;Win32::GUI::Constants;Win32::GUI::**;
pause
