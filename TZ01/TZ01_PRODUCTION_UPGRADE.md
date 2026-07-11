# TZ01 — production upgrade brief (for local Claude Code via canvas co-authoring)

**How to use this file.** Put it in the root of your local clone of this repo, then run
`claude` from that root with the TZ01 app open in Power Apps Studio (co-authoring ON,
see `TZ01/ci/CANVAS_COAUTHOR.md`). The canvas-authoring MCP edits the **live app**
(`.pa.yaml`, modern source). This brief turns the app from a prototype into a
production application. Work through the work packages in order; each has explicit
**acceptance criteria**. Use the compile/validate MCP tools after each package and fix
every App Checker error before moving on.

**Read these repo files first (they are the data + behaviour contract):**
- `TZ01/src/Src/App.fx.yaml` → the `PRODUCTION SWAP` comment block = exact list names,
  `ClearCollect`/`RenameColumns` maps, per-action write-back contract.
- `TZ01/config/TZ01_app_config.yaml` → roles, patch ownership, popups, attachments,
  flow contracts, quick-view columns.
- `TZ01/CHANGES.md` → what each screen already does (v3.2 / v4 / v4.1).
- `TZ01/provisioning/TZ01_provision_full.ps1` → the live SharePoint schema (display +
  internal names, choices) the app binds to.

The 9 data sources already exist in the app: **TZ01 Daily Item, TZ01 Daily Reports,
TZ01 Daily Report Checks, TZ01 Daily Transactions, TZ01 Top Report, TZ01 Reason Config,
TZ01 Reviewers, TZ01 Check Columns, TZ01 Input Files**. Do not create new data sources.

---

## 0. Golden rules

1. **Never hardcode** environment-specific values (site URL, list GUID, emails, flow
   IDs). Read from the connected data sources / `Param()` / `User()`.
2. **Field ownership is split** (MO vs FO) so saves never collide — keep it:
   - MO writes: `MO Reason, MO Comment, Flagged To FO, FO Reviewer, FO Sent, FO Sent On`
     (+ check `Completed/Completed On`, report `Submitted by/Submitted On`).
   - FO writes: `FO Reason, FO Comment` (append-only), `FO Responded On`.
   - The app **never** writes a stored `Status` — status is **derived**.
3. **Every write is `IfError`-wrapped** with a failure `Notify(...)` and, on success, an
   audit append (see §2) + a user `Notify(...)`.
4. **Every batched notify-out action opens a confirm popup first** (§4).
5. **Every state-changing button gets a `Tooltip`** (§9), and disabled buttons explain
   *why* in the tooltip.
6. Reuse the **TZ20 design tokens** (§8) so TZ01 looks like the rest of the suite.

---

## 1. Flow-trigger convention (leave the flow for the user to paste)

Wherever the app must call a Power Automate flow, **do not invent a flow**. Insert a
commented, clearly-marked block the user will complete, and keep the app working
without it (set the underlying flags so the UI is consistent):

```powerfx
// ===== TODO(flow): <purpose> =====
// Add the flow as a data source, then replace this block with the real call.
//   <FlowName>.Run(
//       <param1>,   // e.g. dailyItemId  = varSelectedItem.ID
//       <param2>,   // e.g. reportType   = varCurrentReport.ReportType
//       ...
//   );
// The flow owns: <what the flow does — grouping, emailing, parsing, etc.>
// ==================================
```

Flow call sites (create one TODO block at each):
- **Notify FO** — after the batched *Send flagged to FO* (Check Analysis **and** My Queue).
  App sets `Flagged To FO / FO Sent / FO Sent On`; flow groups per `FO Reviewer` and
  emails one deeplink each.
- **Notify MO** — after the FO batched *Send responses to MO*. App sets `FO Responded On`;
  flow sends one grouped notification.
