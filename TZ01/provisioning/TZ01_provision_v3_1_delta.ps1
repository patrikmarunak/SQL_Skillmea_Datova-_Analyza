<#
  TZ01 round-3.1 delta (feature D) — transaction detail in checks.
  Adds the full SAP source columns to "TZ01 Daily Transactions" and creates the
  per-check visible-column config list "TZ01 Check Columns" (+ seed).
  Run after:  Connect-PnPOnline -Url $SiteUrl -Interactive

  NOTE (casing): FX exports "Active Status", MM exports "Active status" — SharePoint
  treats them as the same field. We provision a single "Active Status" and use it for both.
  NOTE (data): Office Scripts / the import that writes findings must populate ALL source
  columns on each row, otherwise the app's "Show all columns" shows blank cells.
#>
param([string]$SiteUrl = "https://<tenant>.sharepoint.com/sites/<TreasuryControls>")
Connect-PnPOnline -Url $SiteUrl -Interactive

# ---------------------------------------------------------------------------
# 1) TZ01 Daily Transactions — add source listing columns (display names kept,
#    internal names auto-encoded). Text is enough (the app only displays them).
# ---------------------------------------------------------------------------
$L = "TZ01 Daily Transactions"
$fx = @("Company Code","Transaction","Business Partner","Product Type","Product type name","Transaction Type","Name of Transaction Type","Buy/Sell Indicator","Value Date","Expiration Date","Traded Currency","Payment Amount in Payment Currency","Oposit Currency","Oposit Amount","Premium Currency","Premium Amount","Transaction Rate","Leading Currency","Following Currency","Contract Date","Contract.Concl.Time","Trader","Reference","Assignment","Characteristics","Internal Reference","Trading Platform ID","Hedge request","Entered On","Expire/Exercise","Active Status","Release Status","Active activity","Market spot rate")
# MM-only columns (shared ones already covered by the FX set above)
$mm = @("Company Name","Transaction category","Transaction Currency","Amount/start","Interest Rate","Interest amount","Term Start","Term End","Changed On","Activity Category","Activity Categ. Name")
foreach ($n in ($fx + $mm)) {
  if (-not (Get-PnPField -List $L -Identity $n -ErrorAction SilentlyContinue)) {
    Add-PnPField -List $L -DisplayName $n -InternalName ($n -replace "[^A-Za-z0-9]","") -Type Text -AddToDefaultView | Out-Null
    Write-Host "added column $n"
  }
}

# ---------------------------------------------------------------------------
# 2) TZ01 Check Columns — per-check visible-column config (business-editable).
# ---------------------------------------------------------------------------
$CL = "TZ01 Check Columns"
if (-not (Get-PnPList -Identity $CL -ErrorAction SilentlyContinue)) {
  New-PnPList -Title $CL -Template GenericList | Out-Null
  Add-PnPField -List $CL -DisplayName "Report"       -InternalName "Report"      -Type Choice -Choices @("FX","MM") -AddToDefaultView | Out-Null
  Add-PnPField -List $CL -DisplayName "Check Number"  -InternalName "CheckNumber" -Type Number -AddToDefaultView | Out-Null
  Add-PnPField -List $CL -DisplayName "Column Name"   -InternalName "ColumnName"  -Type Text   -AddToDefaultView | Out-Null
  Add-PnPField -List $CL -DisplayName "Order"         -InternalName "ColOrder"    -Type Number -AddToDefaultView | Out-Null
  Add-PnPField -List $CL -DisplayName "Align"         -InternalName "Align"       -Type Choice -Choices @("left","right") -AddToDefaultView | Out-Null
  Write-Host "created list $CL"
}

# Seed (per-check relevant columns, ordered). Re-running clears and reseeds.
$cfg = [ordered]@{
 "FX|1"="Transaction|Product Type|Business Partner|Payment Amount in Payment Currency|Traded Currency"
 "FX|2"="Transaction|Name of Transaction Type|Product Type|Characteristics|Payment Amount in Payment Currency|Traded Currency"
 "FX|3"="Transaction|Product Type|Business Partner|Value Date|Payment Amount in Payment Currency|Traded Currency"
 "FX|4"="Transaction|Product Type|Transaction Type|Transaction Rate|Market spot rate"
 "FX|5"="Transaction|Product Type|Entered On|Contract Date|Payment Amount in Payment Currency"
 "FX|6"="Transaction|Product Type|Value Date|Characteristics|Payment Amount in Payment Currency"
 "MM|1"="Transaction|Company Code|Business Partner|Transaction category|Amount/start"
 "MM|2"="Transaction|Product Type|Transaction Currency|Amount/start|Business Partner"
 "MM|3"="Transaction|Product Type|Company Code|Business Partner|Amount/start|Entered On"
 "MM|4"="Transaction|Product Type|Entered On|Contract Date|Amount/start"
}
$rightAlign = @("Payment Amount in Payment Currency","Amount/start","Transaction Rate","Market spot rate")
# clear any existing seed
Get-PnPListItem -List $CL -PageSize 500 | ForEach-Object { Remove-PnPListItem -List $CL -Identity $_.Id -Force | Out-Null }
foreach ($k in $cfg.Keys) {
  $parts = $k.Split("|"); $rep = $parts[0]; $num = [int]$parts[1]; $i = 0
  foreach ($col in $cfg[$k].Split("|")) {
    $i++
    $al = if ($rightAlign -contains $col) { "right" } else { "left" }
    Add-PnPListItem -List $CL -Values @{ "Report"=$rep; "CheckNumber"=$num; "ColumnName"=$col; "ColOrder"=$i; "Align"=$al } | Out-Null
  }
  Write-Host "seeded $k ($i columns)"
}
Write-Host "TZ01 v3.1 delta complete."
