@echo off
echo ========================================
echo  recv.asi Build Script - Visual Studio
echo ========================================
echo.

echo Configurando ambiente do Visual Studio...
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"

echo.
echo Limpando arquivos anteriores...
if exist recv.asi del recv.asi
if exist Recv\Release\recv.asi del Recv\Release\recv.asi

echo.
echo Compilando com MSBuild...
msbuild Recv\recv.sln /p:Configuration=Release /p:Platform=Win32 /verbosity:minimal

if exist Recv\Release\recv.asi (
    copy Recv\Release\recv.asi .
    echo.
    echo ========================================
    echo  COMPILACAO CONCLUIDA COM SUCESSO!
    echo ========================================
    echo Arquivo criado: recv.asi
    dir recv.asi
) else (
    echo.
    echo ========================================
    echo  ERRO NA COMPILACAO!
    echo ========================================
    echo Verifique os logs de erro acima.
)

echo.
pause 