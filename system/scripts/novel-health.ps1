param(
    [string]$NovelRoot = "",
    [string]$SystemRoot = "",
    [int]$MaxErrors = 20
)

$ErrorActionPreference = "Stop"

if (-not $SystemRoot) {
    $SystemRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} elseif (Test-Path -LiteralPath $SystemRoot) {
    $SystemRoot = (Resolve-Path -LiteralPath $SystemRoot).Path
}

if (-not $NovelRoot) {
    $NovelRoot = $SystemRoot
} elseif (Test-Path -LiteralPath $NovelRoot) {
    $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
}

. "$PSScriptRoot\lib-utf8.ps1"

function Get-EventErrors {
    param(
        [string]$Root,
        [int]$Limit
    )

    $logsDir = Join-Path $Root "logs"
    if (-not (Test-Path -LiteralPath $logsDir)) {
        return @()
    }

    $errors = New-Object System.Collections.Generic.List[object]
    $eventFiles = Get-ChildItem -LiteralPath $logsDir -File -Filter "*events*.jsonl" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    foreach ($file in $eventFiles) {
        $lines = [System.IO.File]::ReadAllLines($file.FullName, [System.Text.Encoding]::UTF8)
        foreach ($line in $lines) {
            if ($errors.Count -ge $Limit) {
                return $errors.ToArray()
            }
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            $include = $false
            $message = ""
            $eventType = ""

            try {
                $event = $line | ConvertFrom-Json
                if ($event.PSObject.Properties.Name -contains "type") {
                    $eventType = [string]$event.type
                }
                if ($eventType -eq "error") {
                    $include = $true
                    $message = Limit-Text ([string]$event.message)
                } elseif ($eventType -eq "turn.failed") {
                    $include = $true
                    $message = Limit-Text ([string]$event.error.message)
                } elseif (($event.PSObject.Properties.Name -contains "item") -and $event.item.status -eq "failed") {
                    $include = $true
                    $exitCode = if ($event.item.PSObject.Properties.Name -contains "exit_code") { $event.item.exit_code } else { "" }
                    $shortLine = Get-MatchingShortLine ([string]$event.item.aggregated_output)
                    $message = Limit-Text ("item failed type={0} exit_code={1} detail={2}" -f $event.item.type, $exitCode, $shortLine)
                }
            } catch {
                if ($line -match "usage limit|quota|error:|failed|timeout|wsl|bash") {
                    $include = $true
                    $message = Limit-Text $line
                }
            }

            if ($include) {
                $errors.Add([PSCustomObject]@{
                    file = $file.Name
                    event_type = $eventType
                    message = $message
                }) | Out-Null
            }
        }
    }

    return $errors.ToArray()
}

function Limit-Text {
    param(
        [string]$Text,
        [int]$MaxLength = 450
    )
    if ($null -eq $Text) {
        return ""
    }
    $oneLine = ($Text -replace "[\r\n]+", " ").Trim()
    if ($oneLine.Length -le $MaxLength) {
        return $oneLine
    }
    return ($oneLine.Substring(0, $MaxLength) + "...")
}

function Get-MatchingShortLine {
    param([string]$Text)
    if ($null -eq $Text) {
        return ""
    }
    $lines = $Text -split "[\r\n]+"
    foreach ($line in $lines) {
        if ($line -match "usage limit|quota|error|failed|failure|timeout|wsl|bash|ParserError|Invalid argument") {
            return (Limit-Text $line)
        }
    }
    if ($lines.Count -gt 0) {
        return (Limit-Text $lines[0])
    }
    return ""
}

$statusRaw = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SystemRoot "scripts\novel-status.ps1") -SystemRoot $SystemRoot -NovelRoot $NovelRoot -WorkflowTail 8
$status = $statusRaw | ConvertFrom-Json
$errors = @(Get-EventErrors -Root $NovelRoot -Limit $MaxErrors)

$health = [PSCustomObject]@{
    system_root = $SystemRoot
    novel_root = $NovelRoot
    first_unfinished = $null
    codex_errors = $errors
    blocking_error_count = $errors.Count
    hints = @(
        "Use SystemRoot/scripts/novel-next-prompt.ps1 -NovelRoot <novel> for the smallest safe resume prompt.",
        "Use SystemRoot/scripts/run-ai-taste-lint.ps1 for Windows-safe AI taste checks.",
        "Do not inspect creative content from output, drafts, review logs, memory, references, or settings in orchestrator mode."
    )
}

foreach ($chapter in $status.chapters) {
    if ($chapter.stage -ne "completed") {
        $health.first_unfinished = [PSCustomObject]@{
            chapter = $chapter.chapter
            stage = $chapter.stage
        }
        break
    }
}

$health | ConvertTo-Json -Depth 20
