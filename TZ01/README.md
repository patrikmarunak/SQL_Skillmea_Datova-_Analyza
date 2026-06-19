# TZ01 – Treasury Transaction Review (Power Apps canvas app)

A Mondelēz treasury‑controls canvas app for the **daily review of FX & MM listings**.
Middle Office (MO) reviews findings, optionally flags them to Front Office (FO); FO
answers; MO completes each check and submits the report. Late entries feed a monthly
**TOP report**.

This folder is **Deliverable A**: a packable canvas source tree that produces a valid
`.msapp` which imports into Power Apps Studio.

```
TZ01/
├─ TZ01.msapp        ← packed app (import this into Power Apps Studio)
├─ src/              ← canvas source (pac canvas unpack layout)
│  ├─ CanvasManifest.json
│  ├─ ControlTemplates.json
│  ├─ Src/App.fx.yaml          ← App.OnStart (seed data) + responsive App props
│  ├─ Src/scrOverview.fx.yaml
│  ├─ Src/scrChecks.fx.yaml
│  ├─ Src/scrCheckDetail.fx.yaml
│  ├─ Src/scrInbox.fx.yaml
│  ├─ Src/scrTop.fx.yaml
│  ├─ Src/EditorState/*.editorstate.json
│  ├─ pkgs/*.xml               ← control templates used by the app
│  └─ Entropy/, Connections/, …
├─ README.md
└─ CHANGES.md         ← deviations from the prototype / schema
```

## Build / round‑trip

Requires the Power Platform CLI (`pac`, the `Microsoft.PowerApps.CLI.Tool` dotnet tool).

```bash
# pack source -> msapp
pac canvas pack   --sources ./src --msapp ./TZ01.msapp

# unpack msapp -> source (round-trips byte-stable)
pac canvas unpack --msapp ./TZ01.msapp --sources ./src
```

The source round‑trips losslessly: `pack → unpack → pack` reproduces an identical
source tree.

## Screens

| Screen | Purpose |
| --- | --- |
| `scrOverview` | MO/FO role switch, day list, stepper, review log, FX/MM reports table, footer TOP‑report buttons |
| `scrChecks` | Check‑results overview for the selected report; **Submit report** (enabled only when every check is Completed) |
| `scrCheckDetail` | Per‑finding row: READ columns + MO reason (data‑driven dropdown) + MO comment + FO flag + FO reason + FO comment; **Send flagged to FO** / **Mark check complete** |
| `scrInbox` | FO view – cards of findings flagged to FO; FO reason + comment + **Send response to MO** |
| `scrTop` | Monthly TOP report – late entries with Days late |

## Layout & responsiveness

* `DocumentLayoutScaleToFit = false`, `SizeBreakpoints = [600, 900, 1200]` – the app is
  **responsive**, not scaled.
* Every screen is built from **vertical / horizontal auto‑layout containers**
  (`groupContainer.verticalAutoLayoutContainer` / `…horizontalAutoLayoutContainer`).
* Sizing follows the brief:
  * **Fixed width** where it has meaning – left day list (`250`), header role switch
    (`240`), logo placeholder (`110`), action buttons, table cells with fixed columns.
  * **Fill / fit** elsewhere – `FillPortions: 1` on the title, the main content column,
    comment inputs and the transaction read‑cell so they grow with the window; child
    cross‑axis sizing via `AlignInContainer.Stretch`.
* Brand colours: header purple `#43164F`, blue accents `#1F60A8`, orange back `#BF5320`,
  green `#3B6D11`, amber `#854F0B`, red `#A32D2D`.
* **No logo** – a dashed `[ logo ]` placeholder sits where the brand logo will go.

## Key Power Fx

All edits are written to the local `colTransactions` collection with `_isDirty = true`
(only dirty rows are committed). The main formulas:

* **Patch on edit** (MO reason / comment, FO flag / reason / comment) –
  `Patch(colTransactions, ThisItem, {MOReason: Self.Selected.Value, _isDirty:true, _state:"modified"})`
* **Send flagged to FO** –
  `ForAll(Filter(colTransactions, …, FlaggedToFO, !FOResponded) As T, Patch(colTransactions, T, {Status:"Awaiting FO review", _isDirty:true})); Patch(colChecks, varCurrentCheck, {Status:"Awaiting FO review"}); Notify(…)`
* **Mark check complete** – `DisplayMode` gated by
  `With({tx: Filter(colTransactions, DailyReportCheckID=varCurrentCheck.ID)}, If(CountRows(tx)>0 && CountRows(Filter(tx, FlaggedToFO && !FOResponded))=0 && CountRows(Filter(tx, IsBlank(MOReason)))=0, DisplayMode.Edit, DisplayMode.Disabled))`
* **Submit report** – `DisplayMode` enabled only when every check is Completed, then
  `Patch(colDailyReports, varCurrentReport, {Submitted:true, Status:"Review completed"}); Notify("Report submitted", NotificationType.Success)`
* **FO respond** – `Patch(colTransactions, ThisItem, {FOResponded:true, Status:"FO replied", _isDirty:true}); Notify(…)`
* **Notifications** – `Notify(…, NotificationType.Success / .Information)` on send‑to‑FO,
  complete, submit, FO reply, and the Power BI export buttons.
* **DisplayMode / Visible** – FO reason & comment are `Disabled` until the row is flagged;
  *Send flagged to FO* is `Visible` only when a flagged‑and‑unanswered row exists; the
  empty “check passed” state is `Visible` when a check has no findings.
* **Data‑driven dropdowns** – MO list `Filter(colReasonConfig, ReportType=…, CheckNumber=…, AppliesTo<>"FO")`,
  FO list `Filter(colReasonConfig, AppliesTo="FO")`.

## Dev vs. production data

`App.OnStart` seeds the six collections with the prototype data so the app **runs
offline**. The bottom of `App.fx.yaml` keeps the commented production block. To bind to
SharePoint, add the lists as data sources and swap the seed `ClearCollect`s for:

```powerfx
ClearCollect(colDailyItems,   'TZ01 Daily Item');
ClearCollect(colDailyReports, 'TZ01 Daily Reports');
ClearCollect(colChecks,       'TZ01 Daily Report Checks');
ClearCollect(colReasonConfig, 'TZ01 Reason Config');
ClearCollect(colTopReport,    'TZ01 Top Report');
// transactions: load only the selected day (delegable on DayKey)
ClearCollect(colTransactions,
    AddColumns(Filter('TZ01 Daily Transactions', DayKey = varDayKey), "_state","loaded","_isDirty",false));
```

and replace the *Save draft* button body in `scrCheckDetail` with the dirty‑row commit:

```powerfx
ForAll(Filter(colTransactions, _isDirty) As T,
    Patch('TZ01 Daily Transactions', LookUp('TZ01 Daily Transactions', ID=T.ID),
        {MOReason:T.MOReason, MOComment:T.MOComment, FlaggedToFO:T.FlaggedToFO,
         FOReason:T.FOReason, FOComment:T.FOComment, FOResponded:T.FOResponded, Status:T.Status}));
UpdateIf(colTransactions, _isDirty, {_isDirty:false, _state:"loaded"});
```

Navigation and gallery filters use the **Number foreign keys** (`DailyItemID`,
`DailyReportID`, `DailyReportCheckID`), never Lookup columns.

Power Automate flows (notify FO, copy attachments, monthly TOP snapshot) and the Office
Scripts that run the 10 checks are **out of scope** – the app only reads/edits the lists.
