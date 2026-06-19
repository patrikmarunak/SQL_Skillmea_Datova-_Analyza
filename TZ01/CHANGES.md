# TZ01 – deviations from the prototype / schema

Rule followed: **the schema (`TZ01_sharepoint_schema.docx`) and `App.OnStart` are the
data/logic contract; the prototype is the visual/behavioural contract.** Where the
prototype and the schema disagree, the schema wins (and it is flagged below).

## Data / logic
* `App.OnStart` is taken **verbatim** from `TZ01_App_OnStart.txt` (seed collections +
  the commented production swap). Blank lines inside the formula were removed because the
  `pac` `.fx.yaml` lexer ends a multi‑line block at a fully‑blank line – this is cosmetic
  only and does not change behaviour.
* All gallery `Items`, status roll‑ups, *Send to FO*, *Mark complete*, *Submit* and
  reason‑dropdown filters use the formulas given in the OnStart file.
* The reports row’s finding count is computed from `colChecks`
  (`Sum(Filter(colChecks, DailyReportID=ThisItem.ID), FlaggedCount)`) instead of a
  `Daily Reports.Findings` column, because that column is optional in the schema and is
  **not present in the seed** – avoids referencing a non‑existent field.

## Visual
* The HTML `<table>`s are rendered as Power Apps **galleries**. The grouped
  `READ / MO / FO` column band from the prototype is represented per row (one read
  summary cell + the MO and FO editors) rather than as a literal three‑section header.
* Amount formatting uses `Text(x, "#,##0")` (e.g. `1,000,000`) rather than the
  space‑grouped `1 000 000` of the HTML mock.
* **Logo** is intentionally **not** included – a dashed `[ logo ]` placeholder is shown
  in the header instead (per request).

## Known open points carried over from the prototype (not invented here)
* **MM Check 2** – the *US Bank Dealer Performance Report* is not yet a defined input;
  the row shows the finding but the comparison source/format is still to be defined.
* **FO reasons** – modelled as the shared `AppliesTo = "FO"` subset of `colReasonConfig`
  (the prototype noted this as an open question: own list vs. shared with MO).
* Auto reasons (`Hedge rate`, `Credit line`) come pre‑filled from the seed; the dropdowns
  remain editable.

## Out of scope (built separately)
* Power Automate flows: notify FO, copy attachments, monthly TOP snapshot.
* Office Scripts that run the 10 daily checks.
The app assumes the flows populate the lists; it only reads / edits them. The *Save draft*
button commits locally in dev; the production SharePoint `Patch` pattern is documented in
`README.md`.
