@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\check-docker-health.ps1"
if errorlevel 1 (
  echo.
  echo Docker health check failed.
  pause
  exit /b 1
)

echo.
echo Docker health check passed.
pause
