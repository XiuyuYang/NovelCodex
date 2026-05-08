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
    [string]$Summary
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib-utf8.ps1"

if (Test-Path -LiteralPath $NovelRoot) {
    $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
}

$pattern = '^\[REVIEW-([^\]]+)\]\s+([0-9]+(?:\.[0-9]+)?)/5\s+(PASS|FAIL)\b.*?\|\s*report=(.+?)\s*$'
if ($Summary -notmatch $pattern) {
    throw "Review summary does not match contract: $Summary"
}

$entry = [PSCustomObject]@{
    chapter = $Chapter
    phase = $Phase
    round = $Round
    dimension = $Matches[1]
    score = [double]$Matches[2]
    pass = ($Matches[3] -eq "PASS")
    report = $Matches[4]
    summary = $Summary
    created_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
}

$manifestPath = Join-Path $NovelRoot "logs\review-manifest.jsonl"
$line = ($entry | ConvertTo-Json -Compress -Depth 8) + [Environment]::NewLine
Append-Utf8File -Path $manifestPath -Content $line
Write-Output $line.TrimEnd()
