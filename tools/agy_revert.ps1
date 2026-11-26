# Antigravity'nin bir projeye yaptigi duzenlemeleri, projenin bir KOPYASINDA tersine uygular.
#
# Antigravity oturum kayitlarindaki (~\.gemini\antigravity\brain\*\.system_generated\logs\transcript_full.jsonl)
# edit_file {Path, Target, Replacement} ve replace_file_content {TargetFile, TargetContent, ReplacementContent}
# cagrilarini -Since zamanindan sonrasi icin yeniden eskiye siralar ve Replacement'i Target'a geri cevirir.
# Commit'lenmemis baska degisiklikler varken "AI'nin isinden onceki hali" kurmak icin (git ref yetmediginde).
# Tum dosyayi yazan write_file / write_to_file geri alinamaz; sayilir ve listelenir.
#
#   powershell -File tools\agy_revert.ps1 -Root <kopya klasoru> -Match PixelVFX-Arena -Since 2026-11-26T17:19
#
# -Match: kayittaki dosya yolunda projeyi taniyan klasor adi; yolun bundan sonrasi -Root'a eklenir.
# -Since / -Until: kaydin created_at alaniyla (UTC, ISO) metin olarak karsilastirilir.
# Asil projeye asla yazmaz: -Root, -Match klasorunun kendisiyse durur.

param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Match,
    [Parameter(Mandatory = $true)][string]$Since,
    [string]$Until = "9999",
    [string]$Brain = (Join-Path $env:USERPROFILE ".gemini\antigravity\brain")
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path $Root).Path
if ((Split-Path -Leaf $Root) -eq $Match -and (Test-Path (Join-Path $Root ".git"))) {
    Write-Host "[agy_revert] HATA: -Root asil proje gibi gorunuyor (.git var). Bir kopya verin." -ForegroundColor Red
    exit 2
}

$needle = "\" + $Match + "\"
$edits = New-Object System.Collections.ArrayList
$whole = New-Object System.Collections.ArrayList
$seq = 0
foreach ($log in Get-ChildItem -Path $Brain -Recurse -Filter "transcript_full.jsonl" -ErrorAction SilentlyContinue) {
    foreach ($line in [System.IO.File]::ReadLines($log.FullName)) {
        if ($line.IndexOf($Match) -lt 0) { continue }
        if ($line.IndexOf('"edit_file"') -lt 0 -and $line.IndexOf('"replace_file_content"') -lt 0 -and $line.IndexOf('write_') -lt 0) { continue }
        try { $j = $line | ConvertFrom-Json } catch { continue }
        $t = [string]$j.created_at
        if ($t -lt $Since -or $t -gt $Until) { continue }
        foreach ($tc in @($j.tool_calls)) {
            if ($null -eq $tc) { continue }
            $a = $tc.args
            $seq++
            $p = $null
            switch ($tc.name) {
                "edit_file" { $p = [string]$a.Path; $from = [string]$a.Target; $to = [string]$a.Replacement }
                "replace_file_content" { $p = [string]$a.TargetFile; $from = [string]$a.TargetContent; $to = [string]$a.ReplacementContent }
                { $_ -in "write_file", "write_to_file" } {
                    $wp = [string]$a.Path; if (-not $wp) { $wp = [string]$a.TargetFile }
                    if ($wp.IndexOf($needle) -ge 0) { [void]$whole.Add("$t $wp") }
                }
            }
            if (-not $p -or $p.IndexOf($needle) -lt 0) { continue }
            $rel = $p.Substring($p.IndexOf($needle) + $needle.Length)
            [void]$edits.Add([pscustomobject]@{ T = $t; Seq = $seq; Rel = $rel; From = $from; To = $to })
        }
    }
}

$ok = 0; $miss = 0
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($e in ($edits | Sort-Object T, Seq -Descending)) {
    $fp = Join-Path $Root $e.Rel
    if (-not (Test-Path $fp)) { $miss++; Write-Host "[agy_revert] YOK  $($e.T) $($e.Rel)" -ForegroundColor Yellow; continue }
    $s = [System.IO.File]::ReadAllText($fp)
    $to = $e.To; $from = $e.From
    if ($s.Contains("`r`n")) { $to = $to.Replace("`r`n", "`n").Replace("`n", "`r`n"); $from = $from.Replace("`r`n", "`n").Replace("`n", "`r`n") }
    $i = $s.IndexOf($to, [System.StringComparison]::Ordinal)
    if ($i -lt 0) {
        $miss++
        $short = $e.To; if ($short.Length -gt 80) { $short = $short.Substring(0, 80) }
        Write-Host "[agy_revert] KACTI $($e.T) $($e.Rel): $short" -ForegroundColor Yellow
        continue
    }
    $s = $s.Remove($i, $to.Length).Insert($i, $from)
    [System.IO.File]::WriteAllText($fp, $s, $utf8)
    $ok++
}
foreach ($w in $whole) { Write-Host "[agy_revert] TUM DOSYA YAZIMI (geri alinamaz): $w" -ForegroundColor Yellow }
Write-Host "[agy_revert] geri alinan=$ok kacan=$miss tum_dosya=$($whole.Count)" -ForegroundColor Cyan
