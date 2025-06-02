@echo off
echo ========================================
echo  recv.asi Build Script
echo ========================================
echo.

echo Limpando arquivos anteriores...
if exist recv.asi del recv.asi

echo.
echo Compilando...
g++ -shared -fPIC -O2 -Wall -Wno-unknown-pragmas -o recv.asi Recv/recv.cpp -lws2_32 -luser32 -lkernel32

if exist recv.asi (
    echo.
    echo ========================================
    echo  COMPILACAO CONCLUIDA COM SUCESSO!
    echo ========================================
    echo Arquivo criado: recv.asi
    dir recv.asi
    echo.
    echo Para usar:
    echo 1. Envie a recv.asi para o a pasta onde está o cliente do Ragnarok Online
    echo 2. Configure a porta do X-Kore quando solicitado
    echo 3. Use F11 para aplicar hook, F12 para remover
) else (
    echo.
    echo ========================================
    echo  ERRO NA COMPILACAO!
    echo ========================================
    echo Verifique se o compilador esta instalado.
    echo Certifique-se de que o MSYS2/MinGW-w64 esta no PATH.
)

echo.
pause 