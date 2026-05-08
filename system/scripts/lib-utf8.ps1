$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {
    if ([Console]::OutputEncoding.WebName -ne "utf-8") {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    }
} catch {
}

function Write-Utf8File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Path,

        [Parameter(Mandatory=$true, Position=1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Content
    )

    if ($null -eq $Content) {
        $Content = ""
    }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, $script:Utf8NoBom)
}

function Append-Utf8File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Path,

        [Parameter(Mandatory=$true, Position=1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Content
    )

    if ($null -eq $Content) {
        $Content = ""
    }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Path) {
        [System.IO.File]::AppendAllText($Path, $Content, $script:Utf8NoBom)
    } else {
        [System.IO.File]::WriteAllText($Path, $Content, $script:Utf8NoBom)
    }
}

function Read-Utf8File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("Read-Utf8File: file not found: {0}" -f $Path)
    }

    return [System.IO.File]::ReadAllText($Path, $script:Utf8NoBom)
}

function Test-Utf8Console {
    Write-Host ("Console encoding: {0}" -f [Console]::OutputEncoding.WebName)
    Write-Host ("Writer encoding: {0}; HasBOM={1}" -f $script:Utf8NoBom.WebName, ($script:Utf8NoBom.GetPreamble().Length -gt 0))
}
