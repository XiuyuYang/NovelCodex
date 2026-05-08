param(
    [string]$SystemRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not $SystemRoot) {
    $SystemRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}
$SystemRoot = (Resolve-Path -LiteralPath $SystemRoot).Path
$InstallRoot = Split-Path -Parent $SystemRoot
if ((Split-Path -Leaf $SystemRoot) -ne "system") {
    $InstallRoot = $SystemRoot
}

. (Join-Path $SystemRoot "scripts\lib-utf8.ps1")

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message
    )
    if ($Actual -ne $Expected) {
        throw ("{0} Expected={1} Actual={2}" -f $Message, $Expected, $Actual)
    }
}

function Assert-MatchText {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )
    Assert-True -Condition ($Text -match $Pattern) -Message $Message
}

function New-TestNovelRoot {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("NovelCodexTest-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return $root
}

function New-ReviewFile {
    param(
        [string]$NovelRoot,
        [string]$Dimension,
        [string]$Chapter,
        [string]$Phase,
        [string]$Round = "1"
    )
    $path = Join-Path $NovelRoot ("logs\review-{0}-ch{1}-{2}-r{3}.txt" -f $Dimension, $Chapter, $Phase, $Round)
    Write-Utf8File -Path $path -Content ("[REVIEW-{0}] 5/5 PASS | report={1}`n" -f $Dimension, $path)
}

function New-ReviewEvidence {
    param(
        [string]$NovelRoot,
        [string]$Dimension,
        [string]$Chapter,
        [string]$Phase,
        [string]$Round = "r1",
        [double]$Score = 5.0,
        [bool]$Pass = $true
    )
    $summary = "[REVIEW-{0}] {1}/5 {2} | report=logs/review-{0}-ch{3}-{4}-{5}.txt" -f $Dimension, $Score, ($(if ($Pass) { "PASS" } else { "FAIL" })), $Chapter, $Phase, $Round
    $entry = [PSCustomObject]@{
        chapter = $Chapter
        phase = $Phase
        round = $Round
        dimension = $Dimension
        score = $Score
        pass = $Pass
        report = "logs/review-$Dimension-ch$Chapter-$Phase-$Round.txt"
        summary = $summary
        created_at = "2026-01-01T00:00:00+00:00"
    }
    Append-Utf8File -Path (Join-Path $NovelRoot "logs\review-manifest.jsonl") -Content (($entry | ConvertTo-Json -Compress) + [Environment]::NewLine)
}

function Seed-MinimalChapter {
    param(
        [string]$NovelRoot,
        [string]$Chapter = "01"
    )
    Write-Utf8File -Path (Join-Path $NovelRoot "drafts\$Chapter-blueprint.md") -Content "# blueprint`n"
    foreach ($dim in @("consistency-facts", "logic", "pacing", "plot-engineering")) {
        New-ReviewFile -NovelRoot $NovelRoot -Dimension $dim -Chapter $Chapter -Phase "blueprint"
        New-ReviewEvidence -NovelRoot $NovelRoot -Dimension $dim -Chapter $Chapter -Phase "blueprint"
    }

    Write-Utf8File -Path (Join-Path $NovelRoot "drafts\$Chapter-outline.md") -Content "# outline`n"
    foreach ($dim in @(
        "consistency-facts", "logic", "pacing", "plot-engineering",
        "consistency-narrative", "language", "dialogue", "description",
        "ai-vocab", "ai-structure", "ai-human"
    )) {
        New-ReviewFile -NovelRoot $NovelRoot -Dimension $dim -Chapter $Chapter -Phase "outline"
        New-ReviewEvidence -NovelRoot $NovelRoot -Dimension $dim -Chapter $Chapter -Phase "outline"
    }

    $chapterFileName = ([char]0x7B2C) + $Chapter + ([char]0x7AE0) + "-test.txt"
    Write-Utf8File -Path (Join-Path $NovelRoot ("output\" + $chapterFileName)) -Content "Chapter 1 Test`n`nThis is a metadata-only test body.`n"
    foreach ($dim in @(
        "consistency-facts", "logic", "pacing", "plot-engineering",
        "consistency-narrative", "language", "dialogue", "description",
        "ai-vocab", "ai-structure", "ai-human", "reader-immersion"
    )) {
        New-ReviewFile -NovelRoot $NovelRoot -Dimension $dim -Chapter $Chapter -Phase "draft"
        New-ReviewEvidence -NovelRoot $NovelRoot -Dimension $dim -Chapter $Chapter -Phase "draft"
    }

    New-ReviewFile -NovelRoot $NovelRoot -Dimension "stress-test" -Chapter $Chapter -Phase "stress-test"
    New-ReviewEvidence -NovelRoot $NovelRoot -Dimension "stress-test" -Chapter $Chapter -Phase "stress-test"
    Write-Utf8File -Path (Join-Path $NovelRoot "logs\post-ch$Chapter.txt") -Content "[POST] ch$Chapter done: 100 words, final_score=5/5, facts_extracted=1, summary_appended=Y`n"
    Write-Utf8File -Path (Join-Path $NovelRoot "logs\facts-ch$Chapter.txt") -Content "[FACTS] ch=$Chapter|new=1|conflicts=0|file=memory/facts.md`n"
    Append-Utf8File -Path (Join-Path $NovelRoot "logs\chapter-index.md") -Content ("| {0} | test | completed metadata test chapter | 100 |`n" -f $Chapter)
}

$tempRoots = New-Object System.Collections.Generic.List[string]
try {
    Assert-Equal -Actual (Split-Path -Leaf $SystemRoot) -Expected "system" -Message "system implementation files should live under a root-level system folder"
    foreach ($required in @(".codex-plugin", "AGENTS.md", "agents", "scripts", "templates", "references", "settings", "tests")) {
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $SystemRoot $required)) -Message "system folder is missing $required"
    }
    foreach ($forbidden in @(".codex-plugin", "AGENTS.md", "agents", "scripts", "templates", "references", "settings", "tests", "start-novel-codex.ps1", "resume-latest-novel-codex.ps1")) {
        Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $InstallRoot $forbidden))) -Message "root should not contain system/internal item $forbidden"
    }
    foreach ($allowed in @("start-novel-codex.bat", "README.md", "novels", "system")) {
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $InstallRoot $allowed)) -Message "root should contain $allowed"
    }
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $InstallRoot "resume-latest-novel-codex.bat"))) -Message "root should not contain a latest-book resume BAT; resume belongs inside each novel folder"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $SystemRoot "resume-latest-novel-codex.ps1"))) -Message "system should not provide a latest-book resume entrypoint"
    $rootItems = @(Get-ChildItem -LiteralPath $InstallRoot -Force | Where-Object {
        $_.Name -notin @(".git", ".gitignore", ".gitattributes", "README.md", "start-novel-codex.bat", "novels", "system")
    })
    Assert-Equal -Actual $rootItems.Count -Expected 0 -Message ("root has unexpected leftover items: " + (($rootItems | ForEach-Object Name) -join ", "))
    $rootLauncher = [System.IO.File]::ReadAllText((Join-Path $InstallRoot "start-novel-codex.bat"), [System.Text.Encoding]::UTF8)
    Assert-MatchText -Text $rootLauncher -Pattern "system\\start-novel-codex\.ps1" -Message "root start BAT should delegate to system/start-novel-codex.ps1"

    $novelRoot = New-TestNovelRoot
    $tempRoots.Add($novelRoot) | Out-Null

    $initScript = Join-Path $SystemRoot "scripts\init-workspace.ps1"
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $novelRoot | Out-Null

    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $novelRoot ".novelcodex\novel-workspace.json")) -Message "init should mark isolated novel workspaces"
    foreach ($dir in @("drafts", "logs", "memory", "output")) {
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $novelRoot $dir)) -Message "missing runtime dir $dir in isolated novel root"
    }
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $novelRoot "runtime.json")) -Message "runtime.json should be created in novel root"
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $novelRoot "memory\facts.md")) -Message "memory templates should be copied from system root"

    $recordScript = Join-Path $SystemRoot "scripts\record-agent-call.ps1"
    Assert-True -Condition (Test-Path -LiteralPath $recordScript) -Message "record-agent-call.ps1 should exist"
    powershell -NoProfile -ExecutionPolicy Bypass -File $recordScript -NovelRoot $novelRoot -Chapter 01 -Phase draft -Round r1 -Agent reviewer-logic -Event start -Eta "1-2min" | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $recordScript -NovelRoot $novelRoot -Chapter 01 -Phase draft -Round r1 -Agent reviewer-logic -Event return -Summary "[REVIEW-logic] 5/5 PASS | report=logs/review-logic-ch01-draft-r1.txt" | Out-Null
    $workflowText = Read-Utf8File -Path (Join-Path $novelRoot "logs\workflow-log.md")
    Assert-MatchText -Text $workflowText -Pattern "\[01-draft-r1\].*reviewer-logic" -Message "record script should append start heartbeat"
    Assert-MatchText -Text $workflowText -Pattern "\[01-draft-r1\].*\[REVIEW-logic\] 5/5 PASS" -Message "record script should append return heartbeat"
    $agentCallsText = Read-Utf8File -Path (Join-Path $novelRoot "logs\agent-calls.md")
    Assert-MatchText -Text $agentCallsText -Pattern "reviewer-logic" -Message "record script should append agent-calls row"
    $manifestText = Read-Utf8File -Path (Join-Path $novelRoot "logs\review-manifest.jsonl")
    Assert-MatchText -Text $manifestText -Pattern '"dimension":"logic"' -Message "record script should append review manifest dimension"
    Assert-MatchText -Text $manifestText -Pattern '"pass":true' -Message "record script should append review manifest pass flag"

    $runtimePath = Join-Path $novelRoot "runtime.json"
    $runtime = Read-Utf8File -Path $runtimePath | ConvertFrom-Json
    $runtime.total_chapters_to_write = 1
    $runtime.last_completed_chapter = 1
    $runtime.quality_tier = "high"
    $runtime.story_seed = "test"
    Write-Utf8File -Path $runtimePath -Content ($runtime | ConvertTo-Json -Depth 20)

    $unconfirmedRoot = New-TestNovelRoot
    $tempRoots.Add($unconfirmedRoot) | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $unconfirmedRoot | Out-Null
    $unconfirmedRuntimePath = Join-Path $unconfirmedRoot "runtime.json"
    $unconfirmedRuntime = Read-Utf8File -Path $unconfirmedRuntimePath | ConvertFrom-Json
    $unconfirmedRuntime.total_chapters_to_write = 1
    Write-Utf8File -Path $unconfirmedRuntimePath -Content ($unconfirmedRuntime | ConvertTo-Json -Depth 20)
    Write-Utf8File -Path (Join-Path $unconfirmedRoot "drafts\01-blueprint.md") -Content "# blueprint`n"
    foreach ($dim in @("consistency-facts", "logic", "pacing", "plot-engineering")) {
        New-ReviewFile -NovelRoot $unconfirmedRoot -Dimension $dim -Chapter "01" -Phase "blueprint"
    }
    $statusScript = Join-Path $SystemRoot "scripts\novel-status.ps1"
    $unconfirmedRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $statusScript -NovelRoot $unconfirmedRoot -WorkflowTail 0
    $unconfirmed = $unconfirmedRaw | ConvertFrom-Json
    Assert-Equal -Actual $unconfirmed.chapters[0].stage -Expected "needs-blueprint-review" -Message "file-only review reports should not advance without PASS evidence"
    Assert-MatchText -Text (($unconfirmed.chapters[0].blueprint_review_unconfirmed | ConvertTo-Json -Compress)) -Pattern "logic" -Message "status should expose unconfirmed file-only review dimensions"

    Seed-MinimalChapter -NovelRoot $novelRoot -Chapter "01"

    $statusRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $statusScript -NovelRoot $novelRoot -WorkflowTail 5
    $status = $statusRaw | ConvertFrom-Json
    Assert-Equal -Actual $status.system_root -Expected $SystemRoot -Message "status should report system root"
    Assert-Equal -Actual $status.novel_root -Expected $novelRoot -Message "status should report novel root"
    Assert-Equal -Actual $status.chapters[0].stage -Expected "completed" -Message "chapter should be completed when reviews, stress, post, facts, index, and runtime marker exist"
    Assert-Equal -Actual $status.chapters[0].draft_review_count -Expected 12 -Message "draft review count should exclude independent stress test"
    Assert-True -Condition $status.chapters[0].stress_test_done -Message "stress test marker should be detected separately"
    Assert-True -Condition $status.chapters[0].postprocess_done -Message "postprocess marker should be detected"
    Assert-True -Condition $status.chapters[0].facts_done -Message "fact extractor marker should be detected"

    $promptScript = Join-Path $SystemRoot "scripts\novel-next-prompt.ps1"
    $prompt = powershell -NoProfile -ExecutionPolicy Bypass -File $promptScript -SystemRoot $SystemRoot -NovelRoot $novelRoot -WorkflowTail 5
    Assert-MatchText -Text $prompt -Pattern ([regex]::Escape("SystemRoot: $SystemRoot")) -Message "resume prompt should include system root"
    Assert-MatchText -Text $prompt -Pattern ([regex]::Escape("NovelRoot: $novelRoot")) -Message "resume prompt should include novel root"
    Assert-MatchText -Text $prompt -Pattern "first_unfinished_stage: completed" -Message "resume prompt should state completed when no open chapter remains"
    Assert-MatchText -Text $prompt -Pattern "logs/chapter-index\.md" -Message "resume prompt should keep chapter-index as canonical"

    $prepareResumeScript = Join-Path $SystemRoot "scripts\prepare-open-ended-resume.ps1"
    Assert-True -Condition (Test-Path -LiteralPath $prepareResumeScript) -Message "prepare-open-ended-resume.ps1 should exist"
    $prepareRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $prepareResumeScript -NovelRoot $novelRoot
    $prepare = $prepareRaw | ConvertFrom-Json
    Assert-Equal -Actual ([int]$prepare.resume_target_chapter) -Expected 2 -Message "open-ended resume should target the chapter after the latest completed chapter"
    Assert-Equal -Actual ([int]$prepare.total_chapters_to_write) -Expected 2 -Message "open-ended resume should move total_chapters_to_write to the next chapter only"
    $preparedRuntime = Read-Utf8File -Path $runtimePath | ConvertFrom-Json
    Assert-Equal -Actual $preparedRuntime.book_mode -Expected "open-ended-resume" -Message "open-ended resume should mark book_mode"
    Assert-True -Condition ([bool]$preparedRuntime.open_ended_resume) -Message "open-ended resume should mark open_ended_resume"
    Assert-Equal -Actual ([int]$preparedRuntime.resume_target_chapter) -Expected 2 -Message "open-ended resume should persist resume_target_chapter"

    $openPrompt = powershell -NoProfile -ExecutionPolicy Bypass -File $promptScript -SystemRoot $SystemRoot -NovelRoot $novelRoot -WorkflowTail 5
    Assert-MatchText -Text $openPrompt -Pattern "open_ended_resume: true" -Message "resume prompt should expose open-ended resume mode"
    Assert-MatchText -Text $openPrompt -Pattern "first_unfinished_chapter: 02" -Message "resume prompt should continue with the next chapter after completed target"
    Assert-MatchText -Text $openPrompt -Pattern "first_unfinished_stage: needs-blueprint" -Message "resume prompt should make the next chapter available"
    Assert-MatchText -Text $openPrompt -Pattern "moving frontier" -Message "resume prompt should instruct the orchestrator to keep extending the chapter frontier"

    $fakeLargeTotalRoot = New-TestNovelRoot
    $tempRoots.Add($fakeLargeTotalRoot) | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $fakeLargeTotalRoot | Out-Null
    $fakeLargeRuntimePath = Join-Path $fakeLargeTotalRoot "runtime.json"
    $fakeLargeRuntime = Read-Utf8File -Path $fakeLargeRuntimePath | ConvertFrom-Json
    $fakeLargeRuntime.total_chapters_to_write = 1005
    $fakeLargeRuntime.last_completed_chapter = 8
    Write-Utf8File -Path $fakeLargeRuntimePath -Content ($fakeLargeRuntime | ConvertTo-Json -Depth 20)
    $fakeLargePrepareRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $prepareResumeScript -NovelRoot $fakeLargeTotalRoot
    $fakeLargePrepare = $fakeLargePrepareRaw | ConvertFrom-Json
    Assert-Equal -Actual ([int]$fakeLargePrepare.total_chapters_to_write) -Expected 9 -Message "open-ended resume should collapse large fake totals to last_completed_chapter + 1"

    $resumeLauncherRoot = New-TestNovelRoot
    $tempRoots.Add($resumeLauncherRoot) | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $resumeLauncherRoot | Out-Null
    $resumeLauncherRuntimePath = Join-Path $resumeLauncherRoot "runtime.json"
    $resumeLauncherRuntime = Read-Utf8File -Path $resumeLauncherRuntimePath | ConvertFrom-Json
    $resumeLauncherRuntime.total_chapters_to_write = 1005
    $resumeLauncherRuntime.last_completed_chapter = 8
    Write-Utf8File -Path $resumeLauncherRuntimePath -Content ($resumeLauncherRuntime | ConvertTo-Json -Depth 20)

    $mockBinRoot = New-TestNovelRoot
    $tempRoots.Add($mockBinRoot) | Out-Null
    $mockCodex = Join-Path $mockBinRoot "codex.cmd"
    Write-Utf8File -Path $mockCodex -Content "@echo off`r`nexit /b 0`r`n"
    $oldPath = $env:Path
    try {
        $env:Path = $mockBinRoot + ";" + $oldPath
        powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SystemRoot "start-novel-codex.ps1") -Resume -NovelRoot $resumeLauncherRoot | Out-Null
    } finally {
        $env:Path = $oldPath
    }
    $resumeLauncherPrepared = Read-Utf8File -Path $resumeLauncherRuntimePath | ConvertFrom-Json
    Assert-Equal -Actual ([int]$resumeLauncherPrepared.total_chapters_to_write) -Expected 9 -Message "resume launcher should prepare open-ended resume before starting Codex"
    Assert-True -Condition ([bool]$resumeLauncherPrepared.open_ended_resume) -Message "resume launcher should persist open-ended mode"

    $failEntry = [PSCustomObject]@{
        chapter = "01"
        phase = "draft"
        round = "r2"
        dimension = "language"
        score = 2.0
        pass = $false
        report = "logs/review-language-ch01-draft-r2.txt"
        summary = "[REVIEW-language] 2/5 FAIL | report=logs/review-language-ch01-draft-r2.txt"
        created_at = "2026-01-01T00:00:00+00:00"
    }
    Append-Utf8File -Path (Join-Path $novelRoot "logs\review-manifest.jsonl") -Content (($failEntry | ConvertTo-Json -Compress) + [Environment]::NewLine)
    $blockedRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $statusScript -NovelRoot $novelRoot -WorkflowTail 5
    $blocked = $blockedRaw | ConvertFrom-Json
    Assert-Equal -Actual $blocked.chapters[0].stage -Expected "needs-draft-review" -Message "manifest FAIL should block phase completion even when report files exist"
    Assert-MatchText -Text (($blocked.chapters[0].draft_review_failed | ConvertTo-Json -Compress)) -Pattern "language" -Message "status should expose manifest-failed draft dimension"

    $gateScript = Join-Path $SystemRoot "scripts\review-gate.ps1"
    Assert-True -Condition (Test-Path -LiteralPath $gateScript) -Message "review-gate.ps1 should exist"

    $lowMeanRoot = New-TestNovelRoot
    $tempRoots.Add($lowMeanRoot) | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $lowMeanRoot | Out-Null
    $lowMeanRuntimePath = Join-Path $lowMeanRoot "runtime.json"
    $lowMeanRuntime = Read-Utf8File -Path $lowMeanRuntimePath | ConvertFrom-Json
    $lowMeanRuntime.total_chapters_to_write = 1
    $lowMeanRuntime.quality_tier = "high"
    Write-Utf8File -Path $lowMeanRuntimePath -Content ($lowMeanRuntime | ConvertTo-Json -Depth 20)
    foreach ($dim in @("consistency-facts", "logic", "pacing", "plot-engineering")) {
        New-ReviewEvidence -NovelRoot $lowMeanRoot -Dimension $dim -Chapter "01" -Phase "blueprint" -Score 4.0 -Pass $true
    }
    $lowMeanGateRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $gateScript -NovelRoot $lowMeanRoot -Chapter 01 -Phase blueprint
    $lowMeanGate = $lowMeanGateRaw | ConvertFrom-Json
    Assert-True -Condition (-not [bool]$lowMeanGate.pass) -Message "review gate should fail high-tier phases when mean score is below threshold"
    Assert-Equal -Actual ([double]$lowMeanGate.mean_score) -Expected 4.0 -Message "review gate should report mean score"
    Assert-Equal -Actual ([double]$lowMeanGate.threshold) -Expected 4.5 -Message "review gate should derive high-tier threshold"

    $passGateRoot = New-TestNovelRoot
    $tempRoots.Add($passGateRoot) | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $passGateRoot | Out-Null
    $passRuntimePath = Join-Path $passGateRoot "runtime.json"
    $passRuntime = Read-Utf8File -Path $passRuntimePath | ConvertFrom-Json
    $passRuntime.total_chapters_to_write = 1
    $passRuntime.quality_tier = "high"
    Write-Utf8File -Path $passRuntimePath -Content ($passRuntime | ConvertTo-Json -Depth 20)
    foreach ($dim in @("consistency-facts", "logic", "pacing", "plot-engineering")) {
        New-ReviewEvidence -NovelRoot $passGateRoot -Dimension $dim -Chapter "01" -Phase "blueprint" -Score 4.5 -Pass $true
    }
    $passGateRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $gateScript -NovelRoot $passGateRoot -Chapter 01 -Phase blueprint
    $passGate = $passGateRaw | ConvertFrom-Json
    Assert-True -Condition ([bool]$passGate.pass) -Message "review gate should pass when all dimensions pass and mean reaches threshold"
    Assert-Equal -Actual ([int]$passGate.fail_count) -Expected 0 -Message "review gate should report zero failed dimensions"

    $highestLowRoot = New-TestNovelRoot
    $tempRoots.Add($highestLowRoot) | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $highestLowRoot | Out-Null
    $highestLowRuntimePath = Join-Path $highestLowRoot "runtime.json"
    $highestLowRuntime = Read-Utf8File -Path $highestLowRuntimePath | ConvertFrom-Json
    $highestLowRuntime.total_chapters_to_write = 1
    $highestLowRuntime.quality_tier = "highest"
    Write-Utf8File -Path $highestLowRuntimePath -Content ($highestLowRuntime | ConvertTo-Json -Depth 20)
    foreach ($dim in @("consistency-facts", "logic", "pacing", "plot-engineering")) {
        New-ReviewEvidence -NovelRoot $highestLowRoot -Dimension $dim -Chapter "01" -Phase "blueprint" -Score 4.99 -Pass $true
    }
    $highestLowGateRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $gateScript -NovelRoot $highestLowRoot -Chapter 01 -Phase blueprint
    $highestLowGate = $highestLowGateRaw | ConvertFrom-Json
    Assert-True -Condition (-not [bool]$highestLowGate.pass) -Message "review gate should fail highest-tier phases below a perfect mean"
    Assert-Equal -Actual ([double]$highestLowGate.threshold) -Expected 5.0 -Message "review gate should derive highest-tier threshold"

    $highestPassRoot = New-TestNovelRoot
    $tempRoots.Add($highestPassRoot) | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $highestPassRoot | Out-Null
    $highestPassRuntimePath = Join-Path $highestPassRoot "runtime.json"
    $highestPassRuntime = Read-Utf8File -Path $highestPassRuntimePath | ConvertFrom-Json
    $highestPassRuntime.total_chapters_to_write = 1
    $highestPassRuntime.quality_tier = "highest"
    Write-Utf8File -Path $highestPassRuntimePath -Content ($highestPassRuntime | ConvertTo-Json -Depth 20)
    foreach ($dim in @("consistency-facts", "logic", "pacing", "plot-engineering")) {
        New-ReviewEvidence -NovelRoot $highestPassRoot -Dimension $dim -Chapter "01" -Phase "blueprint" -Score 5.0 -Pass $true
    }
    $highestPassGateRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $gateScript -NovelRoot $highestPassRoot -Chapter 01 -Phase blueprint
    $highestPassGate = $highestPassGateRaw | ConvertFrom-Json
    Assert-True -Condition ([bool]$highestPassGate.pass) -Message "review gate should pass highest-tier phases only when every dimension reaches 5/5"

    $unconfirmedGateRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $gateScript -NovelRoot $unconfirmedRoot -Chapter 01 -Phase blueprint
    $unconfirmedGate = $unconfirmedGateRaw | ConvertFrom-Json
    Assert-True -Condition (-not [bool]$unconfirmedGate.ready) -Message "review gate should not be ready when only file reports exist"
    Assert-MatchText -Text (($unconfirmedGate.unconfirmed | ConvertTo-Json -Compress)) -Pattern "logic" -Message "review gate should expose unconfirmed dimensions"

    $lookupScript = Join-Path $SystemRoot "scripts\consistency-lookup.ps1"
    Assert-True -Condition (Test-Path -LiteralPath $lookupScript) -Message "consistency-lookup.ps1 should exist"
    $lookupRoot = New-TestNovelRoot
    $tempRoots.Add($lookupRoot) | Out-Null
    powershell -NoProfile -ExecutionPolicy Bypass -File $initScript -SystemRoot $SystemRoot -NovelRoot $lookupRoot | Out-Null
    Write-Utf8File -Path (Join-Path $lookupRoot "memory\facts.md") -Content ("ch01: pantry key belongs to Lin; market rule A stays stable.`n")
    Write-Utf8File -Path (Join-Path $lookupRoot "logs\chapter-index.md") -Content ("| 01 | pantry scene | pantry key appears near the east bridge | 100 |`n")
    $lookupChapterName = ([char]0x7B2C) + "01" + ([char]0x7AE0) + "-lookup.txt"
    Write-Utf8File -Path (Join-Path $lookupRoot ("output\" + $lookupChapterName)) -Content "dummy chapter text should not be returned by default`n"
    $lookupRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $lookupScript -NovelRoot $lookupRoot -Query "pantry" -Limit 5 -SnippetChars 40
    $lookup = $lookupRaw | ConvertFrom-Json
    Assert-Equal -Actual $lookup.query -Expected "pantry" -Message "consistency lookup should echo the query"
    Assert-True -Condition ($lookup.compact_matches.Count -ge 2) -Message "consistency lookup should search compact memory and chapter index files"
    Assert-MatchText -Text (($lookup.compact_matches | ConvertTo-Json -Compress)) -Pattern "memory/facts.md" -Message "consistency lookup should report compact memory sources"
    Assert-MatchText -Text (($lookup.compact_matches | ConvertTo-Json -Compress)) -Pattern "logs/chapter-index.md" -Message "consistency lookup should report chapter-index sources"
    Assert-MatchText -Text (($lookup.targeted_output_files | ConvertTo-Json -Compress)) -Pattern "lookup\.txt" -Message "consistency lookup should return targeted old chapter file paths without reading them"
    Assert-True -Condition (-not (($lookup.compact_matches | ConvertTo-Json -Compress) -match "dummy chapter text")) -Message "consistency lookup should not return old chapter body text by default"

    $doctorScript = Join-Path $SystemRoot "scripts\novel-doctor.ps1"
    Assert-True -Condition (Test-Path -LiteralPath $doctorScript) -Message "novel-doctor.ps1 should exist"
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SystemRoot "scripts\write-resume-files.ps1") -SystemRoot $SystemRoot -NovelRoot $unconfirmedRoot | Out-Null
    $doctorRaw = powershell -NoProfile -ExecutionPolicy Bypass -File $doctorScript -SystemRoot $SystemRoot -NovelRoot $unconfirmedRoot
    $doctor = $doctorRaw | ConvertFrom-Json
    Assert-True -Condition ([bool]$doctor.layout.root_is_clean) -Message "doctor should report clean root layout"
    Assert-Equal -Actual $doctor.first_unfinished.stage -Expected "needs-blueprint-review" -Message "doctor should expose first unfinished stage"
    Assert-MatchText -Text (($doctor.blockers.unconfirmed | ConvertTo-Json -Compress)) -Pattern "logic" -Message "doctor should expose active review blockers"
    Assert-True -Condition ([bool]$doctor.resume.root_start_bat) -Message "doctor should report root start BAT availability"
    Assert-True -Condition (-not ($doctor.resume.PSObject.Properties.Name -contains "root_resume_bat")) -Message "doctor should not report a root resume BAT"
    Assert-True -Condition ([bool]$doctor.resume.novel_resume_bat) -Message "doctor should report per-novel resume BAT availability"
    Assert-MatchText -Text $doctor.recommended_commands.next_prompt -Pattern "novel-next-prompt\.ps1" -Message "doctor should recommend safe next-prompt command"

    $launcher = [System.IO.File]::ReadAllText((Join-Path $SystemRoot "start-novel-codex.ps1"), [System.Text.Encoding]::UTF8)
    Assert-MatchText -Text $launcher -Pattern "New-NovelWorkspace" -Message "launcher should create a per-novel workspace"
    Assert-MatchText -Text $launcher -Pattern "novels" -Message "launcher should store generated novels under a novels directory"
    Assert-MatchText -Text $launcher -Pattern "resume-this-novel\.bat" -Message "launcher should write a per-novel resume BAT"
    Assert-MatchText -Text $launcher -Pattern "Resume requires -NovelRoot" -Message "launcher should require an explicit NovelRoot when resuming"
    Assert-True -Condition ($launcher -notmatch "Get-LatestNovelRoot") -Message "launcher should not resume an implicit latest novel"
    Assert-MatchText -Text $launcher -Pattern "4=highest" -Message "launcher should expose highest quality selection"
    Assert-MatchText -Text $launcher -Pattern "QualityHighest" -Message "launcher should normalize the highest quality tier"

    $writer = [System.IO.File]::ReadAllText((Join-Path $SystemRoot "agents\chapter-writer.md"), [System.Text.Encoding]::UTF8)
    Assert-MatchText -Text $writer -Pattern "run-ai-taste-lint\.ps1" -Message "chapter writer should use the Windows-safe lint wrapper"
    Assert-True -Condition ($writer -notmatch "bash scripts/normalize-text\.sh") -Message "chapter writer should not instruct Windows runs to call bash normalize scripts"

    $agents = [System.IO.File]::ReadAllText((Join-Path $SystemRoot "AGENTS.md"), [System.Text.Encoding]::UTF8)
    Assert-MatchText -Text $agents -Pattern "SystemRoot" -Message "AGENTS should distinguish system root from novel root"
    Assert-MatchText -Text $agents -Pattern "review-manifest\.jsonl" -Message "AGENTS should require structured review summaries for resumability"
    Assert-MatchText -Text $agents -Pattern "record-agent-call\.ps1" -Message "AGENTS should require the unified heartbeat/manifest recorder"
    Assert-MatchText -Text $agents -Pattern "review-gate\.ps1" -Message "AGENTS should require the executable review gate"
    Assert-MatchText -Text $agents -Pattern "consistency-lookup\.ps1" -Message "AGENTS should require executable targeted consistency lookup"
    Assert-MatchText -Text $agents -Pattern "novel-doctor\.ps1" -Message "AGENTS should document the quota-safe doctor command"
    Assert-MatchText -Text $agents -Pattern "targeted consistency lookup" -Message "AGENTS should require targeted consistency lookup before writing"
    Assert-MatchText -Text $agents -Pattern "highest" -Message "AGENTS should document the highest quality tier"
    Assert-MatchText -Text $agents -Pattern "5\.0" -Message "AGENTS should document the perfect-score threshold"

    $planner = [System.IO.File]::ReadAllText((Join-Path $SystemRoot "agents\chapter-planner.md"), [System.Text.Encoding]::UTF8)
    Assert-MatchText -Text $planner -Pattern "consistency-lookup\.ps1" -Message "chapter planner should call executable consistency lookup"
    $outlinePlanner = [System.IO.File]::ReadAllText((Join-Path $SystemRoot "agents\planner-outline.md"), [System.Text.Encoding]::UTF8)
    Assert-MatchText -Text $outlinePlanner -Pattern "consistency-lookup\.ps1" -Message "outline planner should call executable consistency lookup"
    Assert-MatchText -Text $writer -Pattern "consistency-lookup\.ps1" -Message "chapter writer should call executable consistency lookup"

    Write-Host "novel tooling tests passed"
}
finally {
    foreach ($root in $tempRoots) {
        if ($root -and (Test-Path -LiteralPath $root)) {
            Remove-Item -LiteralPath $root -Recurse -Force
        }
    }
}
