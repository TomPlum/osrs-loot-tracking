#!/usr/bin/env sh
# Logs a new Chambers of Xeric purple across every place it needs to appear.
#
# Cross-platform: needs only POSIX sh + awk (same bar as build.sh) -- no Node/Python.
#
#     ./add-drop.sh --item tbow --kc 380 --mode CM --player Tom
#     ./add-drop.sh --item "arcane" --kc 381 --mode cm --player both --collection Will
#     ./add-drop.sh --item dust --kc 382 --mode CM --player Tom --notes B2B --dry-run
#
# It touches, in order:
#   cox-drop-log.txt        append a fixed-width row
#   src/dashboard_src.html  append a DATA entry; bump the COLLECTION row (if --collection)
#   README.md               drop count + the lifetime Tom/Will table
#   CLAUDE.md               the lifetime Tom/Will figures
#   index.html              regenerated via ./build.sh (skip with --no-build)
#
# No mojibake risk: awk streams bytes and never decodes/re-encodes, and this script is
# pure ASCII -- the files it edits stay valid UTF-8.

set -eu
cd "$(dirname "$0")"

LOG="cox-drop-log.txt"
SRC="src/dashboard_src.html"
README="README.md"
CLAUDEMD="CLAUDE.md"

usage() {
  cat <<'EOF'
Usage: ./add-drop.sh --item NAME --kc N --mode Regular|CM --player WHO [options]

Required:
  --item NAME         CoX unique. Aliases accepted (tbow, dex, arcane, buckler, kit,
                      kodai, bulwark, claws, anc hat/top/bottom, dhcb, maul, dust, olmlet).
  --kc N              Kill count at the drop. Regular and CM are independent counters.
  --mode M            Regular | CM  (reg/cm accepted).
  --player WHO        Tom | Will | Tom/Will (aka both/shared) | Aaron IM | none.

Options:
  --date DD/MM/YYYY   Defaults to today.
  --notes TEXT        e.g. B2B / B3B.
  --collection WHO    Whose collection log this increments: Tom | Will | none.
                      Defaults to --player when that is Tom or Will; for a shared
                      Tom/Will drop you must say which brother banked it, or pass
                      "none" to leave the lifetime totals alone.
  --force             Allow an exact duplicate row (same date+item+kc+mode).
  --no-build          Skip ./build.sh (index.html will be stale).
  --dry-run           Print what would be written and change nothing.
  -h, --help          This text.
EOF
}

die() { echo "add-drop: $*" >&2; exit 1; }

ITEM=""; KC=""; MODE=""; PLAYER=""; PLAYER_SET=0
DATE=""; NOTES=""; COLLECTION=""; COLLECTION_SET=0
FORCE=0; BUILD=1; DRYRUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --item)       ITEM="${2:-}"; shift 2 ;;
    --kc)         KC="${2:-}"; shift 2 ;;
    --mode)       MODE="${2:-}"; shift 2 ;;
    --player)     PLAYER="${2:-}"; PLAYER_SET=1; shift 2 ;;
    --date)       DATE="${2:-}"; shift 2 ;;
    --notes)      NOTES="${2:-}"; shift 2 ;;
    --collection) COLLECTION="${2:-}"; COLLECTION_SET=1; shift 2 ;;
    --force)      FORCE=1; shift ;;
    --no-build)   BUILD=0; shift ;;
    --dry-run)    DRYRUN=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "unknown argument: $1 (try --help)" ;;
  esac
done

[ -f "$LOG" ] || die "$LOG not found -- run this from the repo (or via its own path)."

