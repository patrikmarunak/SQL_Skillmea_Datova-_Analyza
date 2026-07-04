<#
  TZ01 v4 delta — roles, production reasons, quick-view columns.
  1) "TZ01 Reviewers"     + Group choice column (MO / FO / ADMIN)  → drives app roles (TZ20 pattern)
  2) "TZ01 Reason Config" + Auto / Auto Flag FO / Requires Comment booleans (if missing)
                          + optional -Reseed: replace values with proposal ch. 14.7.1/14.7.2
  3) "TZ01 Check Columns" optional -Reseed: replace with proposal ch. 8.3 quick-view sets
  Run after:  Connect-PnPOnline -Url $SiteUrl -Interactive

  NOTE: _foDraftReason/_foDraftComment used by the FO batched send are APP-LOCAL
  collection fields only — do NOT provision them as SharePoint columns.
#>
param(
  [string]$SiteUrl = "https://<tenant>.sharepoint.com/sites/<TreasuryControls>",
  [switch]$Reseed
)
Connect-PnPOnline -Url $SiteUrl -Interactive

# ---------------------------------------------------------------------------
# 1) TZ01 Reviewers — Group column (role model: MO / FO / ADMIN)
# ---------------------------------------------------------------------------
$RV = "TZ01 Reviewers"
if (-not (Get-PnPField -List $RV -Identity "Group" -ErrorAction SilentlyContinue)) {
  Add-PnPField -List $RV -DisplayName "Group" -InternalName "Group" -Type Choice -Choices @("MO","FO","ADMIN") -AddToDefaultView | Out-Null
  Write-Host "added Reviewers.Group"
}

# ---------------------------------------------------------------------------
# 2) TZ01 Reason Config — flag columns + ch. 14.7 seed
# ---------------------------------------------------------------------------
$RC = "TZ01 Reason Config"
foreach ($f in @(
  @{n="Auto";             t="Boolean"},   # reason pre-selected by the validation scripts (FX4 Hedge rate, MM4 Credit line)
  @{n="Auto Flag FO";     t="Boolean"},   # selecting the reason flags the finding to FO
  @{n="Requires Comment"; t="Boolean"})) {
  if (-not (Get-PnPField -List $RC -Identity $f.n -ErrorAction SilentlyContinue)) {
    Add-PnPField -List $RC -DisplayName $f.n -InternalName ($f.n -replace "[^A-Za-z0-9]","") -Type $f.t -AddToDefaultView | Out-Null
    Write-Host "added ReasonConfig.$($f.n)"
  }
}

