@echo off
title SoundRelay Installer Builder
cd /d "%~dp0"
echo ========================================================
echo         SoundRelay Windows Installer Builder
echo ========================================================
echo.

set ISCC_BIN="C:\Users\%USERNAME%\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if not exist %ISCC_BIN% (
    if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
        set ISCC_BIN="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    ) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
        set ISCC_BIN="C:\Program Files\Inno Setup 6\ISCC.exe"
    ) else (
        echo [FOUT] Inno Setup compiler (ISCC.exe) niet gevonden!
        pause
        exit /b 1
    )
)

echo [1/2] Bouwen van Windows standalone executable (PyInstaller)...
pyinstaller --noconfirm --onedir --name "SoundRelay" ^
  --distpath "dist" --workpath "build_pyinstaller" ^
  --add-data "server\static;static" ^
  --hidden-import "uvicorn.logging" ^
  --hidden-import "uvicorn.loops.auto" ^
  --hidden-import "uvicorn.protocols.http.auto" ^
  --hidden-import "uvicorn.protocols.websockets.auto" ^
  --hidden-import "uvicorn.lifespan.on" ^
  --collect-all "sounddevice" ^
  --collect-all "uvicorn" ^
  --collect-all "fastapi" ^
  "server\run.py"

echo.
echo [2/2] Compileren van Inno Setup installer...
%ISCC_BIN% "%~dp0installer\SoundRelay.iss"

if exist "%~dp0bin\SoundRelay-Setup.exe" (
    echo.
    echo ========================================================
    echo [SUCCES!] Windows Installer gegenereerd:
    echo %~dp0bin\SoundRelay-Setup.exe
    echo ========================================================
) else (
    echo.
    echo [FOUT] Compilatie mislukt.
)
pause
