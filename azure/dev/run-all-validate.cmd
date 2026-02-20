@echo off
REM Execution policy bypass: run-all-validate.ps1 without changing system policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-all-validate.ps1"
pause
