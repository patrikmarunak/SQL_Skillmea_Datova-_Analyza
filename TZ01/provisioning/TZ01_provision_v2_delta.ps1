<#
  TZ01 v2 delta — adds the FO send/routing columns to Daily Transactions.
  Run after connecting:  Connect-PnPOnline -Url $SiteUrl -Interactive
#>
param([string]$SiteUrl = "https://<tenant>.sharepoint.com/sites/<TreasuryControls>")
Connect-PnPOnline -Url $SiteUrl -Interactive

$L = "TZ01 Daily Transactions"

if (-not (Get-PnPField -List $L -Identity "FOSent" -ErrorAction SilentlyContinue)) {
    Add-PnPField -List $L -DisplayName "FOSent" -InternalName "FOSent" -Type Boolean -AddToDefaultView | Out-Null
    Write-Host "Added FOSent"
}
if (-not (Get-PnPField -List $L -Identity "FOSentOn" -ErrorAction SilentlyContinue)) {
    Add-PnPField -List $L -DisplayName "FOSentOn" -InternalName "FOSentOn" -Type DateTime -AddToDefaultView | Out-Null
    Write-Host "Added FOSentOn"
}
if (-not (Get-PnPField -List $L -Identity "FOReviewer" -ErrorAction SilentlyContinue)) {
    # Text email; switch to -Type User if you prefer a Person column
    Add-PnPField -List $L -DisplayName "FOReviewer" -InternalName "FOReviewer" -Type Text -AddToDefaultView | Out-Null
    Write-Host "Added FOReviewer"
}

Write-Host "TZ01 v2 delta applied." -ForegroundColor Green
