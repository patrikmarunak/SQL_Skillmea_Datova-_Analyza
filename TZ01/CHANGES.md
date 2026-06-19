# TZ01 — change log

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
