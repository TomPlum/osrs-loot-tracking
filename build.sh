#!/usr/bin/env sh
# Builds the self-contained index.html from src/dashboard_src.html.
#
# Cross-platform: needs only POSIX sh + awk + cat (all present on macOS, Linux, and
# Git Bash on Windows) -- no Node/Python/PowerShell required. Run from anywhere:
#
#     ./build.sh          # or:  sh build.sh
#
# The editable source references Google Fonts and Chart.js via CDN so it stays small
# and easy to edit; this inlines them (plus the Olmlet favicon) into one offline file.
#
# No mojibake risk: awk/cat pass bytes straight through, never decoding/re-encoding,
# so clean UTF-8 in stays clean UTF-8 out. The script itself is pure ASCII (it emits
# the em-dash in <title> as its UTF-8 bytes via printf).

set -eu
cd "$(dirname "$0")"

SRC="src/dashboard_src.html"
FONTS="src/vendor/fonts_inline.css"
CHART="src/vendor/chart.umd.min.js"
FAV="$(cat src/vendor/favicon_line.txt)"
OUT="index.html"
CDN='<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js"></script>'
EMDASH="$(printf '\342\200\224')"   # U+2014, keeps this script ASCII-only

tmp_css="$(mktemp)"; tmp_pre="$(mktemp)"; tmp_post="$(mktemp)"
trap 'rm -f "$tmp_css" "$tmp_pre" "$tmp_post"' EXIT

# inner of the head <style>...</style>
awk '/<\/style>/{f=0} f{print} /<style>/{f=1}' "$SRC" > "$tmp_css"

# body inner, split around the CDN <script> line (which we replace with inlined Chart.js)
# pass 1: body lines before the CDN script tag
awk -v cdn="$CDN" '
  $0==cdn{stop=1}
  inbody && !stop && $0!="</body>"{print}
  /<body>/{inbody=1}
' "$SRC" > "$tmp_pre"
# pass 2: body lines after the CDN script tag (up to </body>)
awk -v cdn="$CDN" '
  after && $0=="</body>"{exit}
  after{print}
  $0==cdn{after=1}
' "$SRC" > "$tmp_post"

{
  printf '%s\n' '<!DOCTYPE html>'
  printf '%s\n' '<html lang="en">'
  printf '%s\n' '<head>'
  printf '%s\n' '<meta charset="UTF-8">'
  printf '%s\n' '<meta name="viewport" content="width=device-width, initial-scale=1">'
  printf '%s\n' "<title>The Wolfo Bros Ledger $EMDASH Chambers of Xeric</title>"
  printf '%s\n' "$FAV"
  printf '%s\n' '<style>'
  cat "$FONTS"
  cat "$tmp_css"
  printf '%s\n' '</style>'
  printf '%s\n' '</head>'
  printf '%s\n' '<body>'
  cat "$tmp_pre"
  printf '%s\n' '<script>'
  cat "$CHART"
  printf '%s\n' '</script>'
  cat "$tmp_post"
  printf '%s\n' '</body>'
  printf '%s\n' '</html>'
} > "$OUT"

bytes=$(wc -c < "$OUT" | tr -d ' ')
cdn_gone=$(grep -c 'cdnjs' "$OUT" || true)
echo "index.html written: $bytes bytes"
echo "cdnjs refs left:    $cdn_gone"
[ "$cdn_gone" = "0" ] || { echo "ERROR: CDN reference still present" >&2; exit 1; }
