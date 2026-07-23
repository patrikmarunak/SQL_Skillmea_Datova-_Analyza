# TZ01 FO Notification Routing

## Overview

Front Office (FO) notifications follow a **group-based routing model** that maps checks (FX/MM) to traders and defines routing policies (notify group vs individual vs escalate). The model consists of two complementary SharePoint lists working in concert:

1. **TZ01 Reviewers** — Individual reviewer details (who they are, which checks they handle)
2. **TZ01 FO Groups** — Group routing rules (which team handles which checks, notification strategy)

## The Two Lists

### 1) TZ01 Reviewers (Core Routing)

Stores each FO reviewer with their assignment:

| Field | Type | Example | Note |
|---|---|---|---|
| Title | Text | Ana Kovac | Reviewer name (also display label) |
| Name | Text | Ana Kovac | Full name |
| Email | Text | ana.kovac@mdlz.com | Email address |
| Reviewer | User | ana.kovac@mdlz.com | SharePoint user (resolved if possible) |
| **Group** | Choice | FO | Role: **MO**, **FO**, or **ADMIN** |
| **ReportType** | Text | FX | **FX**, **MM**, or **\*** (all) |
| **CheckNumber** | Number | 6 | Specific check (0 = all checks of ReportType) |
| Default | Boolean | false | Is this the default reviewer for the type/check? |
| Active | Boolean | true | Include in routing decisions? |

**Example seed:**

| Name | Email | Group | ReportType | CheckNumber | Default |
|---|---|---|---|---|---|
| Martina Medvedova | martina.medvedova@mdlz.com | **MO** | * | 0 | ✓ |
| Ana Kovac | ana.kovac@mdlz.com | **FO** | FX | **6** | |
| Peter Cerny | peter.cerny@mdlz.com | **FO** | MM | **0** | ✓ |
| Ivan Horvat | ivan.horvat@mdlz.com | **FO** | FX | **4** | |

**Query pattern** (in Power Apps notification logic):

```
Filter(
  colReviewers,
  Group="FO"  AND
  (ReportType=varReportType OR ReportType="*")  AND
  (CheckNumber=0 OR CheckNumber=varCheckNumber)
)
```

### 2) TZ01 FO Groups (Routing Policy)

Defines **how** to notify FO — group strategy, responsibilities, escalation rules.

| Field | Type | Example | Note |
|---|---|---|---|
| Title | Text | FX Traders | Group name (display label) |
| **GroupID** | Text | FX\|Traders | Unique key for app logic |
| **GroupName** | Text | FX Traders | Friendly name |
| **ReportType** | Choice | FX | FX or MM |
| **CheckNumbers** | Text | 1,2,4,5,6 | Comma-separated list; "*" = all checks |
| **RoutingPolicy** | Choice | Notify Assigned | See routing policies below |
| **RoutingRule** | Note | Check 6 → Ana... | Human-readable rule for ops |
| TeamSize | Number | 2 | Count of traders in group (FYI) |
| Active | Boolean | true | Is this group active? |

**Example seed:**

| GroupID | GroupName | ReportType | CheckNumbers | RoutingPolicy | RoutingRule |
|---|---|---|---|---|---|
| FX\|Traders | FX Traders | FX | 1,2,4,5,6 | **Notify Assigned** | Check 6 → Ana; Checks 1,2,4,5 → Ivan; escalate to Group Lead if no response in 2h |
| MM\|Traders | MM Reconciliation | MM | 1,2,3,4 | **Notify All** | All MM checks → Peter (Group Lead); Peter triages and routes to specialist |
| FX\|Late | FX Late Transactions | FX | 5 | **Escalate On Timeout** | Check 5 → Ivan; escalate to Ana if no acknowledgment in 1h |
| MM\|CreditLine | MM Credit Line | MM | 4 | **Single Trader** | Check 4 → Peter always (single point of contact) |

## Routing Policies

### 1) **Notify Assigned** (most granular)
Send notification **only** to the reviewer assigned to that specific check.

**When to use:**
- Specialized checks requiring expertise (e.g., Check 6 approvals → Ana)
- Need clear single point of contact
- Reviewer roster is stable

**Power Apps flow trigger:**
```
Filter(colReviewers, Group="FO" AND ReportType=varReportType AND CheckNumber=varCheckNumber)
→ Send to each reviewer's email
```

**Example:** Check 6 (FX Approvals) → notify only Ana Kovac

---

### 2) **Notify All** (broadcast to group lead, who routes)
Send notification to the **group lead**; they triage and route to specialists.

**When to use:**
- Multiple checks under one roof (e.g., all MM checks)
- Group lead has bandwidth to manage inbox
- Reduces app-to-email chatter (one notification per day per group)

