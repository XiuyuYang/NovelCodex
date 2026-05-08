param(
    [string]$NovelRoot = "",
    [string]$SystemRoot = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib-utf8.ps1"

if (-not $SystemRoot) {
    $SystemRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} elseif (Test-Path -LiteralPath $SystemRoot) {
    $SystemRoot = (Resolve-Path -LiteralPath $SystemRoot).Path
}

if (-not $NovelRoot) {
    $NovelRoot = $SystemRoot
} elseif (-not (Test-Path -LiteralPath $NovelRoot)) {
    New-Item -ItemType Directory -Path $NovelRoot -Force | Out-Null
    $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
} else {
    $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
}

$agentsPath = Join-Path $SystemRoot "AGENTS.md"
if (-not (Test-Path -LiteralPath $agentsPath)) {
    Write-Error "[ERROR] SystemRoot has no AGENTS.md: $SystemRoot"
    exit 1
}

$manifestPath = Join-Path $SystemRoot ".codex-plugin\plugin.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Host "[WARN] SystemRoot has no .codex-plugin/plugin.json: $SystemRoot"
}

Write-Host ("init-workspace system={0}" -f $SystemRoot)
Write-Host ("init-workspace novel={0}" -f $NovelRoot)

$markerDir = Join-Path $NovelRoot ".novelcodex"
if (-not (Test-Path -LiteralPath $markerDir)) {
    New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
}

$marker = [PSCustomObject]@{
    schema_version = 1
    kind = "novel-workspace"
    system_root = $SystemRoot
    novel_root = $NovelRoot
    created_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
}
Write-Utf8File -Path (Join-Path $markerDir "novel-workspace.json") -Content ($marker | ConvertTo-Json -Depth 10)

foreach ($d in @("output", "drafts", "logs", "memory")) {
    $dir = Join-Path $NovelRoot $d
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}
Write-Host "  [+] runtime dirs: output drafts logs memory"

$copied = 0
$skipped = 0
$memoryFiles = @(
    "README.md", "world.md", "characters.md", "timeline.md", "foreshadowing.md",
    "locations.md", "style-bible.md", "lessons.md", "pacing-budget.md",
    "planner-notes.md", "writer-notes.md", "story-bible.md", "arcs.md", "facts.md"
)

foreach ($f in $memoryFiles) {
    $dest = Join-Path (Join-Path $NovelRoot "memory") $f
    if (-not (Test-Path -LiteralPath $dest)) {
        $src = Join-Path (Join-Path $SystemRoot "templates\memory") $f
        if (Test-Path -LiteralPath $src) {
            $tplContent = Read-Utf8File -Path $src
            Write-Utf8File -Path $dest -Content $tplContent
        } else {
            Write-Utf8File -Path $dest -Content ""
            Write-Host ("  [~] memory/{0} empty template missing" -f $f)
        }
        $copied++
    } else {
        $skipped++
    }
}
Write-Host ("  [+] memory templates: {0} copied, {1} skipped" -f $copied, $skipped)

$runtimePath = Join-Path $NovelRoot "runtime.json"
if (-not (Test-Path -LiteralPath $runtimePath)) {
    $templatePath = Join-Path $SystemRoot "templates\runtime.json.template"
    if (Test-Path -LiteralPath $templatePath) {
        $runtime = (Read-Utf8File -Path $templatePath) | ConvertFrom-Json
    } else {
        $runtime = [PSCustomObject]@{
            current_genre = "general"
            quality_tier = "medium"
            book_mode = "first-N"
            total_chapters_to_write = 3
            last_completed_chapter = 0
            max_revision_rounds = 3
            git_auto_commit = $false
            two_digit_chapter_naming = $true
            schema_version = 6
            created_at = ""
            story_seed = ""
            execution_mode = "single-session-role-emulation"
            use_real_subagents = $false
            revision_state = [PSCustomObject]@{}
        }
    }
    if (-not $runtime.created_at) {
        $runtime.created_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    }
    if ($runtime.PSObject.Properties.Name -contains "schema_version") {
        $runtime.schema_version = [Math]::Max([int]$runtime.schema_version, 6)
    } else {
        $runtime | Add-Member -NotePropertyName "schema_version" -NotePropertyValue 6
    }
    foreach ($pair in @(
        @{ name = "system_root"; value = $SystemRoot },
        @{ name = "novel_root"; value = $NovelRoot },
        @{ name = "workspace_layout_version"; value = 2 },
        @{ name = "platform"; value = "windows" }
    )) {
        $propName = $pair.name
        if ($runtime.PSObject.Properties.Name -contains $propName) {
            $runtime.$propName = $pair.value
        } else {
            $runtime | Add-Member -NotePropertyName $propName -NotePropertyValue $pair.value
        }
    }
    Write-Utf8File -Path $runtimePath -Content ($runtime | ConvertTo-Json -Depth 20)
    Write-Host "  [+] runtime.json"
} else {
    $runtime = (Read-Utf8File -Path $runtimePath) | ConvertFrom-Json
    foreach ($pair in @(
        @{ name = "system_root"; value = $SystemRoot },
        @{ name = "novel_root"; value = $NovelRoot },
        @{ name = "workspace_layout_version"; value = 2 },
        @{ name = "platform"; value = "windows" }
    )) {
        $propName = $pair.name
        if ($runtime.PSObject.Properties.Name -contains $propName) {
            $runtime.$propName = $pair.value
        } else {
            $runtime | Add-Member -NotePropertyName $propName -NotePropertyValue $pair.value
        }
    }
    if (($runtime.PSObject.Properties.Name -contains "schema_version") -and ([int]$runtime.schema_version -lt 6)) {
        $runtime.schema_version = 6
    }
    Write-Utf8File -Path $runtimePath -Content ($runtime | ConvertTo-Json -Depth 20)
    Write-Host "  [.] runtime.json exists"
}

$now = (Get-Date).ToString("yyyy-MM-dd HH:mm")

$workflowPath = Join-Path $NovelRoot "logs\workflow-log.md"
if (-not (Test-Path -LiteralPath $workflowPath)) {
    $workflowLog = @"
# NovelCodex workflow log

## Project
- initialized_at: $now
- status: pending

## Heartbeats
Agent calls must append one start line and one return line.

"@
    Write-Utf8File -Path $workflowPath -Content $workflowLog
    Write-Host "  [+] logs/workflow-log.md"
}

$chapterIndexPath = Join-Path $NovelRoot "logs\chapter-index.md"
if (-not (Test-Path -LiteralPath $chapterIndexPath)) {
    $chapterIndex = @"
# Chapter Index

| chapter | short_title | one_line_summary | words |
|---------|-------------|------------------|-------|
"@
    $chapterIndex = $chapterIndex + [Environment]::NewLine
    Write-Utf8File -Path $chapterIndexPath -Content $chapterIndex
    Write-Host "  [+] logs/chapter-index.md"
}

$agentCallsPath = Join-Path $NovelRoot "logs\agent-calls.md"
if (-not (Test-Path -LiteralPath $agentCallsPath)) {
    $agentCalls = @"
# Agent Calls

| time | chapter | agent | task | result | round |
|------|---------|-------|------|--------|-------|
"@
    $agentCalls = $agentCalls + [Environment]::NewLine
    Write-Utf8File -Path $agentCallsPath -Content $agentCalls
    Write-Host "  [+] logs/agent-calls.md"
}

$manifestPath = Join-Path $NovelRoot "logs\review-manifest.jsonl"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Utf8File -Path $manifestPath -Content ""
    Write-Host "  [+] logs/review-manifest.jsonl"
}

Write-Host "init-workspace done"
