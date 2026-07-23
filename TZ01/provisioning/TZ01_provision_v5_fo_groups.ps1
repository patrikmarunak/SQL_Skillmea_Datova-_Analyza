<#
  TZ01 v5 delta — FO Groups routing configuration
  Defines which Front Office groups/traders handle which checks (FX/MM)
  and routing rules for notifications (group-wide vs single trader).

  Run after: Connect-PnPOnline -Url $SiteUrl -Interactive

  This configures:
  1) "TZ01 FO Groups" list — FO team structure + check responsibilities
  2) Routing policy for each group (notify all vs notify assigned trader)

  Consult with Reason Config (ch. 14.7) and Check Columns (ch. 8.3)
  for the complete check-to-group mapping.
#>
param(
  [string]$SiteUrl = "https://<tenant>.sharepoint.com/sites/<TreasuryControls>",
  [switch]$Reseed
)
Connect-PnPOnline -Url $SiteUrl -Interactive

# ---------------------------------------------------------------------------
# TZ01 FO Groups — routing matrix (Report Type + Check → Notify Rule)
# ---------------------------------------------------------------------------
$FG = "TZ01 FO Groups"
if (-not (Get-PnPList -Identity $FG -ErrorAction SilentlyContinue)) {
  New-PnPList -Title $FG -Template GenericList -EnableVersioning | Out-Null
  Write-Host "created $FG"
}

# Ensure fields
foreach ($f in @(
  @{n="GroupID";        t="Text"},       # e.g. "FX|Traders", "MM|All"
  @{n="GroupName";      t="Text"},       # e.g. "FX Traders", "MM Reconciliation"
  @{n="ReportType";     t="Choice"; c=@("FX","MM")},
  @{n="CheckNumbers";   t="Text"},       # e.g. "1,2,4,5,6" or "*" for all
  @{n="RoutingPolicy";  t="Choice"; c=@("Notify All","Notify Assigned","Single Trader","Escalate On Timeout")},
  @{n="RoutingRule";    t="Note"},       # human-readable description
  @{n="TeamSize";       t="Number"},     # count of traders in this group
  @{n="Active";         t="Boolean"})) {
  if (-not (Get-PnPField -List $FG -Identity $f.n -ErrorAction SilentlyContinue)) {
    if ($f.c) {
      Add-PnPField -List $FG -DisplayName $f.n -InternalName $f.n -Type $f.t -Choices $f.c -AddToDefaultView | Out-Null
    } else {
      Add-PnPField -List $FG -DisplayName $f.n -InternalName $f.n -Type $f.t -AddToDefaultView | Out-Null
    }
    Write-Host "  added $($f.n)"
  }
}

if ($Reseed) {
  Write-Host "reseeding $FG …"
  Get-PnPListItem -List $FG -PageSize 500 | ForEach-Object { Remove-PnPListItem -List $FG -Identity $_.Id -Force }

  # FO Groups seed data
  # GroupID | GroupName | ReportType | CheckNumbers | RoutingPolicy | Description | TeamSize | Active
  $groups = @(
    @{
      Title = "FX Traders"
      GroupID = "FX|Traders"
      GroupName = "FX Traders"
      ReportType = "FX"
      CheckNumbers = "1,2,4,5,6"
      RoutingPolicy = "Notify Assigned"
      RoutingRule = "Check 6 → Ana Kovac (FX Approvals); Checks 1,2,4,5 → Ivan Horvat (FX Reconciliation). Notify assigned trader only; escalate to Group Lead if no response in 2h."
      TeamSize = 2
      Active = $true
    },
    @{
      Title = "MM Reconciliation"
      GroupID = "MM|Traders"
      GroupName = "MM Reconciliation"
      ReportType = "MM"
      CheckNumbers = "1,2,3,4"
      RoutingPolicy = "Notify All"
      RoutingRule = "All MM checks → Peter Cerny (Group Lead). Notify all MM traders; Peter triages by check and routes to specialist."
      TeamSize = 1
      Active = $true
    },
    @{
      Title = "FX Late Transactions"
      GroupID = "FX|Late"
      GroupName = "FX Late Transactions"
      ReportType = "FX"
      CheckNumbers = "5"
      RoutingPolicy = "Escalate On Timeout"
      RoutingRule = "Check 5 (Late confirmations) → Ivan Horvat (assigned); escalate to Ana Kovac (FX Lead) if no acknowledgment in 1h. High SLA: 30min turnaround."
      TeamSize = 2
      Active = $true
    },
    @{
      Title = "MM Credit Line"
      GroupID = "MM|CreditLine"
      GroupName = "MM Credit Line"
      ReportType = "MM"
      CheckNumbers = "4"
      RoutingPolicy = "Single Trader"
      RoutingRule = "Check 4 (Credit line) — specialized check → Peter Cerny always. Single point of contact; Peter delegates if needed."
      TeamSize = 1
      Active = $true
    }
  )

  foreach ($g in $groups) {
    Add-PnPListItem -List $FG -Values $g | Out-Null
  }
  Write-Host "seeded $($groups.Count) FO groups"
}

# ---------------------------------------------------------------------------
# Cross-reference: Reviewers list confirms FO assignments
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "FO Reviewers in [TZ01 Reviewers]:"
Write-Host "  - Ana Kovac (FO) → ReportType=FX, CheckNumber=6"
Write-Host "  - Peter Cerny (FO) → ReportType=MM, CheckNumber=0 (all MM)"
Write-Host "  - Ivan Horvat (FO) → ReportType=FX, CheckNumber=4 (but handles 1,2,4,5 per group rule)"
Write-Host ""
Write-Host "TZ01 v5 FO Groups done."
