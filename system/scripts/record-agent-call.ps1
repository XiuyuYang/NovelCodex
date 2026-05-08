param(
    [Parameter(Mandatory=$true)]
    [string]$NovelRoot,

    [Parameter(Mandatory=$true)]
    [string]$Chapter,

    [Parameter(Mandatory=$true)]
    [string]$Phase,

    [Parameter(Mandatory=$true)]
    [string]$Round,

    [Parameter(Mandatory=$true)]
    [string]$Agent,

    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "return")]
    [string]$Event,

    [string]$Eta = "1-2min",
    [string]$Summary = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib-utf8.ps1"

if (Test-Path -LiteralPath $NovelRoot) {
    $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
}

$chapterText = "{0:D2}" -f [int]$Chapter
$tag = "{0}-{1}-{2}" -f $chapterText, $Phase, $Round
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
$workflowPath = Join-Path $NovelRoot "logs\workflow-log.md"
$agentCallsPath = Join-Path $NovelRoot "logs\agent-calls.md"
$startWord = [string]([char]0x542F) + [string]([char]0x52A8)
$waitText = [string]([char]0xFF0C) + [string]([char]0x7B49) + [string]([char]0x5F85) + [string]([char]0x8FD4) + [string]([char]0x56DE) + [string]([char]0xFF08) + [string]([char]0x5178) + [string]([char]0x578B) + [string]([char]0x8017) + [string]([char]0x65F6) + " {0}" + [string]([char]0xFF09)
$returnWord = [string]([char]0x8FD4) + [string]([char]0x56DE) + [string]([char]0xFF1A)

if ($Event -eq "start") {
    $line = "[{0}] [{1}] {2} {3}{4}" -f $timestamp, $tag, $startWord, $Agent, ($waitText -f $Eta)
    Append-Utf8File -Path $workflowPath -Content ($line + [Environment]::NewLine)
    Write-Output $line
    exit 0
}

if (-not $Summary) {
    throw "Summary is required for return events."
}

$returnLine = "[{0}] [{1}] {2} {3}{4}" -f $timestamp, $tag, $Agent, $returnWord, $Summary
Append-Utf8File -Path $workflowPath -Content ($returnLine + [Environment]::NewLine)

if (-not (Test-Path -LiteralPath $agentCallsPath)) {
    $headerLines = @(
        "# Agent Calls",
        "",
        "| time | chapter | agent | task | result | round |",
        "|------|---------|-------|------|--------|-------|"
    )
    $header = ($headerLines -join [Environment]::NewLine) + [Environment]::NewLine
    Write-Utf8File -Path $agentCallsPath -Content $header
}

$escapedSummary = $Summary.Replace("|", "\|")
$agentRow = "| {0} | {1} | {2} | {3} | {4} | {5} |" -f $timestamp, $chapterText, $Agent, $Phase, $escapedSummary, $Round
Append-Utf8File -Path $agentCallsPath -Content ($agentRow + [Environment]::NewLine)

if ($Summary -match '^\[REVIEW-') {
    & "$PSScriptRoot\append-review-manifest.ps1" -NovelRoot $NovelRoot -Chapter $chapterText -Phase $Phase -Round $Round -Summary $Summary | Out-Null
}

Write-Output $returnLine
