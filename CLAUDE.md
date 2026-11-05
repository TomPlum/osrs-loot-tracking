# CLAUDE.md — OSRS Loot Tracking

Guidance for Claude working in this repo. Read this before editing the dashboard.

## What this is

A drop log + single-page dashboard for **Chambers of Xeric** (Great Olm) purples, tracked by the
**Wolfo Bros** — **Wolfo** (Tom) & **Wolfo JR** (Will), with occasional guest raids from **Aaron**
(ironman). Live at https://tomplum.github.io/osrs-loot-tracking/ (GitHub Pages, `main` / root).

## Files

| Path | Role |
|------|------|
| `src/dashboard_src.html` | **The editable source.** CDN-based (small, easy to edit). Make all dashboard changes here, then run the build. |
| `src/vendor/` | Build inputs inlined by the build: `fonts_inline.css`, `chart.umd.min.js`, `favicon_line.txt` (Olmlet favicon data-URI). |
| `build.sh` | Inlines the vendor assets into `src/dashboard_src.html` to produce `index.html`. Cross-platform (POSIX sh + awk + cat). |
| `add-drop.sh` | Logs a new purple everywhere it needs to appear, then rebuilds. See [Logging a new drop](#logging-a-new-drop). |
| `.claude/commands/log-drop.md` | The `/log-drop` slash command — turns "tbow 380 cm tom" into the right `add-drop.sh` invocation. |
| `index.html` | **Generated — do not hand-edit.** Self-contained (fonts, Chart.js, item icons all inlined as base64 `data:` URIs), ~400 KB. |
| `cox-drop-log.txt` | Raw data: a single fixed-width text table, one row per purple. Source of truth for the drops. |
| `assets/icons/*.webp` | Item sprites (also inlined into `src` as `ICONS`; this folder is the original source). |
| `assets/avatars/*.webp` | Raider avatars — `wolfo.webp` (Tom), `wolfo-jr.webp` (Will). Inlined as `AVATARS`. |
| `README.md` | Human-facing project overview. |

## Data model (`cox-drop-log.txt`)

Columns: `Date  Item  KC  Mode  Player  Notes`

- **Date** — `DD/MM/YYYY`. Six early 2020 drops are undated (`??/??/2020`) and are excluded from all
  time-based charts.
- **KC** — kill count at the drop. **Regular and CM are independent counters** (CM started at 1kc on
  16/01/2022). So KC is not globally monotonic.
- **Mode** — `Regular` or `CM` (Challenge Mode).
- **Player** — attribution (see below).
- **Notes** — e.g. `B2B` / `B3B` back-to-back streaks.

### Attribution rules

Tom and Will raid together, so most drops can't be pinned to one brother. The `Player` column:

- `Tom` / `Will` — confirmed (unique item, or forced by collection-log counts).
- `Tom/Will` — a **shared** duplicate: one of the brothers, not attributable to a specific row.
- `Aaron IM` — Aaron's (guest ironman).
- blank — can't be pinned even to a brother.

Per-item **totals** are exact (reconciled from both collection logs: lifetime **Tom 55 / Will 50**),
even though individual shared rows aren't. In the dashboard JS the raw values are `"Tom"`, `"Will"`,
`"Tom/Will"`, `"Aaron IM"`, or `null`.

## Estimated attribution

`inferAttribution()` fills in the rows the log can't pin (`Tom/Will` and blank). **It never writes to
`cox-drop-log.txt`** — `who` stays exactly as logged and the estimate lives in a separate `inferred`
field, deliberately, so confirmed and guessed never blur.

The method leans on `COLLECTION` being exact: per item, a brother's residual (his collection total
minus his confirmed rows) bounds how many unassigned rows can be his. Several items solve outright
(4 shared Kodai, Tom needs 2 / Will needs 2); the rest are apportioned by largest remainder against
those residuals, then **interleaved through time** so neither cumulative line gets a fake plateau.

Invariants worth preserving if you touch this:

- **Never exceed a collection total.** `place = min(openRows, residualTom + residualWill)`, and each
  share is capped at that brother's residual.
- **Leftovers stay unattributed.** Two items have more logged rows than the collection logs can
  absorb (dexterous scrolls 25 vs 24, elder maul 3 vs 2), so one row of each is left unowned rather
  than force-fitted. Overall there's the opposite slack — the totals account for ~10 off-log raids.
- **Ordering matters, and it's all TDZ-sensitive.** The chain is: the inference block (which owns
  `COLL_TO_ITEM`) → `COLLECTION` → `INFERENCE = inferAttribution()` → everything that reads
  `ownerOf`/`inferred`. All three now sit **above the hero section**, because the who-donut consumes
  `e.inferred` far earlier in the file than the loot-by-raider section where `COLLECTION` used to
  live. Move any of them below a consumer and you get either a TDZ throw or, worse, a silently empty
  estimate — the donut showed `0 estimated / 69 unattributed` when it ran before the inference.

