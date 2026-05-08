param(
    [string]$SystemRoot = "",
    [string]$TargetName = "legacy-runtime"
)

$ErrorActionPreference = "Stop"

if (-not $SystemRoot) {
    $SystemRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} elseif (Test-Path -LiteralPath $SystemRoot) {
    $SystemRoot = (Resolve-Path -LiteralPath $SystemRoot).Path
}
$InstallRoot = if ((Split-Path -Leaf $SystemRoot) -eq "system") {
    (Resolve-Path -LiteralPath (Split-Path -Parent $SystemRoot)).Path
} else {
    $SystemRoot
}

. "$PSScriptRoot\lib-utf8.ps1"

$legacyItems = @("runtime.json", "output", "drafts", "logs", "memory")
$existing = @()
foreach ($item in $legacyItems) {
    $path = Join-Path $InstallRoot $item
    if (Test-Path -LiteralPath $path) {
        $existing += $item
    }
}

if ($existing.Count -eq 0) {
    Write-Output "No legacy runtime files found in system root."
    exit 0
}

$library = Join-Path $InstallRoot "novels"
if (-not (Test-Path -LiteralPath $library)) {
    New-Item -ItemType Directory -Path $library -Force | Out-Null
}
$libraryResolved = (Resolve-Path -LiteralPath $library).Path

$safeName = ($TargetName -replace '[^A-Za-z0-9_-]+', '-').Trim('-')
if (-not $safeName) { $safeName = "legacy-runtime" }
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$target = Join-Path $libraryResolved ("{0}-{1}" -f $timestamp, $safeName)
$i = 2
while (Test-Path -LiteralPath $target) {
    $target = Join-Path $libraryResolved ("{0}-{1}-{2}" -f $timestamp, $safeName, $i)
    $i++
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
$targetResolved = (Resolve-Path -LiteralPath $target).Path

$libraryPrefix = $libraryResolved.TrimEnd('\') + '\'
if (-not $targetResolved.StartsWith($libraryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to move legacy runtime outside novels library: $targetResolved"
}

foreach ($item in $existing) {
    $source = Join-Path $InstallRoot $item
    $dest = Join-Path $targetResolved $item
    Move-Item -LiteralPath $source -Destination $dest
}

& (Join-Path $SystemRoot "scripts\init-workspace.ps1") -SystemRoot $SystemRoot -NovelRoot $targetResolved | Out-Null

$runtimePath = Join-Path $targetResolved "runtime.json"
if (Test-Path -LiteralPath $runtimePath) {
    $runtime = Read-Utf8File -Path $runtimePath | ConvertFrom-Json
    foreach ($pair in @(
        @{ name = "system_root"; value = $SystemRoot },
        @{ name = "novel_root"; value = $targetResolved },
        @{ name = "workspace_layout_version"; value = 2 },
        @{ name = "platform"; value = "windows" },
        @{ name = "schema_version"; value = 6 }
    )) {
        $propName = $pair.name
        if ($runtime.PSObject.Properties.Name -contains $propName) {
            $runtime.$propName = $pair.value
        } else {
            $runtime | Add-Member -NotePropertyName $propName -NotePropertyValue $pair.value
        }
    }
    Write-Utf8File -Path $runtimePath -Content ($runtime | ConvertTo-Json -Depth 20)
}

& (Join-Path $SystemRoot "scripts\write-resume-files.ps1") -SystemRoot $SystemRoot -NovelRoot $targetResolved | Out-Null

[PSCustomObject]@{
    migrated = $existing
    novel_root = $targetResolved
    resume_bat = (Join-Path $targetResolved "resume-this-novel.bat")
} | ConvertTo-Json -Depth 5