if ($Reseed) {
  Write-Host "reseeding $RC per proposal ch. 14.7 …"
  Get-PnPListItem -List $RC -PageSize 500 | ForEach-Object { Remove-PnPListItem -List $RC -Identity $_.Id -Force }
  # "REP|Check|Role|Reason|Auto|AutoFlagFO|RequiresComment"
  $rows = @(
    "FX|1|MO|Missing mirror (FO query pre-selected)|0|1|0","FX|1|MO|Request FO explanation|0|1|1","FX|1|MO|Other|0|0|1",
    "FX|2|MO|Exposure trade|0|0|0","FX|2|MO|Netting trade|0|0|0","FX|2|MO|Testing|0|0|0","FX|2|MO|Write-off IHC balance|0|0|0","FX|2|MO|Dividend Repatriation|0|0|0","FX|2|MO|Request FO explanation|0|1|1","FX|2|MO|Other|0|0|1",
    "FX|3|MO|Manually resent from SAP|0|0|0","FX|3|MO|Technical issue - ticket created|0|0|0","FX|3|MO|Request FO explanation|0|1|1","FX|3|MO|Other|0|0|1",
    "FX|4|MO|Hedge rate|1|0|0","FX|4|MO|Display issue|0|0|0","FX|4|MO|Request FO explanation|0|1|1","FX|4|MO|Other|0|0|1",
    "FX|5|MO|Processing error|0|0|0","FX|5|MO|Confirmation sent late by the bank|0|0|0","FX|5|MO|Spot out of option|0|0|0","FX|5|MO|Time zone difference|0|0|0","FX|5|MO|Technical issue|0|0|0","FX|5|MO|Other|0|0|1",
    "FX|6|MO|Approval attached (by MO)|0|0|0","FX|6|MO|Missing approval (goes to FO)|0|1|0","FX|6|MO|Request FO explanation|0|1|1","FX|6|MO|Other|0|0|1",
    "MM|1|MO|Missing mirror (FO query pre-selected)|0|1|0","MM|1|MO|Request FO explanation|0|1|1","MM|1|MO|Other|0|0|1",
    "MM|2|MO|Sum amount mismatch - corrected|0|0|0","MM|2|MO|Sum amount mismatch (goes to FO)|0|1|0","MM|2|MO|Request FO explanation|0|1|1","MM|2|MO|Other|0|0|1",
    "MM|3|MO|Request FO explanation|0|1|1","MM|3|MO|Other|0|0|1",
    "MM|4|MO|Credit line|1|0|0","MM|4|MO|Processing error|0|0|0","MM|4|MO|Confirmation sent late by bank|0|0|0","MM|4|MO|Time zone difference|0|0|0","MM|4|MO|Technical issue|0|0|0","MM|4|MO|Other reason|0|0|1","MM|4|MO|Restricted cash|0|0|0","MM|4|MO|Confirmation sent late by local Team|0|0|0","MM|4|MO|Missing information (goes to FO)|0|1|0",
    "FX|1|FO|Master Data|0|0|0","FX|1|FO|Technical Issue|0|0|0","FX|1|FO|Other|0|0|1",
    "FX|2|FO|Internal deal not created|0|0|0","FX|2|FO|One leg of swap not traded|0|0|0","FX|2|FO|Other|0|0|1",
    # FX 3: no FO reasons — "does not go to FO" (ch. 14.7.1)
    "FX|4|FO|Wrong currency pair used|0|0|0","FX|4|FO|Wrong transaction rate used|0|0|0","FX|4|FO|Special condition driven by market|0|0|0","FX|4|FO|Other|0|0|1",
    "FX|5|FO|Processing error|0|0|0","FX|5|FO|Confirmation sent late by the bank|0|0|0","FX|5|FO|Spot out of option|0|0|0","FX|5|FO|Time zone difference|0|0|0","FX|5|FO|Technical issue|0|0|0","FX|5|FO|Driven by business|0|0|0","FX|5|FO|Other|0|0|1",
    "FX|6|FO|Approval attached|0|0|0","FX|6|FO|Other|0|0|1",
    "MM|1|FO|Master Data|0|0|0","MM|1|FO|Technical Issue|0|0|0","MM|1|FO|Other|0|0|1",
    "MM|2|FO|Additional trade booked|0|0|0","MM|2|FO|Correction made|0|0|0","MM|2|FO|Duplicate reversed|0|0|0","MM|2|FO|Other|0|0|1",
    "MM|3|FO|Deleted|0|0|0","MM|3|FO|Other|0|0|1",
    "MM|4|FO|Processing error|0|0|0","MM|4|FO|Confirmation sent late by bank|0|0|0","MM|4|FO|Time zone difference|0|0|0","MM|4|FO|Technical issue|0|0|0","MM|4|FO|Other reason|0|0|1","MM|4|FO|Restricted cash|0|0|0","MM|4|FO|Confirmation sent late by local Team|0|0|0"
  )
  $sort=@{}
  foreach ($r in $rows) {
    $p=$r.Split("|"); $k="$($p[0])|$($p[1])|$($p[2])"; $sort[$k]=($sort[$k]+1)
    Add-PnPListItem -List $RC -Values @{
      Title=$p[3]; ReportType=$p[0]; CheckNumber=[int]$p[1]; Role=$p[2];
      Auto=($p[4] -eq "1"); AutoFlagFO=($p[5] -eq "1"); RequiresComment=($p[6] -eq "1");
      Order=$sort[$k]; Active=$true } | Out-Null
  }
  Write-Host "seeded $($rows.Count) reason rows"
}

# ---------------------------------------------------------------------------
# 3) TZ01 Check Columns — ch. 8.3 quick-view sets
# ---------------------------------------------------------------------------
if ($Reseed) {
  $CL = "TZ01 Check Columns"
  Write-Host "reseeding $CL per proposal ch. 8.3 …"
  Get-PnPListItem -List $CL -PageSize 500 | ForEach-Object { Remove-PnPListItem -List $CL -Identity $_.Id -Force }
  $right = @("Payment Amount in Payment Currency","Amount/start","Transaction Rate","Market spot rate")
  $sets = @{
    "FX|1"=@("Company Code","Transaction","Business Partner","Product Type","Name of Transaction Type","Traded Currency","Payment Amount in Payment Currency","Trader")
    "FX|2"=@("Company Code","Transaction","Business Partner","Product Type","Name of Transaction Type","Traded Currency","Payment Amount in Payment Currency","Characteristics","Trader")
    "FX|3"=@("Company Code","Transaction","Business Partner","Product Type","Name of Transaction Type")
    "FX|4"=@("Company Code","Transaction","Business Partner","Traded Currency","Oposit Currency","Trader","Transaction Rate","Market spot rate")
    "FX|5"=@("Company Code","Transaction","Business Partner","Contract Date","Entered On")
    "FX|6"=@("Company Code","Transaction","Business Partner","Product Type","Name of Transaction Type","Trader")
    "MM|1"=@("Company Code","Transaction","Product Type","Business Partner","Trader")
    "MM|2"=@("Company Code","Transaction","Product Type","Business Partner","Amount/start","Entered On","Contract Date","Trader")
    "MM|3"=@("Company Code","Transaction","Product Type","Trader")
    "MM|4"=@("Company Code","Transaction","Product Type","Business Partner","Entered On","Contract Date","Trader")
  }
  foreach ($k in $sets.Keys | Sort-Object) {
    $p=$k.Split("|"); $i=0
    foreach ($c in $sets[$k]) {
      $i++
      Add-PnPListItem -List $CL -Values @{
        Title=$c; Report=$p[0]; CheckNumber=[int]$p[1]; ColumnName=$c; ColOrder=$i;
        Align=$(if ($right -contains $c) {"right"} else {"left"}) } | Out-Null
    }
  }
  Write-Host "seeded quick-view columns"
}
Write-Host "TZ01 v4 delta done."