> **This whole file is one big `initDashboard()` scope, so `const`/`let` ordering is a live hazard and
> has caused three separate bugs.** `AVATARS` below the hero, `COLL_TO_ITEM` below its own caller, and
> `LIVE_KC` below `buildDroughts()` all threw or silently zeroed. The current safe order is: inference
> block → `COLLECTION` → `INFERENCE` → `AVATARS` → hero → `ICONS` → WOM block (`LIVE_KC`) → drought
> distribution → firsts → heatmap → luck → prices → initial renders. **If you move a block, run the
> page in Node against a stubbed `Chart`/`document` before shipping** — a silent zero looks fine in a
> screenshot.
- `ownerOf(e)` is the accessor everything should use; `isEstimated(e)` drives the `est.` tag in
  tooltips and the per-view note.

## Dashboard internals (in `index.html` / the source)

- Charts use **Chart.js 4.4.4** (UMD), inlined.
- `DATA` — array of `{date,item,kc,mode,who,iso}`, mirrors the raw log. `iso` present only on dated rows.
- `COLLECTION` — `[item, tomCount, willCount]` rows for the "Loot by Raider" section (exact totals).
  Also the basis of the attribution estimate, so it's declared near the top, not beside its table.
- The **who donut** has no "shared" slice any more; it splits each brother into *logged* (bright) and
  *estimated* (dim), so the uncertainty the shared slice used to carry is still visible.
- `ICONS` — map of **lowercase item name → data URI**; `iconFor(name)` / `nameCell(name)` render them.
- `AVATARS` — map of `"Tom"`/`"Will"` → data URI, with `RSN` for the in-game names and `avatarImg(who, cls)`
  to render one. Used in the hero crew row, the timeline's corner badge, and the tooltip. **It must stay
  declared above the hero-stats section** — the hero renders at load and would hit the TDZ otherwise.
- The **timeline tooltip is an external HTML one** (`tipHTML` / `showTip`), not Chart.js's built-in, because
  the built-in can't draw the item sprite or raider face. `dropAt[]` maps a label index back to its drop.
- `PRICES` — map of item display-name → GE price in gp (or `null` for untradeables). `PRICE_ASOF`
  holds the snapshot date. Prices are baked in, **not fetched live**.

### Both / Tom / Will selectors

The time-based cards (**Drops over time**, **Loot value**, **Drops per year**) each have a segmented
control (`.seg`, ids `seg-timeline` / `seg-value` / `seg-year`) in their top-right.

