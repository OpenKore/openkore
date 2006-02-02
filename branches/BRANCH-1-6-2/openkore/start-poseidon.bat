@echo off
IF EXIST start.exe GOTO :start
IF EXIST wxstart.exe GOTO :wxstart
IF EXIST C:\Perl\bin\perl.exe GOTO :activeperl
echo ERROR: You do not have a Perl interpreter.
PAUSE
GOTO :end

:start
start.exe ! src\Poseidon\poseidon.pl
GOTO end

:wxstart
wxstart.exe ! src\Poseidon\poseidon.pl
GOTO end

:activeperl
C:\Perl\bin\perl.exe src\Poseidon\poseidon.pl
GOTO end

:end