**Power Apps flow trigger:**
```
Filter(colReviewers, Group="FO" AND ReportType=varReportType AND CheckNumber=0)
→ Send to group lead only (Default=true)
```

**Example:** All MM checks → notify Peter Cerny (group lead); he distributes internally

---

### 3) **Single Trader** (dedicated resource)
Always route to the same trader, no rotation.

**When to use:**
- Specialized high-SLA checks (e.g., credit line checks)
- Trader has exclusive responsibility
- Minimize handoff delays

**Power Apps flow trigger:**
```
Filter(colReviewers, Group="FO" AND ReportType=varReportType AND CheckNumber=varCheckNumber)
→ Send to the one assigned reviewer
```

**Example:** Check 4 (MM Credit Line) → always notify Peter Cerny

---

### 4) **Escalate On Timeout** (primary + escalation)
Send to **assigned trader** first; if no acknowledgment in N minutes, escalate to **group lead**.

**When to use:**
- High-SLA checks (30–60 min turnaround)
- Need guaranteed response
- Escalation path is known

**Power Apps flow trigger:**
```
1) Send to assigned reviewer
2) Wait 30/60 min
3) If no reply status → send reminder to group lead (escalation)
```

**Example:** Check 5 (FX Late confirmations) → notify Ivan (assigned); escalate to Ana (FX Lead) if no ack in 1h

---

## App Integration Points

### In Power Apps (WP-C: Popups)

When MO clicks **"Send to FO"**, the app:

1. **Identifies FO reviewers** for this check:
   ```powerFx
   Set(
     varFOReviewers,
     Filter(
       colReviewers,
       Group="FO"  AND
       (ReportType=varReportType OR ReportType="*")  AND
       (CheckNumber=0 OR CheckNumber=varCheckNumber)
     )
   );
   ```

2. **Looks up routing policy** for this check:
   ```powerFx
   Set(
     varRoutingPolicy,
     LookUp(
       colFOGroups,
       ReportType=varReportType AND
       (CheckNumbers="*" OR CheckNumbers Like "*" & Text(varCheckNumber) & "*")
     ).RoutingPolicy
   );
   ```

3. **Shows confirm dialog**:
   - If "Notify All": shows group lead name (e.g., "Notify Peter Cerny (MM Group Lead)")
   - If "Notify Assigned": shows assigned trader (e.g., "Notify Ana Kovac (Check 6 Approvals)")
   - If "Escalate On Timeout": shows both (e.g., "Notify Ivan Horvat (assigned); escalate to Ana if no response in 1h")

4. **Calls flow** with routing info:
   - Pass reviewer ID(s)
   - Pass check number
   - Pass routing policy
   - Flow decides notification recipients + timing

### In Power Automate Flow

The **"Notify FO"** flow receives:

```json
{
  "CheckNumber": 6,
  "ReportType": "FX",
  "ReviewerIDs": ["ana.kovac@mdlz.com"],
  "RoutingPolicy": "Notify Assigned",
  "TransactionCount": 3,
  "Subject": "TZ01: Check 6 (FX Approvals) — 3 findings flagged"
}
```

And executes:

- **Notify Assigned:** Send to email in `ReviewerIDs[0]`
- **Notify All:** Send to group lead (Peter for MM, Ana for FX Lead)
- **Single Trader:** Send to the named trader
- **Escalate On Timeout:** Send now + queue escalation for 1h later

---

## Provisioning & Seeding

### Initial Setup

1. Run `TZ01_provision_full.ps1` → creates both lists with seed data
2. Or run `TZ01_provision_v5_fo_groups.ps1` (delta) → creates only FO Groups + cross-checks Reviewers

### Seed Data

**TZ01 Reviewers** (5 rows — MO + 3 FO + ADMIN):
- Martina Medvedova (MO, default)
- Ana Kovac (FO, FX, Check 6)
- Peter Cerny (FO, MM, all checks, default)
- Ivan Horvat (FO, FX, Check 4)
- (+ ADMIN if needed)

**TZ01 FO Groups** (4 rows — 2 FX + 2 MM):
- FX Traders (Checks 1,2,4,5,6) → Notify Assigned
- MM Reconciliation (Checks 1,2,3,4) → Notify All
- FX Late Transactions (Check 5) → Escalate On Timeout
- MM Credit Line (Check 4) → Single Trader

### Reseed

```powershell
./TZ01_provision_full.ps1 -SiteUrl "https://<tenant>.sharepoint.com/sites/TZ01" -Reseed
```

Clears all rows and re-seeds with canonical data (lists + columns kept). Use after updating seed in generator.

---

## Cross-Reference: Checks → FO Routing

