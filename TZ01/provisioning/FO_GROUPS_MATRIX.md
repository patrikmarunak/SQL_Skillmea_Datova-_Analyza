# TZ01 FO Groups — Quick Reference Matrix

## The Complete Routing Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ FOREIGN EXCHANGE (FX) CHECKS                                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│ Check │ Check Name                  │ Assigned To     │ Policy              │
├───────┼─────────────────────────────┼─────────────────┼─────────────────────┤
│  1    │ Internal deals net to zero  │ Ivan Horvat     │ Notify Assigned     │
│  2    │ Internal deals matched      │ Ivan Horvat     │ Notify Assigned     │
│  3    │ Manually resent from SAP    │ (Not Routable)  │ Not Comparable      │
│  4    │ Hedge rate reconciliation   │ Ivan → Ana      │ Escalate On Timeout │
│  5    │ Late confirmations          │ Ivan → Ana      │ Escalate On Timeout │
│  6    │ FX Approvals (DTCC)         │ Ana Kovac       │ Notify Assigned     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ MONEY MARKET (MM) CHECKS                                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ Check │ Check Name                      │ Assigned To │ Policy              │
├───────┼─────────────────────────────────┼─────────────┼─────────────────────┤
│  1    │ Internal deals net to zero      │ Peter ★     │ Notify All          │
│  2    │ Amount mismatch reconciliation  │ Peter ★     │ Notify All          │
│  3    │ Booked trades match             │ Peter ★     │ Notify All          │
│  4    │ Credit line reconciliation      │ Peter       │ Single Trader       │
└─────────────────────────────────────────────────────────────────────────────┘

★ = Group Lead (Peter Cerny receives all MM notifications; routes internally)
```

---

## By FO Group

### 1. **FX Traders** (`FX|Traders`)
- **Scope:** All FX checks (1, 2, 4, 5, 6)
- **Policy:** Notify Assigned
- **Members:**
  - **Ana Kovac** (ana.kovac@mdlz.com) → Check 6 only
  - **Ivan Horvat** (ivan.horvat@mdlz.com) → Checks 1, 2, 4, 5
- **SLA:** 2 hours (escalate to Group Lead if no response)

### 2. **MM Reconciliation** (`MM|Traders`)
- **Scope:** All MM checks (1, 2, 3, 4)
- **Policy:** Notify All (group lead triage)
- **Members:**
  - **Peter Cerny** (peter.cerny@mdlz.com) [Group Lead]
- **Rule:** Single notification to Peter; he distributes internally
- **SLA:** Standard

### 3. **FX Late Transactions** (`FX|Late`)
- **Scope:** Check 5 only (late confirmations)
- **Policy:** Escalate On Timeout
- **Escalation Path:**
  - L1: **Ivan Horvat** (assigned, primary handler)
  - L2: **Ana Kovac** (FX Lead, escalation if no ack in 1h)
- **SLA:** 30 minutes (high urgency)

### 4. **MM Credit Line** (`MM|CreditLine`)
- **Scope:** Check 4 only (specialized)
- **Policy:** Single Trader
- **Members:**
  - **Peter Cerny** (peter.cerny@mdlz.com) [always]
- **Rule:** One point of contact; no rotation
- **SLA:** Specialized; Peter delegates if needed

---

## In Power Apps (WP-C: Popups)

When MO clicks "Send to FO" for a check:

```
Step 1: Lookup check in TZ01 FO Groups
        SELECT RoutingPolicy WHERE ReportType=varReportType 
               AND CheckNumbers LIKE %varCheckNumber%

Step 2: Load FO reviewers
        SELECT * FROM TZ01 Reviewers 
        WHERE Group='FO' 
              AND (ReportType=varReportType OR ReportType='*')
              AND (CheckNumber=varCheckNumber OR CheckNumber=0)

Step 3: Show confirm dialog
        "Notify [N FO reviewer(s)] — [routing policy description]"
        Example: "Notify 1 FO reviewer (Ana Kovac) — assigned to Check 6 approvals"
        Example: "Notify 1 FO group lead (Peter Cerny) — all MM checks routed"

Step 4: Call Notify FO flow
        PASS: ReviewerIDs, CheckNumber, RoutingPolicy, TransactionCount
