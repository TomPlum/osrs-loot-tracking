---
description: Log a new CoX purple — appends to cox-drop-log.txt, updates the dashboard data, and rebuilds index.html
argument-hint: [item] [kc] [Regular|CM] [Tom|Will|both|Aaron] [date] [notes]
allowed-tools: Bash(./add-drop.sh:*), Bash(./build.sh), Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Read, AskUserQuestion
---

Log a new Chambers of Xeric purple.

Raw input from the user: **$ARGUMENTS**

`./add-drop.sh` does all the file surgery — do not hand-edit `cox-drop-log.txt`,
`src/dashboard_src.html`, or `index.html` yourself. Your job is to turn the user's shorthand into
correct flags, confirm it, run it, and report.

## 1. Work out the five facts

| Fact | Flag | Notes |
|---|---|---|
| Item | `--item` | Aliases are fine (`tbow`, `dex`, `arcane`, `buckler`, `kit`, `kodai`, `bulwark`, `claws`, `anc hat/top/bottom`, `dhcb`, `maul`, `dust`, `olmlet`). The script rejects anything it doesn't know. |
| KC | `--kc` | Kill count at the drop. **Regular and CM are independent counters** — a CM drop takes the CM kc. |
| Mode | `--mode` | `Regular` or `CM`. |
| Player | `--player` | `Tom`, `Will`, `Tom/Will` (a shared drop — one of the brothers, not pinnable), `Aaron IM`, or `none`. |
| Collection log | `--collection` | Which brother's collection log gained it: `Tom`, `Will`, or `none`. Defaults to `--player` when that's Tom or Will. |

Optional: `--date DD/MM/YYYY` (defaults to today) and `--notes` (e.g. `B2B`/`B3B` for a back-to-back).

Read the arguments generously — "tbow 380 cm tom" is a complete drop. Then:

- **Anything genuinely missing, ask for in one `AskUserQuestion` round**, not one question at a time.
- **A shared drop (`--player Tom/Will`) needs `--collection` explicitly.** Ask which brother actually
  banked it. The lifetime Tom/Will totals are reconciled from the real collection logs and must stay
  exact, so if the user doesn't know, pass `--collection none` and say the totals were left untouched.
- If the user names a *player* but the drop is a duplicate both brothers could have received, still
  take them at their word — `--player Tom` implies Tom's log.

## 2. Preview, then write

Run with `--dry-run` first and show the user the exact log row and DATA entry. If they gave every
detail unambiguously, go straight on to the real run; only stop for confirmation when you had to
guess something.

```
./add-drop.sh --item "<item>" --kc <n> --mode <Regular|CM> --player "<who>" [--collection <who>] [--date DD/MM/YYYY] [--notes "<text>"]
```

Then run it for real (same flags, no `--dry-run`). It appends the fixed-width log row, appends the
`DATA` entry, bumps the `COLLECTION` row and the lifetime totals in `README.md` + `CLAUDE.md`, and
runs `./build.sh` to regenerate `index.html`.

Heed its output:

- A **KC warning** ("not above the highest logged kc") usually means the kc or the mode is wrong —
  surface it to the user rather than burying it.
- A **duplicate row** error blocks the write. Only re-run with `--force` if the user confirms the
  same item really dropped twice at the same kc on the same day.
- If it exits non-zero, nothing downstream ran — fix the flags and re-run rather than patching files
  by hand.

## 3. Report

Tell the user, briefly:

- the row that was logged,
- the new total drop count, and whose lifetime total went up (or that none did),
- that `index.html` was rebuilt.

Then offer to commit and push — this repo deploys from `main` via GitHub Pages, so a push is the
deploy. Don't do it unless they say yes. Commit message: a short summary like
`Log <item> at <kc>kc <mode>`, ending with the repo's trailer:

```
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```
