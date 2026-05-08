param(
    [string]$Story = "",
    [int]$Chapters = 0,
    [string]$Quality = "",
    [switch]$UseRealSubagents,
    [string]$CodexArgs = "",
    [string]$NovelRoot = "",
    [switch]$Resume
)

$ErrorActionPreference = "Stop"

$SystemRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SystemRoot = (Resolve-Path -LiteralPath $SystemRoot).Path
$InstallRoot = if ((Split-Path -Leaf $SystemRoot) -eq "system") {
    (Resolve-Path -LiteralPath (Split-Path -Parent $SystemRoot)).Path
} else {
    $SystemRoot
}
$NovelLibraryRoot = Join-Path $InstallRoot "novels"
Set-Location $SystemRoot
. "$SystemRoot\scripts\lib-utf8.ps1"

function Join-Chars {
    param([int[]]$Codes)
    return -join ($Codes | ForEach-Object { [char]$_ })
}

$QualityLow = Join-Chars @(0x4F4E, 0x6863)
$QualityMid = Join-Chars @(0x4E2D, 0x6863)
$QualityHigh = Join-Chars @(0x9AD8, 0x6863)
$QualityHighest = Join-Chars @(0x6700, 0x9AD8, 0x6863)
$CharLow = Join-Chars @(0x4F4E)
$CharMid = Join-Chars @(0x4E2D)
$CharHigh = Join-Chars @(0x9AD8)
$CharMost = Join-Chars @(0x6700)
$CharFull = Join-Chars @(0x6EE1)
$FullFive = (Join-Chars @(0x5168)) + "5"

function Read-NonEmpty {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )
    while ($true) {
        $suffix = if ($Default) { " [$Default]" } else { "" }
        $value = Read-Host "$Prompt$suffix"
        if (-not $value -and $Default) { return $Default }
        if ($value) { return $value }
        Write-Host "Please enter a value."
    }
}

function Read-PositiveInt {
    param(
        [string]$Prompt,
        [int]$Default = 3
    )
    while ($true) {
        $value = Read-Host "$Prompt [$Default]"
        if (-not $value) { return $Default }
        $parsed = 0
        if ([int]::TryParse($value, [ref]$parsed) -and $parsed -gt 0) {
            return $parsed
        }
        Write-Host "Please enter a positive integer."
    }
}

function Normalize-Quality {
    param([string]$Value)
    if (-not $Value) { return "" }
    $trimmed = $Value.Trim()
    $v = $trimmed.ToLowerInvariant()
    if ($v -match '^(4|highest|perfect|max|strict|all5|full5|full-score)$' -or
        $trimmed -eq $QualityHighest -or
        ($trimmed.Contains($CharMost) -and $trimmed.Contains($CharHigh)) -or
        $trimmed.Contains($CharFull) -or
        $trimmed.Contains($FullFive)) {
        return $QualityHighest
    }
    if ($v -match '^(1|low|fast)$' -or $trimmed -eq $QualityLow -or $trimmed.Contains($CharLow)) {
        return $QualityLow
    }
    if ($v -match '^(2|medium|normal|standard|mid)$' -or $trimmed -eq $QualityMid -or $trimmed.Contains($CharMid)) {
        return $QualityMid
    }
    if ($v -match '^(3|high|premium|best|top)$' -or $trimmed -eq $QualityHigh -or $trimmed.Contains($CharHigh)) {
        return $QualityHigh
    }
    return ""
}

function Read-Quality {
    param([string]$Default = "")
    if (-not $Default) { $Default = $QualityMid }
    while ($true) {
        $value = Read-Host "Quality: 1=low 2=medium 3=high 4=highest [$Default]"
        if (-not $value) { return $Default }
        $normalized = Normalize-Quality $value
        if ($normalized) { return $normalized }
        Write-Host "Please enter 1, 2, 3, 4, low, medium, high, or highest."
    }
}

