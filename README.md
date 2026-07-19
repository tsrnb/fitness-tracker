# CutTracker v2.1

A private, offline fitness tracker with built-in coaching for a fat-loss / muscle-retention phase.

## What's new in this update
- **73-exercise library**, 5 more per body-part section (Chest/Back/Shoulders/Legs/Arms/Core), mixing
  machine and free-weight/bodyweight variations.
- **Diet calorie counter now includes today's activity burn** — your "kcal left" allowance grows with
  logged cardio, same on Home and Diet screens.
- **Today's deficit/surplus stat** on the Diet screen, computed against your coach-estimated maintenance
  (TDEE), net of activity burned.
- **Quick log a meal** — type or paste one item per line as `name, kcal, protein` and it parses, totals,
  and logs the whole meal at once. See "format?" in the Diet screen for the exact syntax.
- **Progress → Photos removed** per request (Weight / Strength / Activity remain).
- **Train screen simplified** — one Save/Update action per exercise instead of two overlapping controls;
  tapping the row expands/collapses, a "Logged" badge shows once you've saved today's sets.
- **Safe-area support** — fixed the top status bar and bottom nav getting clipped when installed as a
  home-screen app (this only shows up in standalone/PWA mode, not in a normal browser tab).
- Diet custom-item entry box fixed (kcal/protein fields were misaligned).

## Diet quick-log format
```
2 Rotis, 240, 6
Dal tadka, 180, 12
Paneer bhurji, 220, 14
```
One item per line: `name, kcal, protein`. Protein is optional — `name, kcal` also works.
It shows a running preview with totals before you tap **Log meal**.

## Run locally
```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # outputs to dist/
```

## Put it on your iPhone
Easiest: use the single-file `CutTracker.html` (no build needed) — drop it on https://app.netlify.com/drop,
open the URL in Safari, then Share → **Add to Home Screen**.

Or deploy this project: `npm run build`, then drag the `dist/` folder onto Netlify Drop and Add to Home Screen.

## Notes
- Storage is **on-device only** — nothing leaves your phone, no account, no sync, no AI calls.
- If SQLite/WASM can't load it falls back to localStorage automatically, so it never bricks.
- Program avoids conventional deadlifts, RDLs, walking lunges and single-arm DB rows by design.
