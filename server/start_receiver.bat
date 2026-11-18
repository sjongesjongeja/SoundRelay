@echo off
title SoundRelay PC Receiver
cd /d "%~dp0"
echo ========================================================
echo               SoundRelay PC Audio Receiver
echo ========================================================
echo.
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [FOUT] Python is niet geinstalleerd of niet in PATH!
    pause
    exit /b 1
)

echo Controleren op vereiste Python packages...
pip install -r requirements.txt --quiet

echo.
echo SoundRelay Receiver wordt gestart...
echo.
python run.py
pause