function New-Slug {
    param([string]$Value)
    $ascii = ($Value -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLowerInvariant()
    if (-not $ascii) { $ascii = "novel" }
    if ($ascii.Length -gt 32) { $ascii = $ascii.Substring(0, 32).Trim('-') }
    if (-not $ascii) { $ascii = "novel" }
    return $ascii
}

function New-NovelWorkspace {
    param([string]$StorySeed)
    $library = $NovelLibraryRoot
    if (-not (Test-Path -LiteralPath $library)) {
        New-Item -ItemType Directory -Path $library -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $slug = New-Slug -Value $StorySeed
    $candidate = Join-Path $library ("{0}-{1}" -f $timestamp, $slug)
    $i = 2
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $library ("{0}-{1}-{2}" -f $timestamp, $slug, $i)
        $i++
    }
    New-Item -ItemType Directory -Path $candidate -Force | Out-Null
    return (Resolve-Path -LiteralPath $candidate).Path
}

function Set-JsonProperty {
    param(
        $Object,
        [string]$Name,
        $Value
    )
    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Write-ResumeFiles {
    param([string]$TargetNovelRoot)
    & (Join-Path $SystemRoot "scripts\write-resume-files.ps1") -SystemRoot $SystemRoot -NovelRoot $TargetNovelRoot | Out-Null
}

if (-not (Test-Path "$SystemRoot\.codex-plugin\plugin.json")) {
    throw "Missing .codex-plugin\plugin.json. Run this from the NovelCodex system root."
}

if ($Resume) {
    if (-not $NovelRoot) {
        throw "Resume requires -NovelRoot. Use the resume-this-novel.bat inside the target novel folder."
    } elseif (Test-Path -LiteralPath $NovelRoot) {
        $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
    } else {
        throw "NovelRoot not found for resume: $NovelRoot"
    }
} else {
    if (-not $Story) {
        $Story = Read-NonEmpty -Prompt "Story seed"
    }
    if ($Chapters -le 0) {
        $Chapters = Read-PositiveInt -Prompt "Chapter count" -Default 3
    }
    if (-not $Quality) {
        $Quality = Read-Quality -Default $QualityMid
    } else {
        $normalizedQuality = Normalize-Quality $Quality
        if (-not $normalizedQuality) {
            throw "Invalid quality. Use 1/2/3/4 or low/medium/high/highest."
        }
        $Quality = $normalizedQuality
    }
    if (-not $NovelRoot) {
        $NovelRoot = New-NovelWorkspace -StorySeed $Story
    } elseif (-not (Test-Path -LiteralPath $NovelRoot)) {
        New-Item -ItemType Directory -Path $NovelRoot -Force | Out-Null
        $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
    } else {
        $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
    }
}

& "$SystemRoot\scripts\init-workspace.ps1" -SystemRoot $SystemRoot -NovelRoot $NovelRoot
Write-ResumeFiles -TargetNovelRoot $NovelRoot

$runtimePath = Join-Path $NovelRoot "runtime.json"
$runtime = (Read-Utf8File -Path $runtimePath) | ConvertFrom-Json

if (-not $Resume) {
    Set-JsonProperty -Object $runtime -Name "current_genre" -Value "auto"
    Set-JsonProperty -Object $runtime -Name "quality_tier" -Value $Quality
    Set-JsonProperty -Object $runtime -Name "book_mode" -Value "first-N"
    Set-JsonProperty -Object $runtime -Name "total_chapters_to_write" -Value $Chapters
    Set-JsonProperty -Object $runtime -Name "story_seed" -Value $Story
    if (-not ($runtime.PSObject.Properties.Name -contains "last_completed_chapter")) {
        Set-JsonProperty -Object $runtime -Name "last_completed_chapter" -Value 0
    }
}

$executionMode = if ($UseRealSubagents) { "real-subagents" } else { "single-session-role-emulation" }
Set-JsonProperty -Object $runtime -Name "execution_mode" -Value $executionMode
Set-JsonProperty -Object $runtime -Name "use_real_subagents" -Value ([bool]$UseRealSubagents)
Set-JsonProperty -Object $runtime -Name "system_root" -Value $SystemRoot
Set-JsonProperty -Object $runtime -Name "novel_root" -Value $NovelRoot
Set-JsonProperty -Object $runtime -Name "workspace_layout_version" -Value 2
Set-JsonProperty -Object $runtime -Name "platform" -Value "windows"
if (-not $runtime.created_at) {
    Set-JsonProperty -Object $runtime -Name "created_at" -Value ((Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz"))
}
Set-JsonProperty -Object $runtime -Name "schema_version" -Value 6

Write-Utf8File -Path $runtimePath -Content ($runtime | ConvertTo-Json -Depth 20)

if ($Resume) {
    & (Join-Path $SystemRoot "scripts\prepare-open-ended-resume.ps1") -NovelRoot $NovelRoot | Out-Null
    $runtime = (Read-Utf8File -Path $runtimePath) | ConvertFrom-Json
}

$safeResumePrompt = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SystemRoot "scripts\novel-next-prompt.ps1") -SystemRoot $SystemRoot -NovelRoot $NovelRoot -WorkflowTail 8

$prompt = @"
$safeResumePrompt

User task:
- story_seed: $($runtime.story_seed)
- chapters_to_write: $($runtime.total_chapters_to_write)
- quality_tier: $($runtime.quality_tier)
- execution_mode: $executionMode

Run fully automatically inside Codex CLI. When generation is finished or blocked, report:
- metadata stage
- NovelRoot
- output directory
- resume command: $NovelRoot\resume-this-novel.bat
"@

Write-Host ""
Write-Host "NovelCodex will start Codex CLI."
Write-Host ("SystemRoot: {0}" -f $SystemRoot)
Write-Host ("NovelRoot:  {0}" -f $NovelRoot)
Write-Host ("Resume BAT: {0}" -f (Join-Path $NovelRoot "resume-this-novel.bat"))
Write-Host ("Mode:       {0}" -f $executionMode)
Write-Host ""

$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) {
    throw "Codex CLI was not found. Install and sign in to codex, then run start-novel-codex.bat again."
}

$args = @(
    "--cd", $SystemRoot,
    "--dangerously-bypass-approvals-and-sandbox",
    $prompt
)

if ($CodexArgs) {
    $args = $CodexArgs.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries) + $args
}

& $codex.Source @args
exit $LASTEXITCODE