# ---------- normalise item ----------
# lower-case, strip punctuation noise, so "Dinh's Bulwark" and "dinhs bulwark" agree
item_key=$(printf '%s' "$ITEM" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' | tr -d "'." )
case "$item_key" in
  "tbow"|"twisted bow")                            ITEM="Twisted Bow" ;;
  "dex"|"dex scroll"|"dexterous"|"dexterous prayer scroll"|"dex prayer scroll")
                                                   ITEM="Dexterous Prayer Scroll" ;;
  "arcane"|"arcane scroll"|"arcane prayer scroll") ITEM="Arcane Prayer Scroll" ;;
  "buckler"|"twisted buckler")                     ITEM="Twisted Buckler" ;;
  "kit"|"twisted kit"|"twisted ancestral kit"|"twisted ancestral colour kit"|"twisted ancestral color kit")
                                                   ITEM="Twisted Kit" ;;
  "kodai"|"kodai insignia")                        ITEM="Kodai Insignia" ;;
  "bulwark"|"dinhs bulwark"|"dinhs")               ITEM="Dinh's Bulwark" ;;
  "claws"|"dclaws"|"dragon claws")                 ITEM="Dragon Claws" ;;
  "anc hat"|"ancestral hat")                       ITEM="Ancestral Hat" ;;
  "anc top"|"ancestral top"|"ancestral robe top")  ITEM="Ancestral Robe Top" ;;
  "anc bottom"|"anc bottoms"|"ancestral bottom"|"ancestral bottoms"|"ancestral robe bottom")
                                                   ITEM="Ancestral Robe Bottom" ;;
  "dhcb"|"dhc"|"dragon hunter crossbow")           ITEM="Dragon Hunter Crossbow" ;;
  "maul"|"elder maul")                             ITEM="Elder Maul" ;;
  "dust"|"meta dust"|"metamorphic dust")           ITEM="Metamorphic Dust" ;;
  "olmlet"|"pet"|"olmlet pet"|"olmlet (pet)")      ITEM="Olmlet" ;;
  "")                                              die "--item is required (try --help)" ;;
  *)                                               die "unrecognised item: '$ITEM'. See --help for the accepted names." ;;
esac

# COLLECTION rows in the dashboard use sentence case and two different names
case "$ITEM" in
  "Twisted Kit") COLL_NAME="Twisted ancestral kit" ;;
  "Olmlet")      COLL_NAME="Olmlet (pet)" ;;
  *)             COLL_NAME=$(printf '%s' "$ITEM" | awk '{ print toupper(substr($0,1,1)) tolower(substr($0,2)) }') ;;
esac

# ---------- normalise mode ----------
mode_key=$(printf '%s' "$MODE" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
case "$mode_key" in
  "cm"|"challenge"|"challenge mode") MODE="CM" ;;
  "reg"|"regular"|"normal")          MODE="Regular" ;;
  "")                                die "--mode is required (Regular or CM)" ;;
  *)                                 die "unrecognised mode: '$MODE' (want Regular or CM)" ;;
esac

# Metamorphic dust is a CM-only drop -- catch the mis-log rather than bake it in
[ "$ITEM" = "Metamorphic Dust" ] && [ "$MODE" != "CM" ] && \
  die "Metamorphic Dust only drops in Challenge Mode -- check --mode."

# ---------- normalise player ----------
[ "$PLAYER_SET" = 1 ] || die "--player is required (Tom, Will, Tom/Will, Aaron IM, or none)"
player_key=$(printf '%s' "$PLAYER" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
case "$player_key" in
  "tom")                                        PLAYER="Tom" ;;
  "will")                                       PLAYER="Will" ;;
  "tom/will"|"will/tom"|"both"|"shared")        PLAYER="Tom/Will" ;;
  "aaron"|"aaron im"|"aaronim")                 PLAYER="Aaron IM" ;;
  "none"|"unknown"|"blank"|"")                  PLAYER="" ;;
  *)                                            die "unrecognised player: '$PLAYER'" ;;
esac

# ---------- collection-log owner ----------
if [ "$COLLECTION_SET" = 0 ]; then
  case "$PLAYER" in
    Tom)  COLLECTION="Tom" ;;
    Will) COLLECTION="Will" ;;
    *)    COLLECTION="none" ;;
  esac
