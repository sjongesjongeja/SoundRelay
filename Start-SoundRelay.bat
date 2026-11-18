@echo off
title SoundRelay Launcher
cd /d "%~dp0"

echo ========================================================
echo                   SOUNDRELAY LAUNCHER
echo ========================================================
echo.
echo Wat wil je doen?
echo  [1] Start PC Receiver (Ontvang audio op deze PC)
echo  [2] Verbind via USB Kabel (0ms vertraging met ADB)
echo  [3] Installeer SoundRelay.apk op aangesloten Android telefoon
echo  [4] Bouw Android APK opnieuw
echo.
set /p choice="Kies [1, 2, 3 of 4]: "

if "%choice%"=="1" (
    call "%~dp0server\start_receiver.bat"
) else if "%choice%"=="2" (
    call "%~dp0server\usb_stream.bat"
) else if "%choice%"=="3" (
    call "%~dp0install_apk_on_phone.bat"
) else if "%choice%"=="4" (
    call "%~dp0Build-APK.bat"
) else (
    echo Ongeldige keuze.
    pause
)
