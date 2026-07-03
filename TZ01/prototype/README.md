# TZ01 — clickable HTML prototype

`TZ01_prototype.html` is the single-file, self-contained clickable prototype of the
TZ01 Treasury Daily Transaction Review app (MO + FO roles). Open it in any browser —
no build, no server. It is the **spec source of truth** the Power Apps app is ported
from (`../CHANGES.md` tracks the Power Apps deltas).

## Latest iteration — proposal chapters 8.3 + 14

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
