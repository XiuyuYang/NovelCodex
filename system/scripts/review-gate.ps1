param(
    [string]$NovelRoot = "",
    [Parameter(Mandatory=$true)]
    [string]$Chapter,
    [Parameter(Mandatory=$true)]
    [ValidateSet("blueprint", "outline", "draft", "stress-test")]
    [string]$Phase,
    [string]$QualityTier = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib-utf8.ps1"

if (-not $NovelRoot) {
    $NovelRoot = $PWD.Path
} elseif (Test-Path -LiteralPath $NovelRoot) {
    $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
}

if ($Chapter -match '^\d+$') {
    $Chapter = "{0:D2}" -f [int]$Chapter
}

$BlueprintReviewers = @("consistency-facts", "logic", "pacing", "plot-engineering")
$OutlineReviewers = @(
    "consistency-facts", "logic", "pacing", "plot-engineering",
    "consistency-narrative", "language", "dialogue", "description",
    "ai-vocab", "ai-structure", "ai-human"
)
$DraftReviewers = @(
    "consistency-facts", "logic", "pacing", "plot-engineering",
    "consistency-narrative", "language", "dialogue", "description",
    "ai-vocab", "ai-structure", "ai-human", "reader-immersion"
)

function Get-ExpectedDimensions {
    param([string]$Name)
    switch ($Name) {
        "blueprint" { return $BlueprintReviewers }
        "outline" { return $OutlineReviewers }
        "draft" { return $DraftReviewers }
        "stress-test" { return @("stress-test") }
    }
}

function Get-QualityThreshold {
    param([string]$Tier)
    $text = ([string]$Tier).ToLowerInvariant()
    $hanHigh = [char]0x9AD8
    $hanMedium = [char]0x4E2D
    $hanLow = [char]0x4F4E
    $hanMost = [char]0x6700
    $hanFull = [char]0x6EE1
    $hanAll = [char]0x5168
    if ($text.Contains("highest") -or
        $text.Contains("perfect") -or
        $text.Contains("max") -or
        $text.Contains("strict") -or
        $text.Contains("all5") -or
        $text.Contains("full5") -or
        ($text.Contains([string]$hanMost) -and $text.Contains([string]$hanHigh)) -or
        $text.Contains([string]$hanFull) -or
        $text.Contains(([string]$hanAll) + "5")) { return 5.0 }
    if ($text.Contains("low") -or $text.Contains([string]$hanLow)) { return 2.5 }
    if ($text.Contains("medium") -or $text.Contains([string]$hanMedium)) { return 3.5 }
    if ($text.Contains("high") -or $text.Contains([string]$hanHigh)) { return 4.5 }
    return 4.5
}

function Get-ReviewManifest {
    param([string]$Root)
    $manifestPath = Join-Path $Root "logs\review-manifest.jsonl"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        return @()
    }
    $entries = New-Object System.Collections.Generic.List[object]
    $lines = [System.IO.File]::ReadAllLines($manifestPath, [System.Text.Encoding]::UTF8)
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $entries.Add(($line | ConvertFrom-Json)) | Out-Null
        } catch {
        }
    }
    return $entries.ToArray()
}

function Get-WorkflowReviewEvidence {
    param([string]$Root)
    $workflowPath = Join-Path $Root "logs\workflow-log.md"
    if (-not (Test-Path -LiteralPath $workflowPath)) {
        return @()
    }
    $entries = New-Object System.Collections.Generic.List[object]
    $lines = [System.IO.File]::ReadAllLines($workflowPath, [System.Text.Encoding]::UTF8)
    $pattern = '\[(?<chapter>\d{2})-(?<phase>[a-z-]+)-(?<round>r\d+)\].*?\[REVIEW-(?<dimension>[^\]]+)\]\s+(?<score>[0-9]+(?:\.[0-9]+)?)/5\s+(?<result>PASS|FAIL)\b(?:.*?\|\s*report=(?<report>\S+))?'
    foreach ($line in $lines) {
        $match = [regex]::Match($line, $pattern)
        if (-not $match.Success) { continue }
        $entries.Add([PSCustomObject]@{
            chapter = $match.Groups["chapter"].Value
            phase = $match.Groups["phase"].Value
            round = $match.Groups["round"].Value
            dimension = $match.Groups["dimension"].Value
            score = [double]$match.Groups["score"].Value
            pass = ($match.Groups["result"].Value -eq "PASS")
            report = $match.Groups["report"].Value
            source = "workflow-log"
        }) | Out-Null
    }
    return $entries.ToArray()
}

