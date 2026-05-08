param(
    [Parameter(Mandatory=$true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\lib-utf8.ps1"

$target = (Resolve-Path -LiteralPath $Path).Path
$text = Read-Utf8File -Path $target

$ellipsis = ([string]([char]0x2026) + [string]([char]0x2026))
$text = $text.Replace("...", $ellipsis)

function Convert-PairedQuote {
    param(
        [string]$Text,
        [char]$AsciiQuote,
        [char]$LeftQuote,
        [char]$RightQuote
    )
    $builder = New-Object System.Text.StringBuilder
    $count = 0
    foreach ($ch in $Text.ToCharArray()) {
        if ($ch -eq $AsciiQuote) {
            $count++
            if (($count % 2) -eq 1) {
                [void]$builder.Append($LeftQuote)
            } else {
                [void]$builder.Append($RightQuote)
            }
        } else {
            [void]$builder.Append($ch)
        }
    }
    return $builder.ToString()
}

$text = Convert-PairedQuote -Text $text -AsciiQuote ([char]34) -LeftQuote ([char]0x201C) -RightQuote ([char]0x201D)
$text = Convert-PairedQuote -Text $text -AsciiQuote ([char]39) -LeftQuote ([char]0x2018) -RightQuote ([char]0x2019)

$dashPattern = ([string]([char]0x2014) + [string]([char]0x2014)) + "|" + ([string]([char]0x2014)) + "|--"
$dashCount = ([regex]::Matches($text, $dashPattern)).Count

Write-Utf8File -Path $target -Content $text

Write-Output ("[normalize] {0}" -f $target)
Write-Output "  triple-dot and quote pairing: done"
if ($dashCount -gt 0) {
    Write-Output ("  [WARN] found {0} dash violations" -f $dashCount)
    exit 1
}

Write-Output "  [OK] no dash violations"
exit 0