fi
coll_key=$(printf '%s' "$COLLECTION" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
case "$coll_key" in
  "tom")                       COLLECTION="Tom" ;;
  "will")                      COLLECTION="Will" ;;
  "none"|"skip"|"neither"|"")  COLLECTION="none" ;;
  *)                           die "--collection must be Tom, Will, or none" ;;
esac

# A shared drop still lands in exactly one collection log; refusing to guess keeps the
# lifetime totals exact (they are reconciled from the real logs, not from this file).
if [ "$PLAYER" = "Tom/Will" ] && [ "$COLLECTION_SET" = 0 ]; then
  die "shared Tom/Will drop: pass --collection Tom|Will (whose log gained it), or --collection none."
fi

# ---------- date ----------
[ -n "$DATE" ] || DATE=$(date +%d/%m/%Y)
echo "$DATE" | grep -Eq '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' || die "--date must be DD/MM/YYYY (got '$DATE')"
d_day=${DATE%%/*}; d_rest=${DATE#*/}; d_mon=${d_rest%%/*}; d_year=${d_rest#*/}
[ "$d_mon" -ge 1 ] && [ "$d_mon" -le 12 ] || die "month out of range in '$DATE'"
[ "$d_day" -ge 1 ] && [ "$d_day" -le 31 ] || die "day out of range in '$DATE'"
ISO="$d_year-$d_mon-$d_day"

# ---------- kc ----------
echo "$KC" | grep -Eq '^[0-9]+$' || die "--kc must be a whole number (got '$KC')"

# KC is per-mode and monotonic in practice; a lower one is usually a typo, so warn loudly
prev_kc=$(awk -v m="$MODE" 'NR>2 && $0 !~ /^ *$/ {
    kc = substr($0, 38, 3); gsub(/ /, "", kc)
    md = substr($0, 43, 7); gsub(/ /, "", md)
    if (md == m && kc ~ /^[0-9]+$/ && kc+0 > max) max = kc+0
  } END { print max+0 }' "$LOG")
if [ "$KC" -le "$prev_kc" ]; then
  echo "add-drop: WARNING: $MODE kc $KC is not above the highest logged $MODE kc ($prev_kc)." >&2
fi

# ---------- duplicate guard ----------
if [ "$FORCE" = 0 ]; then
  dup=$(awk -v d="$DATE" -v i="$ITEM" -v k="$KC" -v m="$MODE" 'NR>2 {
      date = substr($0, 1, 10)
      item = substr($0, 13, 23); gsub(/ +$/, "", item)
      kc   = substr($0, 38, 3);  gsub(/ /, "", kc)
      md   = substr($0, 43, 7);  gsub(/ +$/, "", md)
      if (date == d && item == i && kc == k && md == m) { print NR; exit }
    }' "$LOG")
  [ -z "$dup" ] || die "identical row already at $LOG:$dup -- pass --force if it really dropped twice."
fi

# ---------- the new log row (fixed width: 10, 23, 3, 7, 8, then notes) ----------
ROW=$(printf '%s  %-23s  %3s  %-7s  %-8s  %s' "$DATE" "$ITEM" "$KC" "$MODE" "$PLAYER" "$NOTES" \
      | awk '{ sub(/[ \t]+$/, ""); print }')

# ---------- the new DATA entry ----------
if [ -n "$PLAYER" ]; then who_json="\"$PLAYER\""; else who_json="null"; fi
ENTRY="{\"date\": \"$DATE\", \"item\": \"$ITEM\", \"kc\": $KC, \"mode\": \"$MODE\", \"who\": $who_json, \"iso\": \"$ISO\"}"

if [ "$DRYRUN" = 1 ]; then
  echo "--- dry run, nothing written ---"
  echo "$LOG row:"
  echo "$ROW"
  echo
  echo "$SRC DATA entry:"
  echo "$ENTRY"
  echo
  if [ "$COLLECTION" = "none" ]; then
    echo "COLLECTION: unchanged (no collection-log owner given)"
  else
    echo "COLLECTION: \"$COLL_NAME\" +1 to $COLLECTION"
  fi
  exit 0