- `matchesPlayer(e, p)`: `both` → all; `tom`/`will` → `ownerOf(e)` matches. **The views are disjoint** —
  a drop counts for at most one brother (see [Estimated attribution](#estimated-attribution)).
- Each chart is a `buildX(player)` function that `destroy()`s and recreates its Chart instance.
  `wireSeg(el, cb)` handles button clicks + active state. Initial render + wiring happen at the end of
  `initDashboard()`.

To add another filterable chart: add a `.chart-head` with a `.seg` in the HTML, write a
`buildX(player)`, then `buildX('both')` + `wireSeg(document.getElementById('seg-x'), buildX)`.

## Live data (two public APIs)

Both are **free, keyless, and CORS-open** (`access-control-allow-origin: *`), and both are strictly an
**enhancement layer**: the page renders complete from baked data first, and a failed fetch adds
nothing. Never make either one load-bearing — `index.html` must still work opened from `file://`.

| API | Used for | Limit | Gotcha |
|-----|----------|-------|--------|
| [Wise Old Man](https://docs.wiseoldman.net/) `api.wiseoldman.net/v2/players/{name}` | live CoX + CM kill counts | 20 req/min | lookup names differ from display names — see below |
| [Wiki real-time prices](https://oldschool.runescape.wiki/w/RuneScape:Real-time_Prices) `prices.runescape.wiki/api/v1/osrs/latest` | refreshing `PRICES` | none stated, 60s cache | asks for a descriptive User-Agent, which browsers forbid pages from setting |

Things that will bite you:

- **Hiscores names are not the display names.** Tom's account is **`iWolfo`**, Will's is `wolfo jr`.
  `WOM_PLAYERS` holds the lookup keys; **`RSN` holds what the UI shows** (Wolfo / Wolfo JR). Never
  render a `WOM_PLAYERS` value — the user asked specifically that the UI keep saying "Wolfo".
- **WOM snapshots can be older than the log, or just plain old.** A player is only re-read when
  someone syncs them, so two independent problems arise, and `renderLiveKc()` handles both:
  its KC may be *behind* a purple already logged (378 CM against the log's 380 — a naive subtraction
  prints a **negative** dry streak, so this reports the snapshot as stale instead); or it may be ahead
  but months old (iWolfo's was 184 days stale), in which case the reading is labelled "as of \<date\>"
  rather than "now". Keep both branches.
- `kills: -1` means unranked, not zero. Filter it.
- **Price refresh is all-or-nothing.** A partial response would mix live and baked prices inside one
  total, so `refreshPrices()` only commits when every id resolves.
- Item ids in `PRICE_IDS` came from the API's own `/mapping` endpoint. Re-derive them there, don't guess.

## GE prices

Sourced from the wiki's **Ancient chest unique drop table**
(https://oldschool.runescape.wiki/w/Ancient_chest). Untradeable in this log: **Twisted ancestral
colour kit** ("Twisted Kit"), **Metamorphic dust**, **Olmlet** — they have `null` in `PRICES`, are
**left out of the value table**, and are only mentioned as a count in the section's note line.
When refreshing prices, update the `PRICES` map and `PRICE_ASOF` together.

## Logging a new drop

A drop lands in five places, so **never hand-edit them one by one** — use `/log-drop` (or call the
script directly):

```
./add-drop.sh --item tbow --kc 380 --mode CM --player Tom
./add-drop.sh --item arcane --kc 381 --mode CM --player both --collection Will --notes B2B
./add-drop.sh --help        # aliases + every flag
./add-drop.sh ... --dry-run # print the row and DATA entry, write nothing
```

It appends the fixed-width row to `cox-drop-log.txt`, appends the `DATA` entry in
`src/dashboard_src.html`, bumps that item's `COLLECTION` row, bumps the drop count and lifetime
Tom/Will totals in `README.md` + this file, and runs `./build.sh`.

Notes on its behaviour:

- Item names are normalised from aliases (`tbow`, `dex`, `dhcb`, `anc top`, …) to the exact display
  names `DATA` uses, and separately to the sentence-case names `COLLECTION` uses (`Twisted Kit` →
  `Twisted ancestral kit`, `Olmlet` → `Olmlet (pet)`). Unknown items are rejected, not guessed.
- `--collection` is the brother whose **collection log** gained the item, which is not the same
  question as `--player`. It defaults to `--player` for `Tom`/`Will`; a shared `Tom/Will` drop must
  state it explicitly (or `none`) so the exact lifetime totals never drift on a guess.
- It **warns** when the new kc isn't above the highest logged kc for that mode (usually a typo, since
  Regular and CM count separately) and **blocks** an exact duplicate row unless `--force`.

## Build

Edit `src/dashboard_src.html`, then regenerate `index.html`:

```
./build.sh          # or:  sh build.sh
```

`build.sh` needs only **POSIX sh + awk + cat** — present out of the box on macOS and Linux, and on
Windows via Git Bash (you already have it with git). No Node/Python/PowerShell required. It pulls the
`<style>` CSS and `<body>` out of the source, inlines `fonts_inline.css` (in place of the Google Fonts
`<link>`s) and `chart.umd.min.js` (in place of the Chart.js CDN `<script>`), wraps it in a standalone
`<!doctype>` document with a viewport meta and the Olmlet favicon, and writes `index.html`.

> **Encoding — why the build streams bytes.** `src/dashboard_src.html` is UTF-8 with em-dashes (`—`)
> and non-breaking spaces. `build.sh` never decodes/re-encodes text — `awk`/`cat` pass bytes straight
> through — so clean UTF-8 in stays clean UTF-8 out (no mojibake). The script itself is pure ASCII and
> emits the `<title>` em-dash as raw UTF-8 bytes via `printf '\342\200\224'`.
>
> An earlier `build.ps1` produced mojibake (`Â`, `â€"`) because Windows PowerShell 5.1's
> `Get-Content -Raw` decodes BOM-less files as the ANSI codepage. If you ever reintroduce a PowerShell
> build, read via `[System.IO.File]::ReadAllText(path, UTF8)` and keep the script ASCII-only.

**Only `index.html` is maintained.** A Claude-artifact flavour existed earlier (no
`<!doctype>/<html>/<head>/<body>` wrappers; emoji-only favicon) but the user has asked to stop
updating it — build and ship only `index.html`.

## Verifying locally

The Claude browser pane sandboxes `file://` pages with `script-src 'none'` **and** blocks external
CDNs and raw `localhost`. To render/verify JS:
1. Serve the folder over HTTP (e.g. a PowerShell `System.Net.HttpListener` on a port like 8091).
2. Add a `.claude/launch.json` **attach** config (a configuration with a `url` and no command) pointing
   at that origin, then `preview_start` by name and `navigate` to the file.
3. The **self-contained** `index.html` renders anywhere; the CDN-based source only works over HTTP
   (CDN blocked in the pane), so prefer testing the built `index.html`.

Use `javascript_tool` for DOM/Chart assertions (e.g. `Chart.instances`, computed styles) — screenshots
need the pane to be visible.

## Deploy

Commit to `main`; GitHub Pages (Deploy from branch → `main` / root) serves it. A `.nojekyll` file is
present to bypass Jekyll. Favicons cache hard in browsers — hard-refresh to see changes.

## Conventions

- No global git identity is assumed; this repo has `user.name`/`user.email` set locally.
- End commit messages with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
