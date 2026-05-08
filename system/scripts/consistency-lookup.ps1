param(
    [string]$NovelRoot = "",
    [Parameter(Mandatory=$true)]
    [string]$Query,
    [int]$Limit = 8,
    [int]$SnippetChars = 180
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib-utf8.ps1"

if (-not $NovelRoot) {
    $NovelRoot = $PWD.Path
} elseif (Test-Path -LiteralPath $NovelRoot) {
    $NovelRoot = (Resolve-Path -LiteralPath $NovelRoot).Path
}

if ([string]::IsNullOrWhiteSpace($Query)) {
    Write-Error "Query is required"
    exit 1
}

if ($Limit -lt 1) { $Limit = 1 }
if ($SnippetChars -lt 40) { $SnippetChars = 40 }

function Convert-ToForwardSlash {
    param([string]$Path)
    return $Path.Replace("\", "/")
}

function New-Snippet {
    param(
        [string]$Text,
        [string]$Needle,
        [int]$MaxChars
    )
    $trimmed = $Text.Trim()
    if ($trimmed.Length -le $MaxChars) {
        return $trimmed
    }
    $idx = $trimmed.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase)
    if ($idx -lt 0) {
        return ($trimmed.Substring(0, $MaxChars - 3) + "...")
    }
    $windowStart = [Math]::Max(0, $idx - [int](($MaxChars - $Needle.Length) / 2))
    if ($windowStart + $MaxChars -gt $trimmed.Length) {
        $windowStart = [Math]::Max(0, $trimmed.Length - $MaxChars)
    }
    $length = [Math]::Min($MaxChars, $trimmed.Length - $windowStart)
    $snippet = $trimmed.Substring($windowStart, $length)
    if ($windowStart -gt 0 -and $snippet.Length -gt 3) {
        $snippet = "..." + $snippet.Substring(3)
    }
    if (($windowStart + $length) -lt $trimmed.Length -and $snippet.Length -gt 3) {
        $snippet = $snippet.Substring(0, $snippet.Length - 3) + "..."
    }
    return $snippet
}

function Test-LineMatch {
    param(
        [string]$Line,
        [string]$Needle
    )
    return ($Line.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Read-CompactMatches {
    param(
        [string]$Root,
        [string]$Needle,
        [int]$MaxMatches,
        [int]$MaxSnippetChars
    )
    $sources = @(
        "memory\facts.md",
        "memory\timeline.md",
        "memory\characters.md",
        "memory\world.md",
        "memory\foreshadowing.md",
        "memory\style-bible.md",
        "memory\lessons.md",
        "logs\chapter-index.md"
    )
    $matches = New-Object System.Collections.Generic.List[object]
    foreach ($source in $sources) {
        if ($matches.Count -ge $MaxMatches) { break }
        $path = Join-Path $Root $source
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($matches.Count -ge $MaxMatches) { break }
            if (-not (Test-LineMatch -Line $lines[$i] -Needle $Needle)) { continue }
            $matches.Add([PSCustomObject]@{
                source = Convert-ToForwardSlash $source
                line = $i + 1
                snippet = New-Snippet -Text $lines[$i] -Needle $Needle -MaxChars $MaxSnippetChars
            }) | Out-Null
        }
    }
    return $matches.ToArray()
}

function Get-MatchedIndexChapters {
    param(
        [string]$Root,
        [string]$Needle
    )
    $indexPath = Join-Path $Root "logs\chapter-index.md"
    if (-not (Test-Path -LiteralPath $indexPath)) { return @() }
    $chapters = New-Object System.Collections.Generic.List[string]
    $lines = [System.IO.File]::ReadAllLines($indexPath, [System.Text.Encoding]::UTF8)
    foreach ($line in $lines) {
        if (-not (Test-LineMatch -Line $line -Needle $Needle)) { continue }
        $match = [regex]::Match($line, '^\|\s*(?<chapter>\d{1,4})\s*\|')
        if ($match.Success) {
            $chapters.Add(("{0:D2}" -f [int]$match.Groups["chapter"].Value)) | Out-Null
        }
    }
    return @($chapters.ToArray() | Select-Object -Unique)
}

function Get-TargetedOutputFiles {
    param(
        [string]$Root,
        [string[]]$Chapters
    )
    $outputDir = Join-Path $Root "output"
    if (-not (Test-Path -LiteralPath $outputDir)) { return @() }
    $files = New-Object System.Collections.Generic.List[object]
    foreach ($chapter in $Chapters) {
        $padded = "{0:D2}" -f [int]$chapter
        $prefix = ([char]0x7B2C) + $padded + ([char]0x7AE0) + "-"
        $matches = @(Get-ChildItem -LiteralPath $outputDir -File -Filter "*.txt" |
            Where-Object { $_.Name.StartsWith($prefix) } |
            Sort-Object Name)
        foreach ($file in $matches) {
            $files.Add([PSCustomObject]@{
                chapter = $padded
                name = $file.Name
                path = $file.FullName
                length = $file.Length
            }) | Out-Null
        }
    }
    return $files.ToArray()
}

$compactMatches = @(Read-CompactMatches -Root $NovelRoot -Needle $Query -MaxMatches $Limit -MaxSnippetChars $SnippetChars)
$matchedChapters = @(Get-MatchedIndexChapters -Root $NovelRoot -Needle $Query)
$targetedFiles = @(Get-TargetedOutputFiles -Root $NovelRoot -Chapters $matchedChapters)

[PSCustomObject]@{
    novel_root = $NovelRoot
    query = $Query
    limit = $Limit
    snippet_chars = $SnippetChars
    compact_matches = @($compactMatches)
    matched_chapters = @($matchedChapters)
    targeted_output_files = @($targetedFiles)
    requires_targeted_chapter_check = [bool]($targetedFiles.Count -gt 0)
    note = "Default mode does not read output chapter bodies. Writer/reviewer roles may inspect only the targeted files listed here when a concrete conflict risk remains."
} | ConvertTo-Json -Depth 20
