# CLAUDE.md — OSRS Loot Tracking

Guidance for Claude working in this repo. Read this before editing the dashboard.

## What this is

A drop log + single-page dashboard for **Chambers of Xeric** (Great Olm) purples, tracked by the
**Wolfo Bros** — **Wolfo** (Tom) & **Wolfo JR** (Will), with occasional guest raids from **Aaron**
(ironman). Live at https://tomplum.github.io/osrs-loot-tracking/ (GitHub Pages, `main` / root).

## Files

| Path | Role |
|------|------|
| `index.html` | The dashboard. **Self-contained and generated** — fonts, Chart.js, and item icons are all inlined as base64 `data:` URIs. ~400 KB. Do not hand-edit the inlined blobs. |
| `cox-drop-log.txt` | Raw data: a single fixed-width text table, one row per purple. This is the source of truth for the drops. |
| `assets/icons/*.webp` | Item sprites (also inlined into `index.html`; the folder is the original source). |
| `README.md` | Human-facing project overview. |

> The **editable dashboard source** is a CDN-based HTML file (`dashboard_src.html`) that was kept in
> a scratchpad during development, **not committed**. `index.html` is built from it by inlining assets
> (see Build). If you need to make structural changes and the source isn't available, reconstruct it
> from `index.html` or ask the user for it — then commit it so future edits are reproducible.

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
colour kit** ("Twisted Kit"), **Metamorphic dust**, **Olmlet** — no GE value, counted separately.
When refreshing prices, update the `PRICES` map and `PRICE_ASOF` together.

## Build

`index.html` is produced from the CDN-based source by inlining:
1. Replace the Google Fonts `<link>`s with an inlined `@font-face` block (`fonts_inline.css`, latin
   woff2 subsets as data URIs).
2. Replace the Chart.js `<script src=…cdn…>` with the library inlined in a `<script>` tag.
3. Item icons are already inlined in `ICONS`.

Two output flavours share the same body/CSS/JS:
- **`index.html`** — a full standalone document (`<!doctype>`…`<head>` with viewport + Olmlet favicon
  data-URI…`<body>`). This is what GitHub Pages serves.
- A **Claude artifact** flavour (no `<!doctype>/<html>/<head>/<body>` wrappers — the harness adds them;
  favicon is emoji-only). **The user has asked to stop maintaining the Claude artifact — only keep
  `index.html` current.**

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
