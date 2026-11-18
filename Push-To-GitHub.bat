@echo off
title SoundRelay - Push to GitHub
cd /d "%~dp0"

echo ========================================================
echo             SoundRelay - Push naar GitHub
echo ========================================================
echo.
echo Dit script helpt je om dit project naar je GitHub account te uploaden.
echo.

set GH_BIN="C:\Program Files\GitHub CLI\gh.exe"
if exist %GH_BIN% (
    echo [1/3] Controleren op GitHub login...
    %GH_BIN% auth status >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo [2/3] Je bent ingelogd bij GitHub!
        echo Bezig met aanmaken van de repository op GitHub en pushen...
        %GH_BIN% repo create audiorelay --public --source=. --push
        if %ERRORLEVEL% equ 0 (
            echo.
            echo ========================================================
            echo [SUCCES!] Je repository staat nu live op GitHub!
            echo ========================================================
            pause
            exit /b 0
        )
    ) else (
        echo Je bent nog niet ingelogd via de GitHub CLI.
        echo.
        echo Wil je inloggen via de browser? [J/N]
        set /p login_choice="Keuze: "
        if /i "%login_choice%"=="J" (
            %GH_BIN% auth login -w -p https
            echo.
            echo Repository aanmaken en pushen...
            %GH_BIN% repo create audiorelay --public --source=. --push
            pause
            exit /b 0
        )
    )
)

echo.
echo ========================================================
echo Alternatieve methode (Handmatig):
echo 1. Ga naar: https://github.com/new
echo 2. Noem de repository bijvoorbeeld: audiorelay
echo 3. Voer daarna deze commando's uit in de terminal:
echo.
echo    git remote add origin https://github.com/sjongesjongeja/audiorelay.git
echo    git push -u origin main
echo ========================================================
echo.
pause
