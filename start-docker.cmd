@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-docker.ps1" -Rebuild -CheckHealth
if errorlevel 1 (
  echo.
  echo Failed to start AuthVault containers.
  pause
  exit /b 1
)

echo.
echo AuthVault containers started successfully.
pause
