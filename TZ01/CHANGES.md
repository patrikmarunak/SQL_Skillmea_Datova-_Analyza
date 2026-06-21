# TZ01 — change log

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
