@echo off
cd /d "%~dp0"
python -m start_setminer --dev %*
if errorlevel 1 pause
