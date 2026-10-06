@echo off
setlocal
title Trident — selective agent setup
echo.
echo   TRIDENT
echo   Hermes  ·  ZCode  ·  Antigravity  ·  Claude  ·  ZeroClaw
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set EXITCODE=%ERRORLEVEL%
echo.
if %EXITCODE% NEQ 0 (
  echo   Finished with errors. Press any key to close.
  pause >nul
) else (
  echo   Done. Press any key to close.
  pause >nul
)
exit /b %EXITCODE%
