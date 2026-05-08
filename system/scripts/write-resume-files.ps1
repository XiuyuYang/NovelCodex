param(
    [Parameter(Mandatory=$true)]
    [string]$SystemRoot,

    [Parameter(Mandatory=$true)]
    [string]$NovelRoot
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib-utf8.ps1"

$SystemRoot = (Resolve-Path -LiteralPath $SystemRoot).Path
$NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path

$safeSystemRoot = $SystemRoot.Replace("'", "''")
$resumePs1 = @"
param(
    [string]`$CodexArgs = ""
)

`$SystemRoot = '$safeSystemRoot'
& (Join-Path `$SystemRoot 'start-novel-codex.ps1') -Resume -NovelRoot `$PSScriptRoot -CodexArgs `$CodexArgs
exit `$LASTEXITCODE
"@
Write-Utf8File -Path (Join-Path $NovelRoot "resume-this-novel.ps1") -Content $resumePs1

$resumeBat = @"
@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resume-this-novel.ps1" %*
set RUN_EXIT=%ERRORLEVEL%
echo.
echo Codex exited with code %RUN_EXIT%.
pause
exit /b %RUN_EXIT%
"@
Write-Utf8File -Path (Join-Path $NovelRoot "resume-this-novel.bat") -Content $resumeBat

[PSCustomObject]@{
    novel_root = $NovelRoot
    resume_bat = (Join-Path $NovelRoot "resume-this-novel.bat")
} | ConvertTo-Json -Depth 5
