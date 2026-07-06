# TZ01 — clickable HTML prototype

`TZ01_prototype.html` is the single-file, self-contained clickable prototype of the
TZ01 Treasury Daily Transaction Review app (MO + FO roles). Open it in any browser —
no build, no server. It is the **spec source of truth** the Power Apps app is ported
from (`../CHANGES.md` tracks the Power Apps deltas).

## Iteration — My Queue at scale (accordion by check + bulk apply)

Handles checks with many findings (e.g. Check 1 = dozens of internal deals). Both
queues (MO My Queue, FO My Queue) group findings **by check into a collapsible
accordion**; expanding a check shows the **detail-style inline table** (quick-view
columns + per-row MO/FO reason & comment & flag) instead of one card per transaction.

- **Bulk apply**: select rows (or none = all) and set one reason/comment/flag across
  the whole selection in one click — so a check with 24 identical findings is one
  action, not 24. FO has the same bulk-apply for its reason/comment.
- **Anti-spam preserved**: sending stays **screen-level and batched** (one grouped
  notification per reviewer) with the confirm popup; MO *Replied* uses a bulk
  **Resend** (shared new comment, appended) and *Still with FO* a bulk **Nudge**.
- **Scannable**: groups collapsed by default show a status summary (N findings, X
  flagged, Y no-reason); only the expanded group renders its table.
- **Header/column alignment** is structural: header and cells share one `<table>`
  (thead + tbody), so columns can't drift.
- Demo data: Check 1 (FX) seeded with 10 transactions to show the accordion + bulk.

Check Detail is unchanged (it already handled many rows). The four screens are
preserved — only the queue card granularity changed from per-transaction to
per-check-group.

## Earlier iteration — proposal chapters 8.3 + 14

Aligned to `TZ01_Prototype_Proposal_EN.docx`:

1. **FO My Queue — batched send.** "Send response to MO" was removed from each finding
   card and promoted to a single **screen-level** button in the section header (mirrors
   MO My Queue's "Send flagged to FO"). It answers every pending finding that has a
   reason in one batch, so MO gets a single grouped notification.
2. **FO My Queue — "Open check" removed.** FO responds inline; it no longer deep-links
   into the read-only check screen.
3. **Confirm-before-send.** Both MO "Send flagged to FO" (My Queue **and** Check
   Analysis) and FO "Send response to MO" now open a confirmation dialog warning the
   user to review **all** findings first — one grouped notification per batch, so
   sending everything together avoids spamming reviewers.
4. **Per-check quick-view columns (ch. 8.3).** Each check's default transaction columns
   now match the "Columns required in View Table" table, in order; the "Show all
   columns" toggle still reveals the full SAP record (34 FX / 19 MM columns). The
   header display names follow the schema in ch. 14.5 (e.g. `Oposit Currency`).

Column keys/labels come from the FX/MM source schema (ch. 14.5.2 / 14.5.3); the
per-check sets correspond to the `TZ01 Check Columns` config list (ch. 14.9).

> Power Apps port of these four changes is a separate follow-up (not yet in `CHANGES.md`).
