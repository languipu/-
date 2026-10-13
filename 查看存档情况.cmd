@echo off
chcp 65001 >nul
title Travel Planner - Git Status
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\status.ps1"
echo.
echo Press any key to close this window...
pause >nul