- **Run validation** — after the *Run validation* confirm on a manually uploaded input
  file. Params: `dailyItemId, fileKind, fileName`. Flow parses the file, (re)writes
  Daily Report Checks + Daily Transactions, appends the Review Log; the app then
  refreshes the day (§2).
- **Escalation / reminder** — none from the app (time-triggered flow); no call site.

Acceptance: every place that used to just `Notify(...)` a simulated send now (a) sets the
real SharePoint flags via `Patch`, and (b) carries exactly one `TODO(flow)` block.

---

## 2. Work package A — data layer to production

Replace the offline seed in `App.OnStart` with the production loads. The exact block is
in `TZ01/src/Src/App.fx.yaml` under `PRODUCTION SWAP` — port it to the live OnStart:

- Load config + parents on start: `colReasonConfig, colReviewers, colCheckColumns,
  colDailyItems, colDailyReports, colChecks, colTopReport, colInputFiles` (with the
  `RenameColumns` maps shown there). Keep `varTheme`, roles, deeplinks, audit seed.
- **Transactions are day-scoped and delegable**: load only the selected day
  `Filter('TZ01 Daily Transactions', DayKey = varDayKey)` and `AddColumns` the app-local
  fields `_state, _isDirty, _foDraftReason, _foDraftComment` (never stored in SharePoint).
  Re-run the `colTxnCells` flatten **after** this load.
- **Refresh helper** — add a reusable action `UpdateContext` / named formula that
  re-runs the day load + flatten, and call it: after any batched send, after a flow
  returns, and behind a manual **Refresh** icon on the overview (with a `Refresh(<source>)`
  first so SharePoint delegation cache is dropped).
- **Loading state**: wrap the production loads in `Set(varLoading, true) … Set(varLoading,
  false)`; the overview already has a loading scrim bound to `varLoading`.
- **Offline**: keep the `!Connection.Connected` banner; edits stay in the collections and
  are re-`Patch`ed on reconnect (dirty rows = `Filter(colTransactions, _isDirty)`).

Acceptance: cold start loads real data; the overview refresh icon re-queries; no
non-delegable warnings on the transaction load; App Checker clean.

---

## 3. Work package B — patches to SharePoint

Every MO/FO edit and workflow action must `Patch` the real list (not just the local
collection). Pattern (MO reason shown; mirror for all owned fields):

```powerfx
IfError(
    Patch('TZ01 Daily Transactions',
          LookUp('TZ01 Daily Transactions', ID = ThisItem.ID),
          { 'MO Reason': Self.Selected.Value });
    // keep the local collection in sync so the UI updates without a full reload:
    Patch(colTransactions, ThisItem, { MOReason: Self.Selected.Value, _isDirty: false }),
    Notify("Save failed — " & FirstError.Message, NotificationType.Error)
)
```

Apply to: MO reason/comment, Flag-to-FO (+ auto-flag from `colReasonConfig.AutoFlagFO`),
batched *Send flagged to FO* (`FO Sent/FO Sent On`), FO reply (`FO Reason`, append
`FO Comment`, `FO Responded On`), resend (bump `FO Sent On`), complete check
(`'TZ01 Daily Report Checks'`), submit report (`'TZ01 Daily Reports'`), and late-entry →
`'TZ01 Top Report'` on completion of an `Is Late` check. Reference the write-back list in
the `PRODUCTION SWAP` block.

Audit: every action appends to `colAudit` **and** to the report's `Review Log`
(append-only) via `Patch('TZ01 Daily Reports', rep, {'Review Log': rep.'Review Log' &
Char(10) & Text(Now(),"yyyy-mm-dd hh:mm") & " (CET) – " & <text>})`.

Acceptance: reload the app after each action → the change persisted in SharePoint; MO and
FO never write the same column.

---

## 4. Work package C — warning popups everywhere (batched / irreversible actions)

