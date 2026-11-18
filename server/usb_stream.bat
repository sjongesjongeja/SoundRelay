@echo off
title SoundRelay USB Kabel Modus (ADB)
cd /d "%~dp0"
echo ========================================================
echo        SoundRelay USB Modus (0ms Latentie Streaming)
echo ========================================================
echo.
echo Zorg dat:
echo  1. Je Android telefoon via USB is aangesloten.
echo  2. 'USB-foutopsporing' (USB Debugging) aan staat op je telefoon.
echo.

set ADB_PATH=adb
where adb >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
        set ADB_PATH="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
    ) else (
        echo [FOUT] ADB niet gevonden. Zorg dat de Android SDK geinstalleerd is.
        pause
        exit /b 1
    )
)

echo Controleren op aangesloten telefoons...
%ADB_PATH% devices
echo.

echo USB Poort forwarding instellen...
%ADB_PATH% reverse tcp:59102 tcp:59102
%ADB_PATH% reverse tcp:59100 tcp:59100

if %ERRORLEVEL% equ 0 (
    echo.
    echo [SUCCES!] USB Tunnel actief!
    echo Vul in de SoundRelay app op je telefoon dit IP-adres in:
    echo     127.0.0.1
    echo.
    echo Audio wordt nu direct en zonder vertraging via de USB-kabel gestreamd.
) else (
    echo.
    echo [FOUT] Kon USB-tunnel niet opzetten. Controleer of je telefoon ontgrendeld is en USB-debugging toestaat.
)
echo.
pause
