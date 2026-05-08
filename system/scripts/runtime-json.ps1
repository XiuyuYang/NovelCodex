# runtime.json 跨平台安全读写工具（PowerShell 镜像）
# 解决 log2/log3 中 PowerShell 默认 GBK 编码导致的中文乱码问题。
#
# 用法：
#   .\runtime-json.ps1 -Action read [-Key key]
#   .\runtime-json.ps1 -Action set -Key key -Value value
#   .\runtime-json.ps1 -Action increment-round -Chapter NN
#   .\runtime-json.ps1 -Action reset-rounds
#
# 所有读写一律 UTF-8 无 BOM。

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("read", "set", "increment-round", "reset-rounds")]
    [string]$Action,

    [string]$Key = "",
    [string]$Value = "",
    [string]$Chapter = "",
    [string]$NovelRoot = ""
)

$ErrorActionPreference = "Stop"

# v3：统一走 lib-utf8.ps1（Read-Utf8File / Write-Utf8File / Append-Utf8File）
. "$PSScriptRoot\lib-utf8.ps1"

if (-not $NovelRoot) { $NovelRoot = $PWD.Path }
$rt = Join-Path $NovelRoot "runtime.json"

if (-not (Test-Path $rt)) {
    Write-Error "[ERROR] runtime.json not found at: $rt"
    exit 1
}

# 强制 UTF-8 读（剥离可能的 BOM）
$rawText = Read-Utf8File -Path $rt
$data = $rawText | ConvertFrom-Json

function Save-Runtime {
    param($Data)
    $jsonOut = $Data | ConvertTo-Json -Depth 20
    Write-Utf8File -Path $rt -Content $jsonOut
}

switch ($Action) {
    "read" {
        if ($Key) {
            $val = $data.$Key
            Write-Output $val
        } else {
            $data | ConvertTo-Json -Depth 20
        }
    }

    "set" {
        if (-not $Key) {
            Write-Error "[ERROR] -Key required for 'set'"
            exit 1
        }
        # 尝试把 Value 解析成数字/布尔，否则保留字符串
        $parsed = $Value
        if ($Value -match '^-?\d+$') { $parsed = [int]$Value }
        elseif ($Value -match '^-?\d+\.\d+$') { $parsed = [double]$Value }
        elseif ($Value -eq "true") { $parsed = $true }
        elseif ($Value -eq "false") { $parsed = $false }

        if ($data.PSObject.Properties.Name -contains $Key) {
            $data.$Key = $parsed
        } else {
            $data | Add-Member -NotePropertyName $Key -NotePropertyValue $parsed
        }
        Save-Runtime $data
        Write-Output ("set {0}={1}" -f $Key, $parsed)
    }

    "increment-round" {
        if (-not $Chapter) {
            Write-Error "[ERROR] -Chapter required for 'increment-round'"
            exit 1
        }
        $chKey = "ch$Chapter"
        if (-not ($data.PSObject.Properties.Name -contains "revision_state")) {
            $data | Add-Member -NotePropertyName "revision_state" -NotePropertyValue ([PSCustomObject]@{})
        }
        $rs = $data.revision_state
        if (-not ($rs.PSObject.Properties.Name -contains $chKey)) {
            $rs | Add-Member -NotePropertyName $chKey -NotePropertyValue ([PSCustomObject]@{ round = 0; phase_resets = 0 })
        }
        $entry = $rs.$chKey
        if ($null -eq $entry.round) {
            $entry | Add-Member -NotePropertyName round -NotePropertyValue 0
        }
        $entry.round = [int]$entry.round + 1
        Save-Runtime $data
        Write-Output ("REVISION_ROUND={0}" -f $entry.round)
    }

    "reset-rounds" {
        if (-not ($data.PSObject.Properties.Name -contains "revision_state")) {
            return
        }
        foreach ($prop in $data.revision_state.PSObject.Properties) {
            if ($prop.Value.PSObject.Properties.Name -contains "round") {
                $prop.Value.round = 0
            }
        }
        Save-Runtime $data
        Write-Output "all rounds reset to 0"
    }
}