function Get-ReviewFileForDimension {
    param(
        [string]$Root,
        [string]$Chapter,
        [string]$Phase,
        [string]$Dimension
    )
    $logsDir = Join-Path $Root "logs"
    if (-not (Test-Path -LiteralPath $logsDir)) { return $null }
    $patterns = @(
        "review-$Dimension-ch$Chapter-$Phase-r*.txt",
        "review-$Chapter-$Phase-$Dimension.txt"
    )
    foreach ($pattern in $patterns) {
        $match = Get-ChildItem -LiteralPath $logsDir -File -Filter $pattern -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 0 } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($match) { return $match }
    }
    return $null
}

$runtimePath = Join-Path $NovelRoot "runtime.json"
if ((-not $QualityTier) -and (Test-Path -LiteralPath $runtimePath)) {
    $runtime = Read-Utf8File -Path $runtimePath | ConvertFrom-Json
    if ($runtime -and ($runtime.PSObject.Properties.Name -contains "quality_tier")) {
        $QualityTier = [string]$runtime.quality_tier
    }
}
if (-not $QualityTier) {
    $QualityTier = "high"
}

$expected = @(Get-ExpectedDimensions -Name $Phase)
$threshold = [double](Get-QualityThreshold -Tier $QualityTier)
$evidence = @(@(Get-WorkflowReviewEvidence -Root $NovelRoot) + @(Get-ReviewManifest -Root $NovelRoot))

$confirmed = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]
$unconfirmed = New-Object System.Collections.Generic.List[string]
$failed = New-Object System.Collections.Generic.List[string]
$scores = New-Object System.Collections.Generic.List[double]

foreach ($dimension in $expected) {
    $matches = @($evidence | Where-Object {
        ([string]$_.chapter) -eq $Chapter -and
        ([string]$_.phase) -eq $Phase -and
        ([string]$_.dimension) -eq $dimension
    })
    if ($matches.Count -gt 0) {
        $entry = $matches[$matches.Count - 1]
        $confirmed.Add($dimension) | Out-Null
        if ($entry.PSObject.Properties.Name -contains "score") {
            $scores.Add([double]$entry.score) | Out-Null
        }
        $isPass = ($entry.PSObject.Properties.Name -contains "pass") -and [bool]$entry.pass
        if (-not $isPass) {
            $failed.Add($dimension) | Out-Null
        }
        continue
    }

    $file = Get-ReviewFileForDimension -Root $NovelRoot -Chapter $Chapter -Phase $Phase -Dimension $dimension
    if ($file) {
        $unconfirmed.Add($dimension) | Out-Null
    } else {
        $missing.Add($dimension) | Out-Null
    }
}

$meanScore = $null
if ($scores.Count -gt 0) {
    $sum = 0.0
    foreach ($score in $scores) { $sum += [double]$score }
    $meanScore = [Math]::Round(($sum / $scores.Count), 3)
}

$ready = ($missing.Count -eq 0 -and $unconfirmed.Count -eq 0 -and $confirmed.Count -eq $expected.Count)
$pass = ($ready -and $failed.Count -eq 0 -and $null -ne $meanScore -and [double]$meanScore -ge $threshold)
$reason = "pass"
if (-not $ready) {
    $reason = "missing_or_unconfirmed"
} elseif ($failed.Count -gt 0) {
    $reason = "failed_dimensions"
} elseif ([double]$meanScore -lt $threshold) {
    $reason = "mean_below_threshold"
}

[PSCustomObject]@{
    novel_root = $NovelRoot
    chapter = $Chapter
    phase = $Phase
    quality_tier = $QualityTier
    threshold = $threshold
    expected_dimensions = @($expected)
    confirmed = @($confirmed.ToArray())
    missing = @($missing.ToArray())
    unconfirmed = @($unconfirmed.ToArray())
    failed = @($failed.ToArray())
    review_count = $confirmed.Count
    fail_count = $failed.Count
    mean_score = $meanScore
    ready = [bool]$ready
    pass = [bool]$pass
    reason = $reason
} | ConvertTo-Json -Depth 20
