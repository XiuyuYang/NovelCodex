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

$InstallRoot = Split-Path -Parent $SystemRoot
if ((Split-Path -Leaf $SystemRoot) -ne "system") {
    $InstallRoot = $SystemRoot
}

function Test-PathBool {
    param([string]$Path)
    return [bool](Test-Path -LiteralPath $Path)
}

function Get-RootLayout {
    param(
        [string]$Root,
        [string]$SystemRoot
    )
    $allowed = @(".git", ".gitignore", ".gitattributes", "README.md", "start-novel-codex.bat", "novels", "system")
    $unexpected = @(Get-ChildItem -LiteralPath $Root -Force | Where-Object { $_.Name -notin $allowed } | ForEach-Object { $_.Name })
    $requiredSystem = @(".codex-plugin", "AGENTS.md", "agents", "scripts", "templates", "references", "settings", "tests")
    $missingSystem = New-Object System.Collections.Generic.List[string]
    foreach ($item in $requiredSystem) {
        if (-not (Test-Path -LiteralPath (Join-Path $SystemRoot $item))) {
            $missingSystem.Add($item) | Out-Null
        }
    }
    [PSCustomObject]@{
        root = $Root
        root_is_clean = [bool]($unexpected.Count -eq 0 -and $missingSystem.Count -eq 0)
        unexpected_root_items = @($unexpected)
        missing_system_items = @($missingSystem.ToArray())
    }
}

function Get-FirstUnfinished {
    param($Status)
    foreach ($chapter in @($Status.chapters)) {
        if ($chapter.stage -ne "completed") {
            return $chapter
        }
    }
    return [PSCustomObject]@{
        chapter = "--"
        stage = "completed"
    }
}

function Get-ActiveBlockers {
    param($Chapter)
    $phase = ""
    $missing = @()
    $failed = @()
    $unconfirmed = @()
    switch ([string]$Chapter.stage) {
        "needs-blueprint-review" {
            $phase = "blueprint"
            $missing = @($Chapter.blueprint_review_missing)
            $failed = @($Chapter.blueprint_review_failed)
            $unconfirmed = @($Chapter.blueprint_review_unconfirmed)
        }
        "needs-outline-review" {
            $phase = "outline"
            $missing = @($Chapter.outline_review_missing)
            $failed = @($Chapter.outline_review_failed)
            $unconfirmed = @($Chapter.outline_review_unconfirmed)
        }
        "needs-draft-review" {
            $phase = "draft"
            $missing = @($Chapter.draft_review_missing)
            $failed = @($Chapter.draft_review_failed)
            $unconfirmed = @($Chapter.draft_review_unconfirmed)
        }
        "needs-stress-test" {
            $phase = "stress-test"
            $missing = @("stress-test")
        }
    }
    [PSCustomObject]@{
        phase = $phase
        missing = @($missing)
        failed = @($failed)
        unconfirmed = @($unconfirmed)
    }
}

$statusRaw = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SystemRoot "scripts\novel-status.ps1") -SystemRoot $SystemRoot -NovelRoot $NovelRoot -WorkflowTail $WorkflowTail
$status = $statusRaw | ConvertFrom-Json
$first = Get-FirstUnfinished -Status $status
$blockers = Get-ActiveBlockers -Chapter $first

$doctor = [PSCustomObject]@{
    system_root = $SystemRoot
    install_root = $InstallRoot
    novel_root = $NovelRoot
    layout = Get-RootLayout -Root $InstallRoot -SystemRoot $SystemRoot
    resume = [PSCustomObject]@{
        root_start_bat = Test-PathBool (Join-Path $InstallRoot "start-novel-codex.bat")
        novel_resume_bat = Test-PathBool (Join-Path $NovelRoot "resume-this-novel.bat")
        novel_resume_ps1 = Test-PathBool (Join-Path $NovelRoot "resume-this-novel.ps1")
    }
    first_unfinished = [PSCustomObject]@{
        chapter = $first.chapter
        stage = $first.stage
    }
    blockers = $blockers
    evidence = [PSCustomObject]@{
        review_manifest_count = $status.review_manifest_count
        workflow_review_evidence_count = $status.workflow_review_evidence_count
    }
    recommended_commands = [PSCustomObject]@{
        status = ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}" -SystemRoot "{1}" -NovelRoot "{2}"' -f (Join-Path $SystemRoot "scripts\novel-status.ps1"), $SystemRoot, $NovelRoot)
        next_prompt = ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}" -SystemRoot "{1}" -NovelRoot "{2}"' -f (Join-Path $SystemRoot "scripts\novel-next-prompt.ps1"), $SystemRoot, $NovelRoot)
        health = ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}" -SystemRoot "{1}" -NovelRoot "{2}"' -f (Join-Path $SystemRoot "scripts\novel-health.ps1"), $SystemRoot, $NovelRoot)
    }
    hints = @(
        "Use next_prompt for the smallest safe resume context.",
        "Use review-gate.ps1 after every review batch before advancing phases.",
        "Use consistency-lookup.ps1 inside planner/writer/reviewer roles before reading any targeted old chapter file."
    )
}

$doctor | ConvertTo-Json -Depth 30
