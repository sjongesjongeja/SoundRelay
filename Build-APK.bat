@echo off
title SoundRelay APK Builder
cd /d "%~dp0android"
echo ========================================================
echo             SoundRelay Android APK Builder
echo ========================================================
echo.

set GRADLE_BIN=gradle
where gradle >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "%USERPROFILE%\.gradle\wrapper\dists\gradle-9.1.0-all\7wzd0jkjit61aq2p43wpjgij9\gradle-9.1.0\bin\gradle.bat" (
        set GRADLE_BIN="%USERPROFILE%\.gradle\wrapper\dists\gradle-9.1.0-all\7wzd0jkjit61aq2p43wpjgij9\gradle-9.1.0\bin\gradle.bat"
    ) else (
        echo [FOUT] Gradle niet gevonden!
        pause
        exit /b 1
    )
)

echo Bezig met compileren van APK...
call %GRADLE_BIN% assembleDebug

if exist "%~dp0android\app\build\outputs\apk\debug\app-debug.apk" (
    copy /y "%~dp0android\app\build\outputs\apk\debug\app-debug.apk" "%~dp0bin\SoundRelay.apk"
    echo.
    echo ========================================================
    echo [SUCCES] APK gereed!
    echo Bestand opgeslagen in:
    echo %~dp0bin\SoundRelay.apk
    echo ========================================================
) else (
    echo.
    echo [FOUT] Compilatie mislukt. Bekijk de foutmeldingen hierboven.
)
pause
