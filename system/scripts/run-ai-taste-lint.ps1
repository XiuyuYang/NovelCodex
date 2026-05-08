param(
    [string]$SystemRoot = "",
    [string]$NovelRoot = "",
    [string]$Chapter = "",
    [string]$Path = "",
    [int]$TimeoutSeconds = 60
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

function Resolve-Python {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py -and $py.Name -ieq "py.exe") {
        return [PSCustomObject]@{
            Exe = $py.Source
            PrefixArgs = @("-3")
        }
    }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        return [PSCustomObject]@{
            Exe = $python.Source
            PrefixArgs = @()
        }
    }
    throw "No Python launcher found. Install Python or add py/python to PATH."
}

function Resolve-ChapterOutput {
    param(
        [string]$Root,
        [string]$ChapterNumber
    )
    if (-not $ChapterNumber) {
        throw "Specify -Chapter or -Path."
    }
    $chapter = "{0:D2}" -f [int]$ChapterNumber
    $prefix = ([char]0x7B2C) + $chapter + ([char]0x7AE0) + "-"
    $outputDir = Join-Path $Root "output"
    if (-not (Test-Path -LiteralPath $outputDir)) {
        throw "Output directory not found: $outputDir"
    }
    $matches = @(Get-ChildItem -LiteralPath $outputDir -File -Filter "*.txt" | Where-Object { $_.Name.StartsWith($prefix) })
    if ($matches.Count -eq 0) {
        throw "No output file found for chapter $chapter."
    }
    if ($matches.Count -gt 1) {
        $names = ($matches | ForEach-Object { $_.Name }) -join ", "
        throw "Multiple output files found for chapter ${chapter}: $names"
    }
    return $matches[0].FullName
}

if ($Path) {
    $targetPath = (Resolve-Path -LiteralPath $Path).Path
} else {
    $targetPath = Resolve-ChapterOutput -Root $NovelRoot -ChapterNumber $Chapter
}

$scriptPath = Join-Path $SystemRoot "scripts\ai-taste-lint.py"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "ai-taste-lint.py not found: $scriptPath"
}

$python = Resolve-Python
$exe = $python.Exe
$prefixArgs = @($python.PrefixArgs)

$allArgs = @($prefixArgs) + @($scriptPath, $targetPath)

function Quote-Arg {
    param([string]$Value)
    if ($Value -match '^-[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        return $Value
    }
    return '"' + ($Value -replace '"', '\"') + '"'
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.Arguments = ($allArgs | ForEach-Object { Quote-Arg $_ }) -join " "
$psi.WorkingDirectory = $NovelRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
$psi.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8"

$process = [System.Diagnostics.Process]::Start($psi)
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    try { $process.Kill() } catch {}
    throw "ai-taste-lint timed out after $TimeoutSeconds seconds."
}

$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
if ($stdout) { Write-Output $stdout.TrimEnd() }
if ($stderr) { [Console]::Error.WriteLine($stderr.TrimEnd()) }
exit $process.ExitCode
