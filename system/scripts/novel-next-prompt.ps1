param(
    [string]$NovelRoot = "",
    [string]$SystemRoot = "",
    [int]$WorkflowTail = 8
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

$statusRaw = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SystemRoot "scripts\novel-status.ps1") -SystemRoot $SystemRoot -NovelRoot $NovelRoot -WorkflowTail $WorkflowTail
$status = $statusRaw | ConvertFrom-Json
$runtime = $status.runtime

$firstOpen = $null
foreach ($chapter in @($status.chapters)) {
    if ($chapter.stage -ne "completed") {
        $firstOpen = $chapter
        break
    }
}

if ($null -eq $firstOpen) {
    $firstOpen = [PSCustomObject]@{
        chapter = "--"
        stage = "completed"
        blueprint_review_count = 0
        outline_review_count = 0
        draft_review_count = 0
        stress_test_done = $true
        postprocess_done = $true
        facts_done = $true
    }
}

$useRealSubagents = "false"
if ($runtime -and ($runtime.PSObject.Properties.Name -contains "use_real_subagents") -and $runtime.use_real_subagents) {
    $useRealSubagents = "true"
}

$qualityTier = if ($runtime -and $runtime.quality_tier) { $runtime.quality_tier } else { "unknown" }
$totalChapters = if ($runtime -and $runtime.total_chapters_to_write) { $runtime.total_chapters_to_write } else { "unknown" }
$lastCompleted = if ($runtime -and ($runtime.PSObject.Properties.Name -contains "last_completed_chapter")) { $runtime.last_completed_chapter } else { 0 }
$bookMode = if ($runtime -and $runtime.book_mode) { $runtime.book_mode } else { "unknown" }
$openEndedResume = $false
if ($runtime -and ($runtime.PSObject.Properties.Name -contains "open_ended_resume")) {
    $openEndedResume = [bool]$runtime.open_ended_resume
}
$openEndedResumeText = if ($openEndedResume) { "true" } else { "false" }
$resumeTargetChapter = if ($runtime -and ($runtime.PSObject.Properties.Name -contains "resume_target_chapter")) { $runtime.resume_target_chapter } else { "unknown" }

$workflowTailText = ""
$workflowTailItems = @($status.workflow_tail)
if ($workflowTailItems.Count -gt 0) {
    $workflowTailText = (($workflowTailItems | ForEach-Object { [string]$_ }) -join "`n")
}

$prompt = @"
Continue NovelCodex from the first unfinished metadata stage.

SystemRoot: $SystemRoot
NovelRoot: $NovelRoot
quality_tier: $qualityTier
book_mode: $bookMode
total_chapters_to_write: $totalChapters
last_completed_chapter: $lastCompleted
use_real_subagents=$useRealSubagents
open_ended_resume: $openEndedResumeText
resume_target_chapter: $resumeTargetChapter
first_unfinished_chapter: $($firstOpen.chapter)
first_unfinished_stage: $($firstOpen.stage)
known_review_counts: blueprint=$($firstOpen.blueprint_review_count), outline=$($firstOpen.outline_review_count), draft=$($firstOpen.draft_review_count), stress_done=$($firstOpen.stress_test_done)
postprocess_done=$($firstOpen.postprocess_done)
facts_done=$($firstOpen.facts_done)

Hard rules:
- Follow SystemRoot/AGENTS.md. Do not ask the user during creation.
- System files live under SystemRoot. Novel runtime files live under NovelRoot.
- Read role rules from SystemRoot/agents/{role}.md. Write all drafts, output, logs, and memory under NovelRoot.
- If use_real_subagents=false, do not call spawn_agent, task, delegation, parallel-agent, or any real subagent tool.
- Main-agent context firewall is mandatory: do not read NovelRoot/output/*.txt, NovelRoot/drafts/*.md, NovelRoot/logs/review-*.txt, NovelRoot/memory/*.md, SystemRoot/references/*.md, SystemRoot/settings/*.md, and do not run recursive full-text search over those directories.
- Resume by metadata only. Use Test-Path/Get-Item/Get-ChildItem Name,Length,LastWriteTime, logs/review-manifest.jsonl summaries, logs/chapter-index.md, and workflow-log tail only.
- Role emulation may read only the whitelist named in that role prompt and must return one summary line before switching back to orchestrator identity.
- Before writing or planning a chapter, the active role must perform targeted consistency lookup using memory/facts.md, memory/timeline.md, memory/characters.md, memory/world.md, logs/chapter-index.md, and only the specific prior chapter files supplied in the prompt.
- Windows is the default platform. Do not call bash, .sh, wsl.exe, or Git Bash. Use SystemRoot scripts with .ps1 entrypoints.
- AI taste lint must use "$SystemRoot\scripts\run-ai-taste-lint.ps1" -SystemRoot "$SystemRoot" -NovelRoot "$NovelRoot" -Chapter NN or -Path <literal path>; do not pass wildcard Chinese paths to Python.
- Start at first_unfinished_stage and do not rewrite already-passed artifacts.
- Canonical chapter progress index is NovelRoot/logs/chapter-index.md.
- If open_ended_resume=true, run with a moving frontier: after each chapter is fully completed and last_completed_chapter is updated, set total_chapters_to_write and resume_target_chapter to last_completed_chapter + 1, then continue with that next chapter. Do not create a large fake total; keep only one future chapter visible. Stop only on user interrupt, quota/tool failure, or an unrecoverable blocker.

Recent workflow tail:
$workflowTailText
"@

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Output $prompt