```

---

## Flow Integration

**Power Automate "Notify FO" flow receives:**

```json
{
  "CheckNumber": 6,
  "ReportType": "FX",
  "ReviewerIDs": ["ana.kovac@mdlz.com"],
  "ReviewerNames": ["Ana Kovac"],
  "RoutingPolicy": "Notify Assigned",
  "TransactionCount": 3,
  "Subject": "TZ01: Check 6 (FX Approvals) — 3 findings flagged"
}
```

**Flow logic by policy:**

| Policy | Action |
|---|---|
| **Notify Assigned** | Send to `ReviewerIDs[0]` immediately |
| **Notify All** | Send to group lead (lookup by `Group=FO AND ReportType=... AND Default=true`) |
| **Single Trader** | Send to `ReviewerIDs[0]` (no rotation) |
| **Escalate On Timeout** | Send to `ReviewerIDs[0]`; wait 60min; if no reply, send to `ReviewerIDs[1]` |

---

## Managing the Matrix

### Add a New FO Trader

```
In TZ01 Reviewers (add row):
- Name: John Smith
- Email: john.smith@mdlz.com
- Group: FO
- ReportType: FX (or MM or *)
- CheckNumber: 2 (or 0 for all)
- Default: false
- Active: true
```

### Change Routing Policy

```
In TZ01 FO Groups (edit row):
Example: Change Check 4 from "Single Trader" to "Notify All"
→ RoutingPolicy: "Notify All"
→ RoutingRule: "All MM checks notify Peter; he routes to traders"
```

### Remove a Trader

```
In TZ01 Reviewers (soft delete):
- Set Active: false
- Update TZ01 FO Groups routing rule to reflect change
- Flow filters Active=true automatically
```

---

## Seeding & Regeneration

**Initial setup:**
```powershell
./TZ01_provision_full.ps1 -SiteUrl https://<tenant>.sharepoint.com/sites/TZ01 -ClientId <guid>
```

**Reseed (clear + refill all lists):**
```powershell
./TZ01_provision_full.ps1 -SiteUrl ... -ClientId ... -Reseed
```

**Seed only FO Groups (delta):**
```powershell
./TZ01_provision_v5_fo_groups.ps1 -SiteUrl ... -Reseed
```

---

## Troubleshooting

### Wrong FO reviewer notified
1. Check **TZ01 Reviewers** filter: ReportType matches? CheckNumber = 0 or matches current check? Group = "FO"? Active = true?
2. In Power Apps: `Trace(Filter(colReviewers, Group="FO" AND ReportType="FX" AND (CheckNumber=0 OR CheckNumber=6)))`

### "Escalate On Timeout" not working
1. Verify **TZ01 FO Groups** row: `RoutingPolicy = "Escalate On Timeout"`
2. Check Power Automate flow: Does it wait 60min before escalating? Does it track `FORespondedOn`?

### Group notifications going to wrong person
1. Review **TZ01 FO Groups** row: `RoutingPolicy = "Notify All"`
2. Check **TZ01 Reviewers**: Group lead has `Default = true` for that ReportType?

---

## Key Files

| File | Purpose |
|---|---|
| `TZ01/provisioning/TZ01_provision_full.ps1` | Creates & seeds all 10 lists (including FO Groups) |
| `TZ01/provisioning/FO_ROUTING.md` | Detailed FO routing design + policies + integration guide |
| `TZ01/provisioning/FO_GROUPS_MATRIX.md` | This file — quick visual reference |
| `TZ01/provisioning/README.md` | Step-by-step provisioning instructions |
| `TZ01/TZ01_PRODUCTION_UPGRADE.md` | Full production upgrade brief (WP-A through WP-H) |

---

## Related Checks & Data

**From Reason Config (ch. 14.7):**
- FX checks 1–6 each have multiple MO/FO reasons (2–4 per check)
- MM checks 1–4 each have multiple MO/FO reasons
- `AutoFlagFO` column = true means selecting this reason automatically sends to FO

**From Check Columns (ch. 8.3):**
- FX 1: 8 columns (Company Code, Transaction, Business Partner, ..., Trader)
- MM 4: 7 columns (Company Code, Transaction, Product Type, ...)
- Per-check visibility defined in PowerShell seed (lines 1955–2500+)

**From Daily Transactions:**
- Each transaction carries `FlaggedToFO` (boolean), `FOReviewer` (text), `FOSent` (bool), `FOSentOn` (datetime)
- MO field ownership: {Reason, Comment, FlaggedToFO, FOReviewer, FOSent, FOSentOn}
- FO field ownership: {FOReason, FOComment, FORespondedOn, FOResponded}
