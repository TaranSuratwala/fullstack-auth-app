@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop-docker.ps1"
if errorlevel 1 (
  echo.
  echo Failed to stop AuthVault containers.
  pause
  exit /b 1
)

echo.
echo AuthVault containers stopped successfully.
pause
