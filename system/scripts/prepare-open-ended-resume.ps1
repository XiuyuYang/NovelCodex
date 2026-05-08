param(
    [Parameter(Mandatory=$true)]
    [string]$NovelRoot
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib-utf8.ps1"

if (-not (Test-Path -LiteralPath $NovelRoot)) {
    throw "NovelRoot not found: $NovelRoot"
}
$NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path

$runtimePath = Join-Path $NovelRoot "runtime.json"
if (-not (Test-Path -LiteralPath $runtimePath)) {
    throw "runtime.json not found: $runtimePath"
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

$runtime = Read-Utf8File -Path $runtimePath | ConvertFrom-Json
$lastCompleted = 0
if ($runtime.PSObject.Properties.Name -contains "last_completed_chapter") {
    $lastCompleted = [int]$runtime.last_completed_chapter
}

$resumeTarget = [Math]::Max(1, $lastCompleted + 1)

Set-JsonProperty -Object $runtime -Name "book_mode" -Value "open-ended-resume"
Set-JsonProperty -Object $runtime -Name "open_ended_resume" -Value $true
Set-JsonProperty -Object $runtime -Name "resume_target_chapter" -Value $resumeTarget
Set-JsonProperty -Object $runtime -Name "total_chapters_to_write" -Value $resumeTarget
Set-JsonProperty -Object $runtime -Name "resume_updated_at" -Value ((Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz"))

Write-Utf8File -Path $runtimePath -Content ($runtime | ConvertTo-Json -Depth 20)

[PSCustomObject]@{
    novel_root = $NovelRoot
    open_ended_resume = $true
    last_completed_chapter = $lastCompleted
    resume_target_chapter = $resumeTarget
    total_chapters_to_write = $resumeTarget
} | ConvertTo-Json -Depth 5