Use one reusable overlay pattern (scrim = a `GroupContainer` covering the screen,
`LayoutJustifyContent=Center`, `LayoutAlignItems=Center`, `Visible = var…`, `ZIndex`
high; card = a vertical container with title + message + Cancel/OK). Bind each to its own
`var`. The classic app already has these (`cfSend/cfQs/cfIs/cfVal/cfSub/cfCd`) — build the
equivalents in the live modern app. Confirm **before**:

| Action | Title | Message must say |
|---|---|---|
| Send flagged to FO (Checks + My Queue) | Send flagged findings to Front Office? | how many reviewers / findings, one grouped email each, **review ALL first** |
| Send responses to MO (FO inbox) | Send your responses to Middle Office? | how many will send, how many have **no reason yet** (won't send), review all |
| Run validation (after upload) | Run validation now? | validation regenerates checks/findings, nothing runs until confirm |
| Submit report | Submit report? | locks the report as Completed |
| Complete check | Mark check complete? | writes result + (if late) TOP report |

Validation runs **only** on the OK of its confirm — never on upload alone. Add a comment
that the anti-spam warning exists so reviewers get one notification per batch.

Acceptance: none of the 5 actions fire without its confirm; Cancel is a no-op.

---

## 5. Work package D — attachment window at every placeholder

Per the data model, evidence attaches at **Daily Item** level and **Daily Report Check**
level (native SharePoint attachments). Canvas can only write SP attachments through an
**Edit Form hosting an Attachments card** — reuse the exact TZ20 pattern:

```
Form@2.4.4  (DataSource = the list, Item = the target record, DefaultMode = Edit)
└─ TypedDataCard  DataField = "{Attachments}"
   └─ Attachments@2.3.0
Then a button:  SubmitForm(frmAttach);  OnSuccess → refresh + audit + Notify
```

TZ20 does this in `scrDailyOverview` (item attachments) and `scrBankLimitChangeData` —
open those for the concrete control tree and copy it.

Replace **every** attachment placeholder in TZ01 with a real attachment dialog (an
overlay hosting the mini Edit form + Attachments control + Save/Cancel):
- Check Detail → *Attach check evidence* / *Attach VITUS approval* → Form.Item =
  `LookUp('TZ01 Daily Report Checks', ID = varCurrentCheck.ID)`.
- FO inbox card → *Attach* (FO evidence for the response) → same check record.
- Overview → day-level evidence → Form.Item =
  `LookUp('TZ01 Daily Item', ID = varSelectedItem.ID)`.
- Show existing attachments read-only wherever a record is displayed (gallery over
  `record.Attachments` → name + `Launch(link)`).

For **VITUS (FX Check 6, Characteristics = EXCEPTIONAL)**: the check cannot be completed
while `MO Reason = "Missing approval (goes to FO)"` and there is no attachment — enforce
in the complete-check guard.

Input-file upload (overview) also needs the real file: host an Attachments card (or file
picker) that writes into the **TZ01 Input Files** library, then the metadata row + the
`TODO(flow)` validation call.

Acceptance: from the app you can add and see attachments on a Daily Item and on a Daily
Report Check; they appear in SharePoint on that item.

---

## 6. Work package E — gallery header / column alignment validation

For **every** gallery that renders tabular data (checks list, transactions, TOP report,
queue/inbox record tables, admin config), verify and fix:

1. **A header row exists** directly above the gallery.
2. **Header columns line up with the row columns.** The robust way in canvas: put the
   header labels in a **horizontal auto-layout `GroupContainer`** whose children use the
   **same `Width` / `FillPortions`** as the corresponding cell controls in the gallery
   template (or drive both from the same width constants / `colCheckColumns.Order`). If
   the row template uses a nested **horizontal gallery** for dynamic columns, the header
   must be the **same horizontal gallery** over the same `Items` and identical
   `TemplateSize`, placed in a container that scrolls in sync (or shares the scroll).
3. **No fixed-pixel header over a stretchy row** (or vice-versa) — that's the usual
   drift. Match the layout mode on both.

Method: for each gallery, list its cell controls + widths, list the header controls +
widths, and assert they match 1:1. Report any mismatch, then fix by aligning widths /
switching both to the same auto-layout. Reuse the TZ20 `TableDataField@1.5.0` /
`DataTableColumn` pattern where a real data-table fits — its header is generated in sync
with the columns and removes this whole class of drift.

Acceptance: a written list "gallery → header present? → columns aligned?" for all
galleries, all green; visually the header sits exactly above its column at narrow and wide
widths.

---

## 7. Work package F — reuse TZ20 design (galleries, containers, filters, comboboxes)

Open `TZ20 - Bank Investment Limits` (a33a76ce-TZ20__Bank_Investment_Limits.msapp is in
this repo's upload history / the solution export) and mirror its **modern** design system:

- **Controls**: prefer modern — `Gallery@2.15.0`, `GroupContainer@1.5.0` (auto-layout),
  `ModernText@1.0.0`, `Button@0.0.45`, `ModernDatePicker@1.0.0`, `TableDataField@1.5.0`.
- **Filters / pickers**: use `Classic/ComboBox@2.4.0` with the TZ20 style — light fill
  `RGBA(245,245,245,1)`, `BorderThickness=0`, `Font=Font.'Segoe UI'`, `Height=32`,
  `HoverBorderColor=RGBA(16,110,190,1)`, `DisplayFields=["Value"]`. Replace the current
  plain search/dropdown filters with this look; keep the delegable local-collection
  filtering behind them.
- **Containers**: wrap screen regions in auto-layout `GroupContainer`s (header / filter
  bar / body / footer) with consistent `PaddingLeft/Right = 20`, `LayoutGap` ~10, so
  everything reflows — copy TZ20's container nesting.
- **Galleries**: vertical `Gallery@2.15.0`, card = an auto-layout container; spacing and
  `TemplatePadding` per TZ20.
- Keep the TZ01 brand purple header (`varTheme.Purple`), but align control shapes, radii,
  spacing and filter styling to TZ20.

Acceptance: side-by-side, TZ01's galleries, containers, filter bar and comboboxes read as
the same design language as TZ20.

---

## 8. Work package G — tooltips everywhere

Set a `Tooltip` on **every** interactive control (buttons, icons, dropdowns, comboboxes,
checkboxes, the show-all toggle, filter inputs, attachment/upload, nav). Rules:
- Action buttons: what it does + who it affects (e.g. *"Send all flagged findings to their
  FO reviewers — one grouped email each"*).
- **Disabled** buttons: why it's disabled (e.g. *"Set an MO reason on every finding and
  resolve any open FO item before completing"*) — reuse the existing disabled-reason
  expressions.
- Icon-only controls (chevrons, refresh, attach): a plain-language label; also set
  `AccessibleLabel` to the same text.

Acceptance: hovering any control shows a helpful tooltip; no interactive control has an
empty tooltip.

---

## 8b. Work package H — My Queue at scale (accordion by check + inline table + bulk apply)

A check can carry **dozens** of findings (e.g. FX Check 1 internal deals). One card per
transaction does not scale. Both **MO My Queue** and **FO My Queue** must group findings
**by check** into a collapsible accordion; expanding a check shows the **detail-style
inline table** (the feature-D dynamic columns + per-row MO/FO reason/comment/flag) with a
**bulk-apply** bar. This mirrors the prototype's v5 queue. Match this UX; keep the screens.

**Chosen structure — flat "accordion" gallery (do this; avoids 3-level nesting).**
Do **not** nest a groups-gallery around a rows-gallery around the cells-gallery (3 levels of
galleries with editable controls is slow and the editor fights it). Instead drive **one**
vertical gallery from a pre-built, interleaved collection; only the horizontal **`galCells`**
(dynamic columns, reused from Check Detail) stays nested → **max 2 gallery levels**.

Build the row model in a refresh action (call it on queue open, after edits that change
membership, and after expand/collapse):

```powerfx
// which check-groups are expanded (persists across refresh)
// toggle:  If(key in colExpanded, RemoveIf(colExpanded, Value=key), Collect(colExpanded,{Value:key}))

// section predicate examples (bare, over the day-scoped colTransactions):
//   TO REVIEW  : !FOSent
//   REPLIED    : FlaggedToFO && FOSent && FOAnswered
//   AWAITING   : FlaggedToFO && FOSent && !FOAnswered
// (FOAnswered = FOSent && FORespondedOn >= FOSentOn — the derived flag from WP-B.)

ClearCollect(colQueueRows,
  Ungroup(
    ForAll(
      // one entry per check that has rows in this section, in check order:
      Sort(
        Distinct(Filter(colTransactions, <sectionPredicate>), DailyReportCheckID) As GK,
        Value
      ) As G,
      With({ chk: LookUp(colChecks, ID = G.Value),
             rows: Filter(colTransactions, DailyReportCheckID = G.Value, <sectionPredicate>) },
        { Block:
            Table(
              // header row (always present)
              { Kind:"header", Sort:0, CheckID: chk.ID, CheckKey: chk.CheckKey,
                Title: chk.ReportType & " · Check " & chk.CheckNumber, Scope: chk.Scope,
                Cnt: CountRows(rows),
                CntFlagged: CountRows(Filter(rows, FlaggedToFO)),
                CntNoReason: CountRows(Filter(rows, IsBlank(MOReason))) }
            ) &
            // detail rows only if the group is expanded
            If(chk.CheckKey in colExpanded,
               ForAll(rows As R, { Kind:"row", Sort:1, CheckID: chk.ID, CheckKey: chk.CheckKey, Txn: R })
            )
        }
      ),
      "Block"     // Ungroup flattens the per-group Block tables into one ordered list
    )
  )
);
```

`galQueue.Items = colQueueRows`. In the template, switch controls by `ThisItem.Kind`:

```
galQueue (vertical; TemplateSize dynamic — see below)
  ├─ conHeader   Visible = ThisItem.Kind = "header"
  │    icoChevron (rotate when expanded)  OnSelect = toggle colExpanded + rebuild colQueueRows
  │    lblTitle = ThisItem.Title & "  ·  " & ThisItem.Scope
  │    lblBadges = ThisItem.Cnt & " findings · " & ThisItem.CntFlagged & " flagged · " & ThisItem.CntNoReason & " no reason"
  │    — bulk bar —  drpBulkReason (Items = reasons for this check) · txtBulkComment · btnApply · btnFlag/btnUnflag
  │    btnComplete  (DisplayMode gated to canComplete for ThisItem.CheckID)
  └─ conRow      Visible = ThisItem.Kind = "row"
       chkSelect (bound to  ThisItem.Txn.ID in colSelected)
       galCells  (HORIZONTAL — dynamic quick-view columns from colTxnCells for ThisItem.Txn) 
       drpMOReason · txtMOComment · chkFlagFO      (MO queue)   — or drpFOReason · txtFOComment (FO queue)
```

Row height: give `conHeader` a fixed height and `conRow` a fixed height; set
`galQueue.TemplateSize = If(ThisItem.Kind="header", <headerH>, <rowH>)` so headers and rows
size correctly in one gallery.

**Selection + bulk apply.**
```powerfx
// row checkbox OnCheck/OnUncheck:
//   Collect(colSelected,{Id:ThisItem.Txn.ID})   /   RemoveIf(colSelected, Id=ThisItem.Txn.ID)

// btnApply.OnSelect (targets = selected rows of THIS group, else ALL rows of the group):
With({ tg: Filter(colTransactions, DailyReportCheckID = ThisItem.CheckID, <sectionPredicate>,
                  (CountRows(colSelected)=0 || ID in colSelected.Id)) },
  ForAll(tg As R,
    IfError(
      Patch('TZ01 Daily Transactions', LookUp('TZ01 Daily Transactions', ID=R.ID),
            { 'MO Reason': drpBulkReason.Selected.Value, 'MO Comment': txtBulkComment.Text });
      Patch(colTransactions, R, { MOReason: drpBulkReason.Selected.Value, MOComment: txtBulkComment.Text }),
      Notify("Save failed — " & FirstError.Message, NotificationType.Error)));
  // auto-flag if the chosen reason has AutoFlagFO (config-driven, WP-B), then:
  Notify("Applied to " & CountRows(tg) & " findings", NotificationType.Success)
);
// rebuild colQueueRows so the header counts refresh.
```

**Anti-spam stays (unchanged from WP-C):** sending is **screen-level + batched** with the
confirm popup (one grouped notification per reviewer). MO *Replied* = a bulk **Resend**
(one shared new comment, appended to each `MO Comment` thread, reopens the rows); *Still
with FO* = a bulk **Nudge** (bump `FO Sent On`, no new ask). No per-row send.

**Scannability:** groups collapsed by default (empty `colExpanded`); the header badges give
the at-a-glance state; only expanded groups have `Kind="row"` entries, so the gallery stays
short and fast even with hundreds of findings. Keep the existing check/reviewer/status
filters (they filter which rows feed the section predicate).

**Alternative (only if 1:1 prototype fidelity is required):** true nested galleries
`galGroups → galRows → galCells`. Works, but 3 levels with editable controls is heavier and
the editor may warn — prefer the flat gallery above.

Acceptance: a check with 20+ findings shows as **one** collapsible group; expanding reveals
the inline table with aligned header (WP-E); bulk-apply sets reason/comment/flag on the
selected (or all) rows in one action and Patches SharePoint; batched send + confirm
unchanged; App Checker clean; smooth at 100+ findings.

---

## 9. Final acceptance checklist

- [ ] Cold start loads all 9 lists from SharePoint; transactions day-scoped + delegable.
- [ ] Refresh icon re-queries; loading scrim shows during loads.
- [ ] Every MO/FO edit + workflow action Patches the real list, `IfError`-wrapped, with
      audit append to `colAudit` and the report Review Log.
- [ ] MO/FO field ownership preserved; no stored Status; status derived.
- [ ] 5 confirm popups present and blocking; validation only on confirm.
- [ ] Attachment dialog (Form + `Attachments@2.3.0`) at every placeholder; works per Daily
      Item and per Daily Report Check; existing attachments listed with open links.
- [ ] Every flow call site is a working flag-set + one `TODO(flow)` block (no invented flow).
- [ ] Every tabular gallery has a header; header columns aligned with row columns (list + all green).
- [ ] My Queue (MO + FO) grouped by check (accordion); expand shows the inline table + bulk
      apply; flat single gallery over `colQueueRows` (max 2 gallery levels); scales to 100+ findings.
- [ ] TZ20 design reused: galleries, containers, filter bar, comboboxes, modern controls.
- [ ] Tooltip on every interactive control; disabled buttons explain why; AccessibleLabel on icons.
- [ ] App Checker: 0 errors. App opens without repair.

## 10. Data contract appendix

List names, key columns, rename maps and per-action write targets are authoritative in
`TZ01/src/Src/App.fx.yaml` (`PRODUCTION SWAP` block) and
`TZ01/provisioning/TZ01_provision_full.ps1` (live schema: display + internal names,
choices). Quick-view columns per check come from **TZ01 Check Columns** (ch. 8.3); reason
dropdowns + `Auto Flag FO` / `Requires Comment` from **TZ01 Reason Config** (ch. 14.7);
roles (MO/FO/ADMIN) from **TZ01 Reviewers** `Group`. Do not restate these values in
formulas — read them from the lists.
