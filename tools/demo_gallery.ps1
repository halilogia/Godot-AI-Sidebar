# Demo kütüphanesinin galerisini yeniden kurar: demos/*/screenshot.png dosyalarını demos/README.md'nin sonundaki
# <!-- galeri --> ... <!-- /galeri --> bölümüne yazar. tools/demo_library_add.ps1 her ekleme sonunda çağırır.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_gallery.ps1

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$Lib = Join-Path $Repo "demos"
$readme = Join-Path $Lib "README.md"
if (-not (Test-Path $readme)) { exit 0 }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$text = [IO.File]::ReadAllText($readme, $utf8)
# Üst bölüm (tablo başlığına kadar) + tür başına tek satır; yinelenen "## Galeri" başlıkları ve eski galeri bloğu atılır.
$all = $text -split "`r?`n"
$sep = 0
for ($i = 0; $i -lt $all.Count; $i++) { if ($all[$i] -match '^\|---') { $sep = $i; break } }
$rows = @{}
foreach ($l in $all[($sep + 1)..($all.Count - 1)]) {
    if ($l -match '^\| \[[^\]]*\]\(([^/]+)/\)') { $rows[$Matches[1]] = $l }
}
$text = (($all[0..$sep] + ($rows.Keys | Sort-Object | ForEach-Object { $rows[$_] })) -join "`n") + "`n"

$items = Get-ChildItem $Lib -Directory | Where-Object { Test-Path (Join-Path $_.FullName "screenshot.png") } | Sort-Object Name
if ($items.Count -gt 0) {
    $block = "`n## Galeri`n`n<!-- galeri -->`n"
    foreach ($d in $items) {
        $block += "**$($d.Name)**`n`n![$($d.Name)]($($d.Name)/screenshot.png)`n`n"
    }
    $block += "<!-- /galeri -->`n"
    $text = $text.TrimEnd() + "`n" + $block
}
[IO.File]::WriteAllText($readme, $text, $utf8)
Write-Host "[demo_gallery] $($items.Count) görüntü"
