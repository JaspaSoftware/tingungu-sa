param(
    [string]$ExtractDir = "$env:TEMP\infoHub_extract"
)

[xml]$sst = Get-Content "$ExtractDir\xl\sharedStrings.xml"
$ns = @{ x = "http://schemas.openxmlformats.org/spreadsheetml/2006/main" }
$strings = @()
foreach ($si in $sst.sst.si) {
    if ($si.t -ne $null) {
        $strings += $si.t
    } elseif ($si.r) {
        $text = ($si.r | ForEach-Object { $_.t }) -join ''
        $strings += $text
    } else {
        $strings += ''
    }
}

function Get-ColIndex($ref) {
    $letters = ($ref -replace '[0-9]', '')
    $idx = 0
    foreach ($c in $letters.ToCharArray()) {
        $idx = $idx * 26 + ([int][char]$c - [int][char]'A' + 1)
    }
    return $idx - 1
}

function Parse-Sheet($sheetPath) {
    [xml]$sheet = Get-Content $sheetPath
    $rows = @()
    foreach ($row in $sheet.worksheet.sheetData.row) {
        $rowData = @{}
        $maxCol = 0
        foreach ($c in $row.c) {
            if (-not $c.r) { continue }
            $colIdx = Get-ColIndex $c.r
            if ($colIdx -gt $maxCol) { $maxCol = $colIdx }
            $val = $null
            if ($c.t -eq 's') {
                if ($c.v -ne $null) { $val = $strings[[int]$c.v] }
            } elseif ($c.t -eq 'inlineStr') {
                $val = $c.is.t
            } else {
                $val = $c.v
            }
            $rowData[$colIdx] = $val
        }
        $arr = @()
        for ($i = 0; $i -le $maxCol; $i++) {
            $arr += , $rowData[$i]
        }
        $rows += , $arr
    }
    return $rows
}

$sheets = @("sheet1", "sheet2", "sheet3")
foreach ($s in $sheets) {
    Write-Output "=== $s ==="
    $rows = Parse-Sheet "$ExtractDir\xl\worksheets\$s.xml"
    foreach ($r in $rows) {
        Write-Output ($r -join " | ")
    }
    Write-Output ""
}
