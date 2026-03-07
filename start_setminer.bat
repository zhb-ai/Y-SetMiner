@echo off
cd /d "%~dp0"
python -m start_setminer %*
if errorlevel 1 pause
