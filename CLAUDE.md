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
| `index.html` | **Generated — do not hand-edit.** Self-contained (fonts, Chart.js, item icons all inlined as base64 `data:` URIs), ~400 KB. |
| `cox-drop-log.txt` | Raw data: a single fixed-width text table, one row per purple. Source of truth for the drops. |
| `assets/icons/*.webp` | Item sprites (also inlined into `src` as `ICONS`; this folder is the original source). |
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

Per-item **totals** are exact (reconciled from both collection logs: lifetime **Tom 55 / Will 48**),
even though individual shared rows aren't. In the dashboard JS the raw values are `"Tom"`, `"Will"`,
`"Tom/Will"`, `"Aaron IM"`, or `null`.

## Dashboard internals (in `index.html` / the source)

- Charts use **Chart.js 4.4.4** (UMD), inlined.
- `DATA` — array of `{date,item,kc,mode,who,iso}`, mirrors the raw log. `iso` present only on dated rows.
- `COLLECTION` — `[item, tomCount, willCount]` rows for the "Loot by Raider" section (exact totals).
- `ICONS` — map of **lowercase item name → data URI**; `iconFor(name)` / `nameCell(name)` render them.
- `PRICES` — map of item display-name → GE price in gp (or `null` for untradeables). `PRICE_ASOF`
  holds the snapshot date. Prices are baked in, **not fetched live**.

### Both / Tom / Will selectors

The time-based cards (**Drops over time**, **Loot value**, **Drops per year**) each have a segmented
control (`.seg`, ids `seg-timeline` / `seg-value` / `seg-year`) in their top-right.

- `matchesPlayer(e, p)`: `both` → all; `tom` → `who` is `Tom` **or** `Tom/Will`; `will` → `Will` **or**
  `Tom/Will`. **Shared drops appear in both individual views**, so Tom's and Will's totals overlap.
- Each chart is a `buildX(player)` function that `destroy()`s and recreates its Chart instance.
  `wireSeg(el, cb)` handles button clicks + active state. Initial render + wiring happen at the end of
  `initDashboard()`.

To add another filterable chart: add a `.chart-head` with a `.seg` in the HTML, write a
`buildX(player)`, then `buildX('both')` + `wireSeg(document.getElementById('seg-x'), buildX)`.

## GE prices

Sourced from the wiki's **Ancient chest unique drop table**
(https://oldschool.runescape.wiki/w/Ancient_chest). Untradeable in this log: **Twisted ancestral
colour kit** ("Twisted Kit"), **Metamorphic dust**, **Olmlet** — they have `null` in `PRICES`, are
**left out of the value table**, and are only mentioned as a count in the section's note line.
When refreshing prices, update the `PRICES` map and `PRICE_ASOF` together.

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
