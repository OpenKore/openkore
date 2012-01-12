cd ..\..
set BUILDING_WX=1
perlapp --clean --trim Pod::Usage;I18N::Langinfo;Wx::build::**;XSTools --icon src\build\openkore.ico --lib src --norunlib --nologo --force --exe wxstart.exe start.pl --add List::Util;File::Path;Text::Balanced;Digest::MD5;Math::BigInt;Math::BigInt::Calc;Math::BigInt::CalcEmu;Math::BigInt::FastCalc;Math::BigInt::Trace;Math::BigFloat;Math::BigFloat::Trace;Math::BigRat;Math::Complex;Math::Trig;Wx::Perl::Packager;Wx;Wx::**;
pause