Based on proposal ch. 14.7 (Reason Config) and the seed above:

| Report | Check | Check Name | FO Routable? | Routed To | Policy |
|---|---|---|---|---|---|
| **FX** | 1 | Internal deals net to zero | ✓ | Ivan Horvat | Notify Assigned |
| | 2 | Internal deals matched | ✓ | Ivan Horvat | Notify Assigned |
| | 3 | Manually resent from SAP | ✗ | (none) | Not Comparable |
| | 4 | Hedge rate reconciliation | ✓ | Ivan Horvat → Ana Kovac | Escalate On Timeout |
| | 5 | Late confirmations | ✓ | Ivan Horvat → Ana Kovac | Escalate On Timeout |
| | 6 | FX Approvals (DTCC) | ✓ | Ana Kovac | Notify Assigned |
| **MM** | 1 | Internal deals net to zero | ✓ | Peter Cerny | Notify All |
| | 2 | Amount mismatch reconciliation | ✓ | Peter Cerny | Notify All |
| | 3 | Booked trades match | ✓ | Peter Cerny | Notify All |
| | 4 | Credit line reconciliation | ✓ | Peter Cerny | Single Trader |

---

## Customization Guide

### Add a New FO Trader

1. Add row to **TZ01 Reviewers**:
   ```
   Name: John Smith
   Email: john.smith@mdlz.com
   Group: FO
   ReportType: FX (or MM or *)
   CheckNumber: 2 (or 0 for all)
   Default: false
   Active: true
   ```

2. If new group lead (e.g., John is FX assistant), update:
   ```
   CheckNumber: 0
   Default: true  ← enables "Notify All" routing
   ```

3. Update **TZ01 FO Groups** routing rule if new responsibilities:
   ```
   e.g., "Checks 1,2 → Ivan (primary); John (backup)"
   ```

### Change Routing Policy for a Check

1. Edit row in **TZ01 FO Groups**:
   ```
   Example: Change Check 4 from "Single Trader" to "Notify All"
   → RoutingPolicy: Notify All
   → RoutingRule: "Check 4 (Credit Line) → notify Peter; he routes to specialist"
   ```

2. No changes needed in Power Apps code—flow logic references `colFOGroups.RoutingPolicy`

### Remove a Trader

1. Set `Active: false` in **TZ01 Reviewers** (soft delete)
2. Update **TZ01 FO Groups** routing rule to reflect
3. Scheduler: Power Automate flow filters `Active=true` automatically

---

## Troubleshooting

### "Notify FO" shows wrong reviewer

1. Check **TZ01 Reviewers** filter logic:
   - ReportType matches?
   - CheckNumber = 0 or matches current check?
   - Group = "FO"?
   - Active = true?

2. Test filter in Power Apps:
   ```powerFx
   Trace(Filter(colReviewers, Group="FO" AND ReportType="FX" AND (CheckNumber=0 OR CheckNumber=6)))
   ```

### "Escalate On Timeout" not working

1. Check **TZ01 FO Groups** row:
   - RoutingPolicy = "Escalate On Timeout"?

2. Check Power Automate flow:
   - Does it wait for N minutes before escalating?
   - Does it capture initial send timestamp?

3. Check reply status tracking:
   - Is `FOResponded` being set to true on trader reply?
   - Flow queries: `WHERE FOResponded=false AND FOSentOn < Now-1h`?

### Notification goes to wrong group

1. Review **CheckNumbers** field in **TZ01 FO Groups**:
   - Is the check listed?
   - e.g., "1,2,4,5,6" should include the current check
   - Use "*" for all checks if intended

2. Verify app logic matches policy:
   - Power Apps flow trigger should respect `colFOGroups.RoutingPolicy`
   - No hardcoded email addresses in flow

---

## Implementation Checklist (WP-C + Flow Integration)

- [ ] Seed **TZ01 Reviewers** with 5 rows (MO + 3 FO + ADMIN)
- [ ] Seed **TZ01 FO Groups** with 4 routing rules (FX/MM + policy matrix)
- [ ] In app `Popups` screen: load `colFOGroups` on startup
- [ ] In "Send to FO" popup: show reviewer name + routing policy
- [ ] In Power Automate flow: read `RoutingPolicy` column
- [ ] Flow implements each policy:
  - [ ] Notify Assigned → send to reviewer email
  - [ ] Notify All → send to group lead (Default=true)
  - [ ] Single Trader → send to named reviewer
  - [ ] Escalate On Timeout → send + wait + escalate
- [ ] Test each policy with sample check + reviewer
- [ ] Confirm popup shows correct count (e.g., "Notify 1 FO reviewer")
- [ ] Verify flow subjects include check number + transaction count
