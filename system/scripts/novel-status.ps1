param(
    [string]$NovelRoot = "",
    [string]$SystemRoot = "",
    [int]$WorkflowTail = 20
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

function Get-FileMeta {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    $item = Get-Item -LiteralPath $Path
    [PSCustomObject]@{
        path = $item.FullName
        name = $item.Name
        length = $item.Length
        last_write_time = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Test-NonEmptyFile {
    param([string]$Path)
    $meta = Get-FileMeta -Path $Path
    return ($null -ne $meta -and $meta.length -gt 0)
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

function Get-OutputChapterMeta {
    param([string]$Root)
    $outputDir = Join-Path $Root "output"
    if (-not (Test-Path -LiteralPath $outputDir)) { return @() }
    Get-ChildItem -LiteralPath $outputDir -File -Filter "*.txt" |
        Sort-Object Name |
        ForEach-Object {
            [PSCustomObject]@{
                name = $_.Name
                length = $_.Length
                last_write_time = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
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
        if ($match) {
            return $match
        }
    }
    return $null
}

function Get-ReviewSummary {
    param(
        [string]$Root,
        [string]$Chapter,
        [string]$Phase,
        [string[]]$Dimensions,
        [object[]]$Evidence = @()
    )
    $found = New-Object System.Collections.Generic.List[string]
    $missing = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    $unconfirmed = New-Object System.Collections.Generic.List[string]
    foreach ($dimension in $Dimensions) {
        $evidenceEntry = @($Evidence | Where-Object {
            ([string]$_.chapter) -eq $Chapter -and
            ([string]$_.phase) -eq $Phase -and
            ([string]$_.dimension) -eq $dimension
        } | Select-Object -Last 1)

        if ($evidenceEntry.Count -gt 0) {
            $entry = $evidenceEntry[0]
            if (($entry.PSObject.Properties.Name -contains "pass") -and [bool]$entry.pass) {
                $found.Add($dimension) | Out-Null
            } else {
                $failed.Add($dimension) | Out-Null
            }
        } else {
            $file = Get-ReviewFileForDimension -Root $Root -Chapter $Chapter -Phase $Phase -Dimension $dimension
            if ($file) {
                $unconfirmed.Add($dimension) | Out-Null
            } else {
                $missing.Add($dimension) | Out-Null
            }
        }
    }
    [PSCustomObject]@{
        found = $found.ToArray()
        missing = $missing.ToArray()
        failed = $failed.ToArray()
        unconfirmed = $unconfirmed.ToArray()
        count = $found.Count
        expected = $Dimensions.Count
        complete = ($missing.Count -eq 0 -and $failed.Count -eq 0 -and $unconfirmed.Count -eq 0)
    }
}

function Get-ChapterOutputs {
    param(
        [string]$Root,
        [string]$Chapter
    )
    $outputDir = Join-Path $Root "output"
    if (-not (Test-Path -LiteralPath $outputDir)) { return @() }
    $prefix = ([char]0x7B2C) + $Chapter + ([char]0x7AE0) + "-"
    Get-ChildItem -LiteralPath $outputDir -File -Filter "*.txt" |
        Where-Object { $_.Name.StartsWith($prefix) } |
        Sort-Object Name |
        ForEach-Object {
            [PSCustomObject]@{
                name = $_.Name
                path = $_.FullName
                length = $_.Length
                last_write_time = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
}

function Test-ChapterIndexRow {
    param(
        [string]$Root,
        [string]$Chapter
    )
    $indexPath = Join-Path $Root "logs\chapter-index.md"
    if (-not (Test-Path -LiteralPath $indexPath)) { return $false }
    $lines = [System.IO.File]::ReadAllLines($indexPath, [System.Text.Encoding]::UTF8)
    $chapterInt = [int]$Chapter
    foreach ($line in $lines) {
        if ($line -match "\|\s*$Chapter\s*\|" -or $line -match "\|\s*$chapterInt\s*\|") {
            return $true
        }
    }
    return $false
}

function Get-ChapterStage {
    param(
        [string]$Root,
        [int]$Number,
        $Runtime,
        [object[]]$Evidence = @()
    )
    $chapter = "{0:D2}" -f $Number
    $blueprint = Get-FileMeta (Join-Path $Root "drafts\$chapter-blueprint.md")
    $outline = Get-FileMeta (Join-Path $Root "drafts\$chapter-outline.md")
    $outputs = @(Get-ChapterOutputs -Root $Root -Chapter $chapter)

    $blueprintReviews = Get-ReviewSummary -Root $Root -Chapter $chapter -Phase "blueprint" -Dimensions $BlueprintReviewers -Evidence $Evidence
    $outlineReviews = Get-ReviewSummary -Root $Root -Chapter $chapter -Phase "outline" -Dimensions $OutlineReviewers -Evidence $Evidence
    $draftReviews = Get-ReviewSummary -Root $Root -Chapter $chapter -Phase "draft" -Dimensions $DraftReviewers -Evidence $Evidence
    $stressReviews = Get-ReviewSummary -Root $Root -Chapter $chapter -Phase "stress-test" -Dimensions @("stress-test") -Evidence $Evidence

    $postDone = Test-NonEmptyFile (Join-Path $Root "logs\post-ch$chapter.txt")
    $factsDone = Test-NonEmptyFile (Join-Path $Root "logs\facts-ch$chapter.txt")
    $indexDone = Test-ChapterIndexRow -Root $Root -Chapter $chapter
    $lastCompleted = 0
    if ($Runtime -and ($Runtime.PSObject.Properties.Name -contains "last_completed_chapter")) {
        $lastCompleted = [int]$Runtime.last_completed_chapter
    }
    $runtimeDone = ($lastCompleted -ge $Number)

    if (-not ($blueprint -and $blueprint.length -gt 0)) {
        $stage = "needs-blueprint"
    } elseif (-not $blueprintReviews.complete) {
        $stage = "needs-blueprint-review"
    } elseif (-not ($outline -and $outline.length -gt 0)) {
        $stage = "needs-outline"
    } elseif (-not $outlineReviews.complete) {
        $stage = "needs-outline-review"
    } elseif ($outputs.Count -eq 0) {
        $stage = "needs-draft"
    } elseif (-not $draftReviews.complete) {
        $stage = "needs-draft-review"
    } elseif (-not $stressReviews.complete) {
        $stage = "needs-stress-test"
    } elseif (-not $postDone) {
        $stage = "needs-postprocess"
    } elseif (-not $factsDone) {
        $stage = "needs-fact-extraction"
    } elseif (-not ($indexDone -and $runtimeDone)) {
        $stage = "needs-completion-marker"
    } else {
        $stage = "completed"
    }

    [PSCustomObject]@{
        chapter = $chapter
        stage = $stage
        blueprint = $blueprint
        blueprint_review_count = $blueprintReviews.count
        blueprint_review_missing = @($blueprintReviews.missing)
        blueprint_review_failed = @($blueprintReviews.failed)
        blueprint_review_unconfirmed = @($blueprintReviews.unconfirmed)
        outline = $outline
        outline_review_count = $outlineReviews.count
        outline_review_missing = @($outlineReviews.missing)
        outline_review_failed = @($outlineReviews.failed)
        outline_review_unconfirmed = @($outlineReviews.unconfirmed)
        output = @($outputs)
        draft_review_count = $draftReviews.count
        draft_review_missing = @($draftReviews.missing)
        draft_review_failed = @($draftReviews.failed)
        draft_review_unconfirmed = @($draftReviews.unconfirmed)
        stress_test_done = [bool]$stressReviews.complete
        postprocess_done = [bool]$postDone
        facts_done = [bool]$factsDone
        chapter_index_done = [bool]$indexDone
        runtime_completed = [bool]$runtimeDone
    }
}

$runtimePath = Join-Path $NovelRoot "runtime.json"
$runtime = if (Test-Path -LiteralPath $runtimePath) {
    Read-Utf8File -Path $runtimePath | ConvertFrom-Json
} else {
    $null
}
$reviewManifest = @(Get-ReviewManifest -Root $NovelRoot)
$workflowReviewEvidence = @(Get-WorkflowReviewEvidence -Root $NovelRoot)
$reviewEvidence = @($workflowReviewEvidence) + @($reviewManifest)

$total = if ($runtime -and $runtime.total_chapters_to_write) { [int]$runtime.total_chapters_to_write } else { 0 }
$chapters = @()
if ($total -gt 0) {
    for ($i = 1; $i -le $total; $i++) {
        $chapters += Get-ChapterStage -Root $NovelRoot -Number $i -Runtime $runtime -Evidence $reviewEvidence
    }
}

$workflowPath = Join-Path $NovelRoot "logs\workflow-log.md"
$workflowTailLines = @()
if ((Test-Path -LiteralPath $workflowPath) -and $WorkflowTail -gt 0) {
    $allWorkflowLines = [System.IO.File]::ReadAllLines($workflowPath, [System.Text.Encoding]::UTF8)
    if ($allWorkflowLines.Length -gt 0) {
        $start = [Math]::Max(0, $allWorkflowLines.Length - $WorkflowTail)
        $workflowTailLines = @($allWorkflowLines[$start..($allWorkflowLines.Length - 1)])
    }
}

$status = [PSCustomObject]@{
    system_root = $SystemRoot
    novel_root = $NovelRoot
    runtime = $runtime
    review_manifest_count = $reviewManifest.Count
    workflow_review_evidence_count = $workflowReviewEvidence.Count
    chapters = $chapters
    output_files = @(Get-OutputChapterMeta $NovelRoot)
    workflow_tail = @($workflowTailLines)
}

$status | ConvertTo-Json -Depth 30
