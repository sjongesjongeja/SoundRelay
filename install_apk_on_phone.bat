@echo off
title Installeer SoundRelay op aangesloten Android Telefoon
cd /d "%~dp0"

echo ========================================================
echo        SoundRelay APK Installeren via USB (ADB)
echo ========================================================
echo.
set ADB_PATH=adb
where adb >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
        set ADB_PATH="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
    ) else (
        echo [FOUT] ADB niet gevonden.
        pause
        exit /b 1
    )
)

echo Controleren op aangesloten telefoons...
%ADB_PATH% devices
echo.

if not exist "%~dp0bin\SoundRelay.apk" (
    echo [FOUT] bin\SoundRelay.apk niet gevonden. Voer eerst Build-APK.bat uit!
    pause
    exit /b 1
)

echo Bezig met installeren van SoundRelay.apk op je telefoon...
%ADB_PATH% install -r "%~dp0bin\SoundRelay.apk"

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo [SUCCES!] SoundRelay is geinstalleerd op je telefoon!
    echo Je kunt de app nu openen op je toestel.
    echo ========================================================
) else (
    echo.
    echo [FOUT] Installatie mislukt. Controleer of USB-debugging aan staat en je telefoon ontgrendeld is.
)
echo.
pause
