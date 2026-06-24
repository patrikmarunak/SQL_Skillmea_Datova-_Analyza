# TZ01 — change log

## v3.1 delta (feature D — transaction detail in checks)

In each check, MO **and** FO now see the transaction record: the **relevant columns
per check** (driven by a config list), with a **Show all columns** toggle that reveals
the full SAP source record with horizontal scroll. Only the check-detail screen, the
FO inbox, the MO queue and `App.OnStart` were touched — everything else is unchanged.

**Data layer (`App.OnStart`)**
- `colAllColsForListing` — the full source schema (FX 34 + MM 19 = 53 rows) `{Listing, ColName, Align, Order}`; drives *Show all* and the headers.
- `colCheckColumns` — per-check visible-column config (53 rows) `{Report, CheckNo, ColName, Order, Align}`; seeded from the v3.1 delta. **Production:** swap for `ClearCollect(colCheckColumns, RenameColumns('TZ01 Check Columns', "Check Number","CheckNo", "Column Name","ColName"))` (offline uses space-free field names for convenience).
- Source columns added to every seeded transaction (FX records get the FX columns, MM the MM columns; shared columns once) with the meaningful per-finding values for demo parity.
- `colTxnCells` — flatten: one row per (transaction × column-in-its-listing), value projected by a `Switch` over the 45-column union. Lets a gallery render columns chosen at runtime (Power Fx can't read a field by a variable name).

**Check detail (`scrCheckDetail`)** — the flat transaction row became a **nested gallery**:
outer `galTxn` (one row per finding) → inner **horizontal** `galCells` in a width-bounded,
horizontally-scrolling area, plus a horizontal header gallery `galHdr` aligned above it.
The fixed MO/FO edit controls (reason, comment, FO flag, state, FO reason/comment, resend)
sit after the cells and **do not scroll**. `OnVisible` seeds `varVisibleCols` (relevant
subset); the **Show all columns** button flips `varShowAll` and re-projects `varVisibleCols`
to the full listing; an "N of M cols" hint updates.

**FO inbox + MO queue** — each finding card now embeds the **same read-only cell table**
(`fo_rectable`: header + horizontal cells), with per-card visible columns computed inline
from the finding's `ReportType`/`CheckNumber` and the shared `varShowAll` toggle.

**Provisioning** — `provisioning/TZ01_provision_v3_1_delta.ps1` adds the source columns to
`TZ01 Daily Transactions` and creates + seeds `TZ01 Check Columns`.

**Decisions / assumptions (flagged, not guessed silently)**
- **Active Status casing:** FX `Active Status` / MM `Active status` unified to a single `Active Status` (per the schema delta).
- **Column width:** cells/headers use a fixed 140px width with horizontal scroll. Header and cells align at rest; because each is its own gallery, scrolling one does not scroll the other (minor; functional parity with the prototype's single-scroll table is the only gap).
- **Offline seed:** the demo seeds `colCheckColumns`/`colAllColsForListing` and the source-column values in `OnStart`; the commented production block must `ClearCollect` them from SharePoint instead.
- **Dependency (outside the app):** import / Office Scripts must populate all source columns on each row, or *Show all columns* shows blank cells — the app is ready for the data.

**Verified:** `pac canvas pack` is clean and the source round-trips losslessly (276 controls,
+23). **Not verifiable here (needs Power Apps Studio):** import-without-repair and the visual
render of the nested galleries / horizontal scroll.



## UX pass 2 (backlog B, C, E, F, G — no dark mode)

**B — filtering / search / sort.** Search boxes on Check Analysis (by name), check detail
(transaction no), FO inbox, My Queue (transaction/reviewer) and the TOP report
(transaction/reason); a **status** filter on Check Analysis (derived status), a **FO-state**
filter (Unflagged/Queued/Sent/Replied) on the check detail, and a **sort** dropdown
(Days late / Amount / Date) on the TOP report. (Local collections, so the `… in …` search
predicates don't hit delegation.)

**C — responsive rows.** The day-list, reports and checks rows were converted from absolute
`X/Y` positioning to **horizontal/vertical auto-layout containers** (`dayCardC` / `repRowC` /
`ckRowC`) with `FillPortions`, matching the transaction/TOP/queue rows — so columns reflow on
narrow widths.

**E — context & unsaved.** Breadcrumb on Check Analysis (`Day › Report`) and the check detail
(`Day › Report › Check`); an **unsaved-edits** indicator (`● N unsaved`) on the check-detail
and Check Analysis footers, driven by `CountRows(Filter(colTransactions, _isDirty))`.

**F — runtime states + live audit log.** An **offline banner** (`!Connection.Connected`) and a
**loading overlay** (`varLoading`, wired for the production SharePoint load) on the overview.
The static review log is now a **live audit feed** (`colAudit`): seeded with the validation
entries and appended on send-to-FO, FO reply, submit, complete and resend
(`Set(varAuditSeq,…); Collect(colAudit,{Seq,Stamp,Text})`), shown newest-first in the overview.

**G — theme record.** The brand palette now lives in a single runtime record **`varTheme`**
(set first in `App.OnStart`); every control reads `varTheme.Purple/Blue/…` instead of a baked-in
`RGBA`. Dark mode intentionally out of scope.

Deferred: **D** (FO read context — amount/rates/variance) until the per-check analysis columns
are defined. 246 controls; packs clean and round-trips.

## UX pass (quick wins 1–5)

Role-perspective UX hardening; all status logic and the data model are unchanged.

1. **Identity & role from the Reviewers matrix** — `App.OnStart` reads `User()` and looks the
   signer up in a new `colReviewers` collection; `varRole` derives from it (deeplink `Role=FO`
   still wins). Every header shows **"Signed in as … · {role}"**; the MO/FO toggle is shown only
   when identity doesn't resolve a role (demo/unknown user). MO inputs in the check detail are
   now `DisplayMode`-gated to the **MO** role (field-level security, not just convention).
2. **Column headers** — a sticky **READ / MO / FO** header row above the transaction gallery,
   aligned to the row widths (colour-tinted per band).
3. **Confirmations + error handling** — `Submit report`, `Mark check complete`, and queue
   **Resend / Complete** now open a confirmation modal (scrim + card); the action runs inside
   `IfError(...)` with a failure toast. Flag/unflag is also `IfError`-wrapped. (Power Apps has no
   native modal `Confirm()`, so this is the standard overlay pattern; "undo" = explicit confirm.)
4. **Disabled-state tooltips** — `Submit` shows how many checks still block it; `Mark complete`
   explains what must be resolved first.
5. **Accessibility** — 9–10 px fonts bumped to 12; `AccessibleLabel` added to the icon-only
   chevrons.

Touched: `App.fx.yaml`, the shared header (so every screen's header gains identity),
`scrOverview/scrChecks/scrCheckDetail/scrInbox/scrMoQueue`. 215 controls; packs clean and
round-trips. Remaining backlog (filtering/search, fully container-based rows, FO read context,
breadcrumb/unsaved indicator, contrast/focus order, theming) is unaddressed by design.

## Round 3 (delta applied to the existing app — not rebuilt)

Source of truth: refreshed `TZ01_prototype.html`; spec: `TZ01_codex_update_prompt_2.md`
+ `TZ01_App_OnStart_v2.txt` + `TZ01_schema_v2_delta.md`. Touched only the affected files
(`App.fx.yaml` incl. `App.StartScreen`, `scrOverview`, `scrChecks`, `scrCheckDetail`,
`scrInbox`, `scrMoQueue`).

### Step 0 — schema
* `provisioning/TZ01_provision_v3_delta.ps1` adds **`FORespondedOn`** (Date/time, FO‑owned)
  to `TZ01 Daily Transactions` and **`NotCompared`** (Yes/No) to `TZ01 Daily Report Checks`,
  and adds **"Not compared"** to the `Result` choices. `FOComment` is **append‑only**.
* Seed: `colTransactions` gains `FORespondedOn:Blank()`, `colChecks` gains `NotCompared`.

### Change 1 — derived status + field‑scoped patches (concurrency‑safe)
* Status is **derived, never stored by the app**. Inlined the OnStart‑v2 logic on the
  controls: `FOAnswered = FOSent && FORespondedOn ≥ FOSentOn`, and from it the check
  **Result**, check **status**, **CanComplete**, and report status (In review / Completed).
* **Field ownership is split** so MO and FO never write the same column:
  MO writes `MOReason, MOComment, FlaggedToFO, FOReviewer, FOSent, FOSentOn` (+ check
  `Completed`, report `Submitted`); FO writes `FOReason, FOComment (append), FORespondedOn`.
  The app no longer writes any shared `Status`/`FOResponded` column.

### Change 2 — FO reply append + resend
* FO reply **appends** a timestamped line to `FOComment` (`[dd Mmm hh:mm - reason] text`),
  sets `FORespondedOn = Now()` and the latest `FOReason`; prior replies stay. The FO inbox
  shows the reply history, a fresh comment box, and an **"MO asked again"** badge when reopened.
* **Resend** (Check Analysis row state + MO My Queue, both groups): MO bumps `FOSentOn = Now()`
  only — `FOAnswered` derives false and the row reopens for FO with `FOComment` intact.
  One grouped notification per `FOReviewer` is the flow's job.

### Change 3 — Not compared
* `CheckResult` returns **"Not compared"** (precedence) when `NotCompared` is true. FX Check 3
  (DTCC) is seeded Not‑compared with zero findings, so it **auto‑completes**, and both the
  check table and the check‑detail empty state clearly say *Not compared* for audit.

### Change 4 — deeplinks + default selection
* `App.OnStart` reads `DayKey / Report / Check / Screen / Role` params and sets
  **`varSelectedItem` once** (deeplink `LookUp` else `First(SortByColumns(colDailyItems,…))`).
* **`App.StartScreen`** `Switch`es on `Screen` (detail/checks/moqueue/inbox/overview) and opens
  the FO view when `Role=FO`.
* Overview gallery: `Default = varSelectedItem`, row highlight on `ThisItem.ID = varSelectedItem.ID`,
  row `OnSelect` updates `varSelectedItem`. **`scrOverview.OnVisible` was removed** so the
  deeplinked item stays selected on return to the overview (normal open → first item).

### Notes
* UDFs from the OnStart‑v2 file are **inlined** on controls (the file explicitly allows this
  where UDF support is unavailable) — keeps the legacy pack format importing cleanly.
* My Queue is conceptually cross‑day; offline it runs over the seeded day's `colTransactions`
  (production loads per `DayKey`).

---

## v2 (delta applied to the existing app — not rebuilt)

Source of truth: the updated `TZ01_prototype.html`; implementation spec:
`TZ01_codex_update_prompt.md`. Only the screens/files that changed were touched
(`App.fx.yaml`, `scrOverview`, `scrChecks`, `scrCheckDetail`, `scrInbox`, and the new
`scrMoQueue`); `scrTop` is unchanged.

### Step 0 — data model
* Three columns added to **`TZ01 Daily Transactions`** via
  `provisioning/TZ01_provision_v2_delta.ps1`: **`FOSent`** (Yes/No),
  **`FOSentOn`** (Date/time), **`FOReviewer`** (Text email / Person).
* `colTransactions` seed in `App.OnStart` extended with
  `FOSent:false, FOSentOn:Blank(), FOReviewer:""` on every finding, and the prototype's
  v2 routing pre-seeded: row 103 (FX3 DTCC) sent + FO-replied (`ana.kovac`), row 109
  (MM2) sent + awaiting (`peter.cerny`), rows 105/107 flagged-not-sent
  (`ivan.horvat` / `ana.kovac`). Flagged-but-not-sent rows carry `Status:"Awaiting MO review"`.

### Change 1 — report status = In review / Completed
* `scrChecks` stepper reduced to **2 nodes** (*In review* → *Completed*).
* The overview report row shows `If(ThisItem.Submitted, "Completed", "In review")`.
* *Submit report* now patches `Status:"Completed"` (was "Review completed"); submit
  enablement (every check Completed) and the per-check status column are unchanged.

### Change 2 — auto-flag on "Request FO explanation"
* `scrCheckDetail` MO-reason dropdown `OnChange` auto-checks **FO?** and sets
  `FOReviewer` (via `Coalesce(ThisItem.FOReviewer, If(ReportType="MM","fo.mm@mdlz.com","fo.fx@mdlz.com"))`)
  when the reason is *Request FO explanation* and the row isn't already flagged. Other
  reasons never auto-uncheck. Manual FO? check also defaults the reviewer.

### Change 3 — batched send on Check Analysis (per reviewer)
* The per-check **Send flagged to FO** button was **removed** from `scrCheckDetail`.
* `scrChecks` gained **Send flagged to FO (N)** where
  `N = CountRows(Filter(colTransactions, DailyReportID=varCurrentReport.ID, FlaggedToFO, !FOSent, !FOResponded))`.
  `OnSelect` sets `FOSent:true, FOSentOn:Now(), Status:"Awaiting FO review"` on the batch
  and notifies *"Sent X findings to Y FO reviewer(s)"* (`CountRows(Distinct(toSend, FOReviewer))`).
  Per-reviewer grouping into one email is the **flow's** job — the app only sets the flags
  and ensures `FOReviewer` is populated.
* **Check status is now live** in the checks gallery: *Awaiting FO review* only when a
  finding is `FlaggedToFO && FOSent && !FOResponded`; flagged-but-not-sent stays
  *Awaiting MO review*.
* **FO reason/comment in `scrCheckDetail` are read-only** (`DisplayMode.View`); a small
  per-row state (**queued / sent / replied** + reviewer) shows under the FO? checkbox.
* **FO inbox** (`scrInbox`) `Items` now require sent: `Filter(colTransactions, FlaggedToFO, FOSent)`.

### Change 4 — new MO "My Queue" (`scrMoQueue`)
* Entry point **FO responses (N)** on `scrOverview`
  (`N = CountRows(Filter(colTransactions, FlaggedToFO, FOSent, FOResponded, Not(LookUp(colChecks, ID=DailyReportCheckID).Completed)))`).
* Two groups across all reports: **Replied — ready for you** (`FOResponded`) shows the FO
  reason+comment (read-only green) with **Complete check** (enabled by the row's
  `canComplete`) and **Open check**; **Still with Front Office** (`!FOResponded`) shows
  *Awaiting reply from {reviewer}* + **Open check**. Completing a check removes its items
  from the queue (the queue filters out completed checks).

### Notes / minor deviations
* The send-batch formula keeps the spec's `With({toSend: …}, ForAll(…); Notify(…))` form
  (With binds `toSend` to a snapshot, so the count in the toast is stable).
* `canComplete` is unchanged in spirit: blocked while any `FlaggedToFO && !FOResponded`
  (sent or not), and every finding needs an MO reason.
* The app never sends email; it only sets `FOSent`/`FOSentOn` and ensures `FOReviewer` —
  the per-reviewer grouped emailing is a separate Power Automate flow.

---

## v1 (initial build)

Deliverable A: packable canvas source that packs into a valid `TZ01.msapp` and round-trips
losslessly. Five responsive screens built from vertical/horizontal auto-layout containers,
full Power Fx (Patch on edit, send-to-FO, complete/submit gating, FO respond, Notify,
Visible/DisplayMode logic), data-driven reason dropdowns from `colReasonConfig`, FK-based
navigation, and a logo placeholder. See `README.md` for build/run and the production
SharePoint data swap. Schema wins where it disagreed with the prototype.
