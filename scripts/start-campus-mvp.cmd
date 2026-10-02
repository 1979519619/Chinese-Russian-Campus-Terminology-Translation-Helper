@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-campus-mvp.ps1" -OpenBrowser
if errorlevel 1 (
  echo.
  echo Campus MVP failed to start. Review the message above.
  pause
)
endlocal
