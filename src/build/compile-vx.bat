cd ..\..
set BUILDING_WX=2
perlapp --clean --trim Pod::Usage;I18N::Langinfo;XSTools --icon src\build\openkore.ico --lib src --norunlib --gui --nologo --force --exe vxstart.exe start.pl --add List::Util;File::Path;Text::Balanced;Digest::MD5;Math::BigInt;Math::BigInt::Calc;Math::BigInt::CalcEmu;Math::BigInt::FastCalc;Math::BigInt::Trace;Math::BigFloat;Math::BigFloat::Trace;Math::BigRat;Math::Complex;Math::Trig;Tk;Tk::**;
pause