fi

# rewrite a file through awk, atomically-ish
rewrite() { # rewrite <file> <awk-program> [-v assignments...]
  f="$1"; shift
  t="$(mktemp)"
  awk "$@" "$f" > "$t"
  cat "$t" > "$f"
  rm -f "$t"
}

# ---------- 1. append to the raw log ----------
printf '%s\n' "$ROW" >> "$LOG"

# ---------- 2. append to DATA in the dashboard source ----------
rewrite "$SRC" -v entry="$ENTRY" '
  !done && /^const DATA = \[/ {
    n = length($0)
    if (substr($0, n - 1) == "];") {
      print substr($0, 1, n - 2) ", " entry "];"
      done = 1
      next
    }
  }
  { print }
  END { if (!done) { print "add-drop: could not find the DATA array" > "/dev/stderr"; exit 1 } }
'

# ---------- 3. bump the COLLECTION row ----------
if [ "$COLLECTION" != "none" ]; then
  rewrite "$SRC" -v name="$COLL_NAME" -v who="$COLLECTION" '
    !done {
      key = "[\"" name "\","
      p = index($0, key)
      if (p > 0) {
        rest = substr($0, p + length(key))
        sub(/\],?[ \t]*$/, "", rest)
        split(rest, a, ",")
        t = a[1] + 0; w = a[2] + 0
        if (who == "Tom") t++; else w++
        printf "  [\"%s\",%d,%d],\n", name, t, w
        done = 1
        next
      }
    }
    { print }
    END { if (!done) { print "add-drop: no COLLECTION row for \"" name "\"" > "/dev/stderr"; exit 1 } }
  '
fi

# ---------- 4. README: drop count + lifetime table ----------
TOTAL=$(awk 'NR>2 && $0 !~ /^ *$/' "$LOG" | wc -l | tr -d ' ')
rewrite "$README" -v total="$TOTAL" -v who="$COLLECTION" '
  /^[0-9]+ uniques logged since/ { sub(/^[0-9]+/, total) }
  who != "none" && /^\| \*\*Lifetime CoX uniques\*\* \|/ {
    n = split($0, a, "|")          # "", " **Lifetime...** ", " 55 ", " 48 ", ""
    col = (who == "Tom") ? 3 : 4
    v = a[col] + 0
    a[col] = " " (v + 1) " "
    out = a[1]
    for (i = 2; i <= n; i++) out = out "|" a[i]
    $0 = out
  }
  { print }
'

# ---------- 5. CLAUDE.md: the lifetime figures in prose ----------
if [ "$COLLECTION" != "none" ]; then
  rewrite "$CLAUDEMD" -v who="$COLLECTION" '
    match($0, /lifetime \*\*Tom [0-9]+ \/ Will [0-9]+\*\*/) {
      s = substr($0, RSTART, RLENGTH)
      split(s, a, " ")             # lifetime **Tom  N  /  Will  M**
      tom = a[3] + 0
      will = a[6] + 0              # trailing ** is stripped by the +0
      if (who == "Tom") tom++; else will++
      $0 = substr($0, 1, RSTART - 1) "lifetime **Tom " tom " / Will " will "**" substr($0, RSTART + RLENGTH)
    }
    { print }
  '
fi

echo "logged: $ROW"
echo "  DATA entry appended ($TOTAL drops total)"
if [ "$COLLECTION" = "none" ]; then
  echo "  COLLECTION unchanged (no collection-log owner)"
else
  echo "  COLLECTION \"$COLL_NAME\" +1 to $COLLECTION; README + CLAUDE.md lifetime totals bumped"
fi

# ---------- 6. rebuild index.html ----------
if [ "$BUILD" = 1 ]; then
  echo
  ./build.sh
else
  echo "  (skipped build -- index.html is now stale; run ./build.sh)"
fi
