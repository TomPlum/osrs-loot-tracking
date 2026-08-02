# Builds the self-contained index.html from src/dashboard_src.html.
#
# The editable source (src/dashboard_src.html) references Google Fonts and Chart.js
# via CDN so it stays small and easy to edit. This script inlines those (plus the
# favicon) to produce a single self-contained index.html that works offline and on
# GitHub Pages. Run it from anywhere:  pwsh ./build.ps1   (or Windows PowerShell).
#
# IMPORTANT: all reads use UTF-8 explicitly. Do NOT switch to `Get-Content -Raw`,
# which in Windows PowerShell 5.1 decodes as the ANSI codepage and corrupts every
# em-dash / non-breaking space into mojibake (Â, â€”) baked into the output.

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM
$emdash = [char]0x2014   # this script stays pure-ASCII; emit unicode via code point

function ReadText($p) { [System.IO.File]::ReadAllText((Join-Path $here $p), [System.Text.Encoding]::UTF8) }

$src   = ReadText "src/dashboard_src.html"
$fonts = ReadText "src/vendor/fonts_inline.css"
$chart = ReadText "src/vendor/chart.umd.min.js"
$fav   = (ReadText "src/vendor/favicon_line.txt").Trim()

# --- pull the CSS out of the head <style> block ---
$sTag = "<style>"; $eTag = "</style>"
$si = $src.IndexOf($sTag); $ei = $src.IndexOf($eTag)
if ($si -lt 0 -or $ei -lt 0) { throw "could not locate <style> block" }
$css = $src.Substring($si + $sTag.Length, $ei - ($si + $sTag.Length))

# --- pull the body inner ---
$bTag = "<body>"; $beTag = "</body>"
$bi = $src.IndexOf($bTag); $be = $src.IndexOf($beTag)
if ($bi -lt 0 -or $be -lt 0) { throw "could not locate <body>" }
$body = $src.Substring($bi + $bTag.Length, $be - ($bi + $bTag.Length))

# --- inline Chart.js in place of the CDN <script src> ---
$cdn = '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js"></script>'
if (-not $body.Contains($cdn)) { throw "CDN chart <script> not found in body" }
$body = $body.Replace($cdn, "<script>`n$chart`n</script>")

# --- assemble the standalone document ---
$doc = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>The Wolfo Bros Ledger $emdash Chambers of Xeric</title>
$fav
<style>
$fonts
$css
</style>
</head>
<body>
$body
</body>
</html>
"@

$out = Join-Path $here "index.html"
[System.IO.File]::WriteAllText($out, $doc, $utf8)

$bytes = (Get-Item $out).Length
$mojibake = 0
foreach ($ch in $doc.ToCharArray()) { $c = [int]$ch; if ($c -eq 0xC2 -or $c -eq 0xE2) { $mojibake++ } }
"index.html written: $bytes bytes"
"CDN removed:        $(-not $doc.Contains('cdnjs'))"
"mojibake chars:     $mojibake"
if ($mojibake -gt 0) { throw "mojibake detected in output - check read encodings" }
