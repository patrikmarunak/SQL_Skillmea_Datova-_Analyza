<#
  TZ01 round-3 delta — derived-status / append / Not compared model.
  Adds FORespondedOn (Daily Transactions) and NotCompared (Daily Report Checks),
  and the "Not compared" Result choice. Run after:  Connect-PnPOnline -Url $SiteUrl -Interactive
  FOComment is made append-only (multi-line; the app appends timestamped replies).
#>
param([string]$SiteUrl = "https://<tenant>.sharepoint.com/sites/<TreasuryControls>")
Connect-PnPOnline -Url $SiteUrl -Interactive

$T = "TZ01 Daily Transactions"
if (-not (Get-PnPField -List $T -Identity "FORespondedOn" -ErrorAction SilentlyContinue)) {
    Add-PnPField -List $T -DisplayName "FORespondedOn" -InternalName "FORespondedOn" -Type DateTime -AddToDefaultView | Out-Null
    Write-Host "Added FORespondedOn"
}

$C = "TZ01 Daily Report Checks"
if (-not (Get-PnPField -List $C -Identity "NotCompared" -ErrorAction SilentlyContinue)) {
    Add-PnPField -List $C -DisplayName "NotCompared" -InternalName "NotCompared" -Type Boolean -AddToDefaultView | Out-Null
    Write-Host "Added NotCompared"
}

# Add "Not compared" to the Result choice values (No finding / Finding / Late / Exceptional / Not compared)
$resultField = Get-PnPField -List $C -Identity "Result" -ErrorAction SilentlyContinue
if ($resultField) {
    $choices = @("No finding","Finding","Late","Exceptional","Not compared")
    Set-PnPField -List $C -Identity "Result" -Values @{ Choices = $choices } | Out-Null
    Write-Host "Result choices updated"
}

Write-Host "TZ01 round-3 delta applied." -ForegroundColor Green
