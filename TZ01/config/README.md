# TZ01 — app build config

`TZ01_app_config.yaml` is the **single source of truth** from which the generator
emits the canvas app source (`App.OnStart` + all six screens) that `pac canvas pack`
turns into `TZ01.msapp`. Everything configurable lives in the config — the generator
must not invent behaviour that is not stated there.

## What the config covers

| Section | Drives |
|---|---|
| `build` | emit target (classic/modern), pac pins, Studio feature flags, classic→modern control mapping |
| `theme` | `varTheme` record (first OnStart statement); no baked-in RGBA anywhere |
| `roles` | identity resolution order (deeplink param → Reviewers list → default), capability matrix, `DisplayMode` gating |
| `deeplinks` | `Param()` reads, `App.StartScreen` switch, email-link formats for the notify flows |
| `data` | SharePoint list bindings + rename maps, **test/production switch**, derived-status formulas (status is never stored) |
| `patches` | MO/FO field ownership (no shared column → concurrent saves are safe), canonical `Patch` templates per action, `IfError` wrapper, flow contracts |
| `popups` | all five confirm dialogs incl. the review-all anti-spam warnings on both batched sends |
| `attachments` | evidence at check/report/day level via native SP attachments (hidden Edit-form + Attachments control pattern), VITUS rule, Input Files library |
| `audit` / `notifications` | live audit feed events + which Power Automate flow reacts to which flag |
| `quickViewColumns` | per-check visible columns (proposal ch. 8.3) → seeds `TZ01 Check Columns` |
| `reasons` | **production** MO/FO dropdown seeds (proposal ch. 14.7), AutoFlagFO + RequiresComment semantics, auto-reasons (FX4 hedge rate, MM4 credit line), auto-clear (FX2 EXPOSURE), Not compared (FX3) |
| `screens` | per-screen part list (behavioural spec = prototype v4) |
| `testData` | deterministic seed (days, reviewers, 11 findings with full source records via defaults+overrides, audit seed) used when `data.mode: test` |

## Test vs production

`data.mode: test` emits the `testData` seed into `App.OnStart`; `production` emits
`ClearCollect`s from the SharePoint lists (with the rename maps) plus the loading
overlay. **Screen formulas are identical in both modes** — they only ever read the
collections — so flipping the mode is a rebuild, not a rewrite.

## Build targets — the modern-controls caveat (read before switching)

- **classic** (today's pipeline): `.fx.yaml`, source format **0.24**, `pac 1.43.6`,
  classic controls. Proven: packs clean, imports into the MDLZ QA env, CI checker wired.
- **modern** (`build.target: modern`): Fluent v9 controls (Text, Button, Dropdown,
  ComboBox, CheckBox, Badge, Spinner, DatePicker…) mapped per `build.controlMapping`.
  Modern controls **cannot** be represented in the 0.24/pac 1.43.6 format — the modern
  emit requires the modern source format (`.pa.yaml`, pac ≥ 2.x) and:
  1. bumping the pinned pac version in `.github/workflows/powerapps-checker.yml`,
  2. enabling *Modern controls and themes* in the app settings (`PaModernControls`),
  3. re-validating import in Studio (modern templates evolve; some have preview gaps —
     no modern **gallery** or **icon** control exists, so galleries/icons/containers stay classic).
  The config keeps `fallbackTarget: classic` so the proven emit path never breaks.

## Pipeline

```
TZ01_app_config.yaml ──> generator (config-driven rewrite of gen_base/fix_onstart/gen_all)
                          ├─ target classic ──> TZ01/src (.fx.yaml, 0.24) ──> pac 1.43.6 pack ──> TZ01.msapp
                          └─ target modern  ──> src-modern (.pa.yaml, 0.30+) ──> pac 2.x pack ──> TZ01.msapp
                                                        └──> CI: solution pack + checker (per target pin)
```

The generator consuming this config is the next step — the current generators
(`gen_base.py` / `fix_onstart.py` / `gen_all.py`) hard-code what this file now declares.
