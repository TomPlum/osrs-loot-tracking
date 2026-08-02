# OSRS Loot Tracking — The Wolfo Bros Ledger

A drop log and interactive dashboard for **Chambers of Xeric** (Great Olm) purples, tracked by
the **Wolfo Bros** — **Wolfo** (Tom) & **Wolfo JR** (Will) — with the occasional guest raid from Aaron.

94 uniques logged since August 2020, spanning the old standard-Chambers grind and the Challenge Mode era.

## Live dashboard

The dashboard is a single self-contained `index.html` (fonts, charts, and item icons all inlined — no
external requests, works offline).

- **Open locally:** double-click [`index.html`](index.html), or serve the folder and visit it.
- **GitHub Pages:** enable Pages for this repo (Settings → Pages → Deploy from branch → `main` / root)
  and it will be served at `https://tomplum.github.io/osrs-loot-tracking/`.

It renders:

- **Kill-count progress** — Regular Chambers and Challenge Mode run on separate KC counters.
- **Drops over time** — cumulative purples, split by raid mode.
- **Drought watch** — the longest dry streaks, measured in KC.
- **Loot table breakdown** — every unique, ranked by how often it dropped, with in-game icons.
- **Loot by raider** — the Tom vs Will split, reconciled from collection logs.
- **Drops per year** and a **recent feed** of the last 12 drops.

## Repository contents

| Path | What it is |
|------|------------|
| [`cox-drop-log.txt`](cox-drop-log.txt) | The raw drop log — a plain-text table, one row per purple. |
| [`index.html`](index.html) | The self-contained interactive dashboard. |
| [`assets/icons/`](assets/icons) | Item sprites (webp) used in the dashboard. |

## The data

`cox-drop-log.txt` is a fixed-width table with these columns:

```
Date        Item                      KC  Mode     Player    Notes
```

- **Date** — `DD/MM/YYYY`. Six early drops are undated (`??/??/2020`).
- **KC** — the kill count at the drop. Regular and CM are **independent counters** (CM started at 1kc on 16/01/2022).
- **Mode** — `Regular` (standard Chambers) or `CM` (Challenge Mode).
- **Player** — who received it (see attribution below).
- **Notes** — e.g. `B2B` / `B3B` back-to-back streaks.

### How attribution works

Tom and Will raid together, so on shared drops the log can't always say *which* brother got a given
duplicate. The `Player` column resolves each row as far as the collection logs allow:

- **Tom / Will** — confirmed (a unique item, or forced by the collection-log counts).
- **Tom/Will** — a shared duplicate: definitely one of the brothers, but not attributable to a specific row.
- **Aaron IM** — Aaron's (ironman, guest raids).
- **blank** — can't be pinned even to a brother.

Per-item **totals** are exact even where individual rows aren't. Reconciled from the brothers' collection logs:

| | Tom | Will |
|---|----:|----:|
| **Lifetime CoX uniques** | 55 | 48 |

Some collection-log counts (prayer scrolls, bucklers, kits, DH crossbow) exceed what's in this log —
those are lifetime totals and include raids that were never written down here.

### Data clean-up notes

- Four 2020 dates were logged in US `MM/DD` format and were normalised to `DD/MM`.
- Two dates whose originals were forgotten were inferred from KC order: Ancestral top @455kc → `05/03/2022`;
  Twisted kit @182kc → `17/07/2022`.
- The `13/09/2020` Ancestral Hat shows 253kc (lower than the 255kc before it) — likely a KC typo, not a date.

---

*Built with far too many purples and not enough tbows.*
