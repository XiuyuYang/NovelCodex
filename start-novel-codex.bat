@echo off
REM ============================================================
REM  NovelCodex one-click runner
REM ============================================================
REM  This file must stay ASCII. Chinese prompts and UTF-8 JSON
REM  writes are handled by start-novel-codex.ps1.
REM ============================================================

cd /d "%~dp0"
chcp 65001 > nul

if not exist "%~dp0system\start-novel-codex.ps1" (
    echo [ERROR] system\start-novel-codex.ps1 not found.
    echo Please run this BAT from the NovelCodex root.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0system\start-novel-codex.ps1" %*

set RUN_EXIT=%ERRORLEVEL%
echo.
echo Codex exited with code %RUN_EXIT%.
echo Press any key to close this window.
pause > nul
exit /b %RUN_EXIT%
