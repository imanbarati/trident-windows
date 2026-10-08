@echo off
setlocal
title Trident Setup (MVP)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Trident.Gui.ps1" %*
