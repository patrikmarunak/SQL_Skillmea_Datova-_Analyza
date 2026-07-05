#requires -Version 7.0
#requires -Modules PnP.PowerShell
<#
  TZ01 — full SharePoint provisioning + test-data seed  (PnP.PowerShell, PS 7+)
  GENERATED from the app's App.OnStart collections — the seed below is exactly the
  test data the canvas app currently holds offline. Re-generate with
  TZ01/provisioning/gen_provision.py after changing the seed.

  Creates the 9 TZ01 lists (proposal ch. 14) with friendly display names +
  compact internal names, so the app's production ClearCollect/RenameColumns
  (see App.OnStart 'PRODUCTION SWAP' block) binds without changes, and seeds
  every list with the current collection data in dependency order (real
  SharePoint IDs are captured and wired into child FK columns).

  USAGE
    pwsh> Install-Module PnP.PowerShell -Scope CurrentUser        # once
    pwsh> ./TZ01_provision_full.ps1 -SiteUrl https://<tenant>.sharepoint.com/sites/<TZ01> [-Reseed]
    Interactive sign-in by default. For app-only (unattended) pass -ClientId <appId>
    and register PnP (Register-PnPEntraIDAppForInteractiveLogin) beforehand.

    -Reseed        delete existing items in each list before seeding (columns kept)
    -SkipPeople    do not attempt to resolve the Reviewer person column (text email only)
#>
param(
  [Parameter(Mandatory)][string]$SiteUrl,
  [string]$ClientId,
  [switch]$Reseed,
  [switch]$SkipPeople
)
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

if ($ClientId) { Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId }
else           { Connect-PnPOnline -Url $SiteUrl -Interactive }
Write-Information "Connected to $SiteUrl"

# --------------------------------------------------------------------------
# helpers (idempotent)
# --------------------------------------------------------------------------
function Ensure-List([string]$Title){
  $l = Get-PnPList -Identity $Title -ErrorAction SilentlyContinue
  if (-not $l){ $l = New-PnPList -Title $Title -Template GenericList -EnableVersioning; Write-Information "list + $Title" }
  return $l
}
function Ensure-Field($List,$Display,$Internal,$Type,$Choices){
  if (Get-PnPField -List $List -Identity $Internal -ErrorAction SilentlyContinue){ return }
  if ($Type -eq 'Choice'){
    Add-PnPField -List $List -DisplayName $Display -InternalName $Internal -Type Choice -Choices $Choices -AddToDefaultView | Out-Null
  } else {
    Add-PnPField -List $List -DisplayName $Display -InternalName $Internal -Type $Type -AddToDefaultView | Out-Null
  }
  Write-Information "  field + $Display ($Internal/$Type)"
}
function Clear-List($List){
  if ($Reseed){
    Get-PnPListItem -List $List -PageSize 500 | ForEach-Object { Remove-PnPListItem -List $List -Identity $_.Id -Force | Out-Null }
    Write-Information "  cleared items in $List"
  }
}
function Add-TzItem($List,[hashtable]$Values){ return (Add-PnPListItem -List $List -Values $Values).Id }

# --------------------------------------------------------------------------
# 1) lists + columns
# --------------------------------------------------------------------------
$di = Ensure-List 'TZ01 Daily Item'
Ensure-Field $di 'DayKey' 'DayKey' 'Text' $null
Ensure-Field $di 'ItemDate' 'ItemDate' 'DateTime' $null
Ensure-Field $di 'Status' 'Status' 'Choice' @('To be processed','In review','Completed')
Ensure-Field $di 'Reviewer' 'Reviewer' 'Text' $null
Ensure-Field $di 'FXFindings' 'FXFindings' 'Number' $null
Ensure-Field $di 'MMFindings' 'MMFindings' 'Number' $null
Ensure-Field $di 'SubmittedOn' 'SubmittedOn' 'DateTime' $null
Ensure-Field $di 'ReviewLog' 'ReviewLog' 'Note' $null

$dr = Ensure-List 'TZ01 Daily Reports'
Ensure-Field $dr 'DailyItemID' 'DailyItemID' 'Number' $null
Ensure-Field $dr 'DayKey' 'DayKey' 'Text' $null
Ensure-Field $dr 'ReportType' 'ReportType' 'Choice' @('FX','MM')
Ensure-Field $dr 'ReportKey' 'ReportKey' 'Text' $null
Ensure-Field $dr 'ReportDate' 'ReportDate' 'DateTime' $null
Ensure-Field $dr 'Status' 'Status' 'Choice' @('In review','Completed')
Ensure-Field $dr 'Reviewer' 'Reviewer' 'Text' $null
Ensure-Field $dr 'ReviewLog' 'ReviewLog' 'Note' $null
Ensure-Field $dr 'Submitted' 'Submitted' 'Boolean' $null

$ck = Ensure-List 'TZ01 Daily Report Checks'
Ensure-Field $ck 'CheckKey' 'CheckKey' 'Text' $null
Ensure-Field $ck 'ReportKey' 'ReportKey' 'Text' $null
Ensure-Field $ck 'DailyReportID' 'DailyReportID' 'Number' $null
Ensure-Field $ck 'DayKey' 'DayKey' 'Text' $null
Ensure-Field $ck 'Report Type' 'ReportType' 'Choice' @('FX','MM')
Ensure-Field $ck 'Check Number' 'CheckNumber' 'Number' $null
Ensure-Field $ck 'Check Name' 'CheckName' 'Text' $null
Ensure-Field $ck 'Scope' 'Scope' 'Text' $null
Ensure-Field $ck 'Result' 'Result' 'Choice' @('No finding','Finding','Not compared','Late','Exceptional')
Ensure-Field $ck 'Findings Count' 'FindingsCount' 'Number' $null
Ensure-Field $ck 'FO Flagged Count' 'FOFlaggedCount' 'Number' $null
Ensure-Field $ck 'Not Compared' 'NotCompared' 'Boolean' $null
Ensure-Field $ck 'Is Late' 'IsLate' 'Boolean' $null
Ensure-Field $ck 'Completed' 'Completed' 'Boolean' $null
Ensure-Field $ck 'Completed On' 'CompletedOn' 'DateTime' $null

$tx = Ensure-List 'TZ01 Daily Transactions'
Ensure-Field $tx 'TxnKey' 'TxnKey' 'Text' $null
Ensure-Field $tx 'Day Key' 'DayKey' 'Text' $null
Ensure-Field $tx 'DailyItemID' 'DailyItemID' 'Number' $null
Ensure-Field $tx 'DailyReportID' 'DailyReportID' 'Number' $null
Ensure-Field $tx 'DailyReportCheckID' 'DailyReportCheckID' 'Number' $null
Ensure-Field $tx 'Report Type' 'ReportType' 'Choice' @('FX','MM')
Ensure-Field $tx 'Check Number' 'CheckNumber' 'Number' $null
Ensure-Field $tx 'TransactionNo' 'TransactionNo' 'Text' $null
Ensure-Field $tx 'Product Type (wf)' 'ProductTypeWf' 'Text' $null
Ensure-Field $tx 'Txn Type Name' 'TxnTypeName' 'Text' $null
Ensure-Field $tx 'Amount' 'Amount' 'Number' $null
Ensure-Field $tx 'Currency' 'Currency' 'Text' $null
Ensure-Field $tx 'MO Reason' 'MOReason' 'Text' $null
Ensure-Field $tx 'MO Comment' 'MOComment' 'Note' $null
Ensure-Field $tx 'Flagged To FO' 'FlaggedToFO' 'Boolean' $null
Ensure-Field $tx 'FO Reviewer' 'FOReviewer' 'Text' $null
Ensure-Field $tx 'FO Sent' 'FOSent' 'Boolean' $null
Ensure-Field $tx 'FO Sent On' 'FOSentOn' 'DateTime' $null
Ensure-Field $tx 'FO Reason' 'FOReason' 'Text' $null
Ensure-Field $tx 'FO Comment' 'FOComment' 'Note' $null
Ensure-Field $tx 'FO Responded On' 'FORespondedOn' 'DateTime' $null
Ensure-Field $tx 'FO Responded' 'FOResponded' 'Boolean' $null
Ensure-Field $tx 'Status (legacy)' 'Status' 'Text' $null
Ensure-Field $tx 'Is Late' 'IsLate' 'Boolean' $null
Ensure-Field $tx 'Days Late' 'DaysLate' 'Number' $null
Ensure-Field $tx 'Company Code' 'CompanyCode' 'Text' $null
Ensure-Field $tx 'Transaction' 'Transaction' 'Text' $null
Ensure-Field $tx 'Business Partner' 'BusinessPartner' 'Text' $null
Ensure-Field $tx 'Product Type' 'ProductType' 'Text' $null
Ensure-Field $tx 'Product type name' 'Producttypename' 'Text' $null
Ensure-Field $tx 'Transaction Type' 'TransactionType' 'Text' $null
Ensure-Field $tx 'Name of Transaction Type' 'NameofTransactionType' 'Text' $null
Ensure-Field $tx 'Buy/Sell Indicator' 'BuySellIndicator' 'Text' $null
Ensure-Field $tx 'Value Date' 'ValueDate' 'Text' $null
Ensure-Field $tx 'Expiration Date' 'ExpirationDate' 'Text' $null
Ensure-Field $tx 'Traded Currency' 'TradedCurrency' 'Text' $null
Ensure-Field $tx 'Payment Amount in Payment Currency' 'PaymentAmountinPaymentCurrency' 'Text' $null
Ensure-Field $tx 'Oposit Currency' 'OpositCurrency' 'Text' $null
Ensure-Field $tx 'Oposit Amount' 'OpositAmount' 'Text' $null
Ensure-Field $tx 'Premium Currency' 'PremiumCurrency' 'Text' $null
Ensure-Field $tx 'Premium Amount' 'PremiumAmount' 'Text' $null
Ensure-Field $tx 'Transaction Rate' 'TransactionRate' 'Text' $null
Ensure-Field $tx 'Leading Currency' 'LeadingCurrency' 'Text' $null
Ensure-Field $tx 'Following Currency' 'FollowingCurrency' 'Text' $null
Ensure-Field $tx 'Contract Date' 'ContractDate' 'Text' $null
Ensure-Field $tx 'Contract.Concl.Time' 'ContractConclTime' 'Text' $null
Ensure-Field $tx 'Trader' 'Trader' 'Text' $null
Ensure-Field $tx 'Reference' 'Reference' 'Text' $null
Ensure-Field $tx 'Assignment' 'Assignment' 'Text' $null
Ensure-Field $tx 'Characteristics' 'Characteristics' 'Text' $null
Ensure-Field $tx 'Internal Reference' 'InternalReference' 'Text' $null
Ensure-Field $tx 'Trading Platform ID' 'TradingPlatformID' 'Text' $null
Ensure-Field $tx 'Hedge request' 'Hedgerequest' 'Text' $null
Ensure-Field $tx 'Entered On' 'EnteredOn' 'Text' $null
Ensure-Field $tx 'Expire/Exercise' 'ExpireExercise' 'Text' $null
Ensure-Field $tx 'Active Status' 'ActiveStatus' 'Text' $null
Ensure-Field $tx 'Release Status' 'ReleaseStatus' 'Text' $null
Ensure-Field $tx 'Active activity' 'Activeactivity' 'Text' $null
Ensure-Field $tx 'Market spot rate' 'Marketspotrate' 'Text' $null
Ensure-Field $tx 'Company Name' 'CompanyName' 'Text' $null
Ensure-Field $tx 'Transaction category' 'Transactioncategory' 'Text' $null
Ensure-Field $tx 'Transaction Currency' 'TransactionCurrency' 'Text' $null
Ensure-Field $tx 'Amount/start' 'Amountstart' 'Text' $null
Ensure-Field $tx 'Interest Rate' 'InterestRate' 'Text' $null
Ensure-Field $tx 'Interest amount' 'Interestamount' 'Text' $null
Ensure-Field $tx 'Term Start' 'TermStart' 'Text' $null
Ensure-Field $tx 'Term End' 'TermEnd' 'Text' $null
Ensure-Field $tx 'Changed On' 'ChangedOn' 'Text' $null
Ensure-Field $tx 'Activity Category' 'ActivityCategory' 'Text' $null
Ensure-Field $tx 'Activity Categ. Name' 'ActivityCategName' 'Text' $null

$rc = Ensure-List 'TZ01 Reason Config'
Ensure-Field $rc 'Report Type' 'ReportType' 'Choice' @('FX','MM','Both')
Ensure-Field $rc 'Check Number' 'CheckNumber' 'Number' $null
Ensure-Field $rc 'Role' 'Role' 'Choice' @('MO','FO')
Ensure-Field $rc 'Auto' 'Auto' 'Boolean' $null
Ensure-Field $rc 'Auto Flag FO' 'AutoFlagFO' 'Boolean' $null
Ensure-Field $rc 'Requires Comment' 'RequiresComment' 'Boolean' $null
Ensure-Field $rc 'Order' 'Order' 'Number' $null
Ensure-Field $rc 'Active' 'Active' 'Boolean' $null

$rv = Ensure-List 'TZ01 Reviewers'
Ensure-Field $rv 'Reviewer' 'Reviewer' 'User' $null
Ensure-Field $rv 'Email' 'Email' 'Text' $null
Ensure-Field $rv 'Name' 'Name' 'Text' $null
Ensure-Field $rv 'Group' 'Group' 'Choice' @('MO','FO','ADMIN')
Ensure-Field $rv 'Report Type' 'ReportType' 'Text' $null
Ensure-Field $rv 'Check Number' 'CheckNumber' 'Number' $null
Ensure-Field $rv 'Default' 'IsDefault' 'Boolean' $null
Ensure-Field $rv 'Active' 'Active' 'Boolean' $null

$cc = Ensure-List 'TZ01 Check Columns'
Ensure-Field $cc 'Report' 'Report' 'Choice' @('FX','MM')
Ensure-Field $cc 'Check Number' 'CheckNumber' 'Number' $null
Ensure-Field $cc 'Column Name' 'ColumnName' 'Text' $null
Ensure-Field $cc 'Order' 'Order' 'Number' $null
Ensure-Field $cc 'Align' 'Align' 'Choice' @('left','right')

$tr = Ensure-List 'TZ01 Top Report'
Ensure-Field $tr 'MonthKey' 'MonthKey' 'Text' $null
Ensure-Field $tr 'DayKey' 'DayKey' 'Text' $null
Ensure-Field $tr 'ReportType' 'ReportType' 'Choice' @('FX','MM')
Ensure-Field $tr 'TransactionNo' 'TransactionNo' 'Text' $null
Ensure-Field $tr 'ProductType' 'ProductType' 'Text' $null
Ensure-Field $tr 'EnteredOn' 'EnteredOn' 'DateTime' $null
Ensure-Field $tr 'ContractDate' 'ContractDate' 'DateTime' $null
Ensure-Field $tr 'DaysLate' 'DaysLate' 'Number' $null
Ensure-Field $tr 'Amount' 'Amount' 'Number' $null
Ensure-Field $tr 'Reason' 'Reason' 'Text' $null
Ensure-Field $tr 'SourceTxnID' 'SourceTxnID' 'Number' $null

$inf = Ensure-List 'TZ01 Input Files'
Ensure-Field $inf 'DayKey' 'DayKey' 'Text' $null
Ensure-Field $inf 'FileKind' 'FileKind' 'Choice' @('FX Listing','MM Listing','ZTRM Export','US Bank Report','Other')
Ensure-Field $inf 'ReportType' 'ReportType' 'Text' $null
Ensure-Field $inf 'FileName' 'FileName' 'Text' $null
Ensure-Field $inf 'ReceivedOn' 'ReceivedOn' 'DateTime' $null
Ensure-Field $inf 'Source' 'Source' 'Text' $null
Ensure-Field $inf 'Validated' 'Validated' 'Boolean' $null

# --------------------------------------------------------------------------
# 2) seed (dependency order; real IDs captured for child FK columns)
# --------------------------------------------------------------------------
Clear-List $di
Clear-List $dr
Clear-List $ck
Clear-List $tx
Clear-List $rc
Clear-List $rv
Clear-List $cc
Clear-List $tr
Clear-List $inf

# --- TZ01 Daily Item (1 row) ---
$itemValues = @{
  Title = 'TZ01 2026-02-16'
  DayKey = '2026-02-16'
  ItemDate = (Get-Date -Year 2026 -Month 2 -Day 16)
  Status = 'In review'
  Reviewer = 'martina.medvedova@mdlz.com'
  FXFindings = 8
  MMFindings = 3
  ReviewLog = 'FO query sent for CH06 DTCC deal by MO | Automatic validation: FX 6 findings, MM 4 findings'
}
$itemId = Add-TzItem $di $itemValues
Write-Information "seeded Daily Item -> ID $itemId"

# --- TZ01 Daily Reports (2) ---
$reportId = @{}
$v = @{
  DailyItemID = $itemId
  Title = '2026-02-16|FX'
  DayKey = '2026-02-16'
  ReportType = 'FX'
  ReportKey = '2026-02-16|FX'
  ReportDate = (Get-Date -Year 2026 -Month 2 -Day 16)
  Status = 'In review'
  Submitted = $false
  ReviewLog = 'Automatic validation 2026-02-16T08:31Z: 8 findings'
}
$reportId['FX'] = Add-TzItem $dr $v
$v = @{
  DailyItemID = $itemId
  Title = '2026-02-16|MM'
  DayKey = '2026-02-16'
  ReportType = 'MM'
  ReportKey = '2026-02-16|MM'
  ReportDate = (Get-Date -Year 2026 -Month 2 -Day 16)
  Status = 'In review'
  Submitted = $false
  ReviewLog = 'Automatic validation 2026-02-16T08:31Z: 3 findings'
}
$reportId['MM'] = Add-TzItem $dr $v
Write-Information "seeded Daily Reports"

# --- TZ01 Daily Report Checks (10) ---
$checkId = @{}
$v = @{
  Title = 'Internal deals net to zero'
  CheckKey = '2026-02-16|FX|1'
  ReportKey = '2026-02-16|FX'
  DailyReportID = $reportId['FX']
  DayKey = '2026-02-16'
  ReportType = 'FX'
  CheckNumber = 1
  CheckName = 'Internal deals net to zero'
  Scope = 'Internal deals net to zero'
  Result = 'No finding'
  FindingsCount = 0
  FOFlaggedCount = 0
  NotCompared = $false
  IsLate = $false
  Completed = $true
}
$checkId['FX|1'] = Add-TzItem $ck $v
$v = @{
  Title = 'CH06 pairwise offset'
  CheckKey = '2026-02-16|FX|2'
  ReportKey = '2026-02-16|FX'
  DailyReportID = $reportId['FX']
  DayKey = '2026-02-16'
  ReportType = 'FX'
  CheckNumber = 2
  CheckName = 'CH06 pairwise offset'
  Scope = 'CH06 pairwise offset'
  Result = 'Finding'
  FindingsCount = 2
  FOFlaggedCount = 2
  NotCompared = $false
  IsLate = $false
  Completed = $false
}
$checkId['FX|2'] = Add-TzItem $ck $v
$v = @{
  Title = 'DTCC transactions'
  CheckKey = '2026-02-16|FX|3'
  ReportKey = '2026-02-16|FX'
  DailyReportID = $reportId['FX']
  DayKey = '2026-02-16'
  ReportType = 'FX'
  CheckNumber = 3
  CheckName = 'DTCC transactions'
  Scope = 'DTCC transactions'
  Result = 'Not compared'
  FindingsCount = 0
  FOFlaggedCount = 0
  NotCompared = $true
  IsLate = $false
  Completed = $false
}
$checkId['FX|3'] = Add-TzItem $ck $v
$v = @{
  Title = 'Spot vs transaction rate'
  CheckKey = '2026-02-16|FX|4'
  ReportKey = '2026-02-16|FX'
  DailyReportID = $reportId['FX']
  DayKey = '2026-02-16'
  ReportType = 'FX'
  CheckNumber = 4
  CheckName = 'Spot vs transaction rate'
  Scope = 'Spot vs transaction rate ±5%'
  Result = 'Finding'
  FindingsCount = 2
  FOFlaggedCount = 2
  NotCompared = $false
  IsLate = $false
  Completed = $false
}
$checkId['FX|4'] = Add-TzItem $ck $v
$v = @{
  Title = 'Late entry'
  CheckKey = '2026-02-16|FX|5'
  ReportKey = '2026-02-16|FX'
  DailyReportID = $reportId['FX']
  DayKey = '2026-02-16'
  ReportType = 'FX'
  CheckNumber = 5
  CheckName = 'Late entry'
  Scope = 'Late entry → TOP report'
  Result = 'Late'
  FindingsCount = 1
  FOFlaggedCount = 1
  NotCompared = $false
  IsLate = $true
  Completed = $false
}
$checkId['FX|5'] = Add-TzItem $ck $v
$v = @{
  Title = 'Hedging'
  CheckKey = '2026-02-16|FX|6'
  ReportKey = '2026-02-16|FX'
  DailyReportID = $reportId['FX']
  DayKey = '2026-02-16'
  ReportType = 'FX'
  CheckNumber = 6
  CheckName = 'Hedging'
  Scope = 'Hedging (exceptional → VITUS)'
  Result = 'Exceptional'
  FindingsCount = 1
  FOFlaggedCount = 1
  NotCompared = $false
  IsLate = $false
  Completed = $false
}
$checkId['FX|6'] = Add-TzItem $ck $v
$v = @{
  Title = '55A intercompany legs'
  CheckKey = '2026-02-16|MM|1'
  ReportKey = '2026-02-16|MM'
  DailyReportID = $reportId['MM']
  DayKey = '2026-02-16'
  ReportType = 'MM'
  CheckNumber = 1
  CheckName = '55A intercompany legs'
  Scope = '55A intercompany both legs'
  Result = 'Finding'
  FindingsCount = 1
  FOFlaggedCount = 1
  NotCompared = $false
  IsLate = $false
  Completed = $false
}
$checkId['MM|1'] = Add-TzItem $ck $v
$v = @{
  Title = '53A commercial paper'
  CheckKey = '2026-02-16|MM|2'
  ReportKey = '2026-02-16|MM'
  DailyReportID = $reportId['MM']
  DayKey = '2026-02-16'
  ReportType = 'MM'
  CheckNumber = 2
  CheckName = '53A commercial paper'
  Scope = '53A commercial paper sum'
  Result = 'Finding'
  FindingsCount = 1
  FOFlaggedCount = 1
  NotCompared = $false
  IsLate = $false
  Completed = $false
}
$checkId['MM|2'] = Add-TzItem $ck $v
$v = @{
  Title = 'No 56A/56B/56C'
  CheckKey = '2026-02-16|MM|3'
  ReportKey = '2026-02-16|MM'
  DailyReportID = $reportId['MM']
  DayKey = '2026-02-16'
  ReportType = 'MM'
  CheckNumber = 3
  CheckName = 'No 56A/56B/56C'
  Scope = 'No transaction under 56A/56B/56C'
  Result = 'No finding'
  FindingsCount = 0
  FOFlaggedCount = 0
  NotCompared = $false
  IsLate = $false
  Completed = $true
}
$checkId['MM|3'] = Add-TzItem $ck $v
$v = @{
  Title = 'Late entry (56D)'
  CheckKey = '2026-02-16|MM|4'
  ReportKey = '2026-02-16|MM'
  DailyReportID = $reportId['MM']
  DayKey = '2026-02-16'
  ReportType = 'MM'
  CheckNumber = 4
  CheckName = 'Late entry (56D)'
  Scope = 'Late entry (56D → Credit line)'
  Result = 'Late'
  FindingsCount = 2
  FOFlaggedCount = 2
  NotCompared = $false
  IsLate = $true
  Completed = $false
}
$checkId['MM|4'] = Add-TzItem $ck $v
Write-Information "seeded Daily Report Checks"

# --- TZ01 Daily Transactions (11: findings + full source record) ---
$txnId = @{}
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['FX']
  DailyReportCheckID = $checkId['FX|2']
  TxnKey = 'FX|CH061000000070312'
  ReportType = 'FX'
  CheckNumber = 2
  TransactionNo = 'CH061000000070312'
  ProductTypeWf = '60B'
  TxnTypeName = 'Forward-liquidity'
  Amount = -1000000
  Currency = 'EUR'
  MOReason = ''
  MOComment = ''
  FlaggedToFO = $false
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting MO review'
  IsLate = $false
  DaysLate = 0
  FOSent = $false
  FOReviewer = ''
  CompanyCode = 'CH06'
  Transaction = 'CH061000000070312'
  BusinessPartner = 'I_US10'
  ProductType = '60B'
  Producttypename = 'FX Forward'
  TransactionType = '102'
  NameofTransactionType = 'Forward-liquidity'
  BuySellIndicator = 'Buy'
  ValueDate = '16 Mar 2026'
  ExpirationDate = '—'
  TradedCurrency = 'EUR'
  PaymentAmountinPaymentCurrency = '-1 000 000'
  OpositCurrency = 'USD'
  OpositAmount = '0'
  PremiumCurrency = '—'
  PremiumAmount = '—'
  TransactionRate = '1.0850'
  LeadingCurrency = 'EUR'
  FollowingCurrency = 'USD'
  ContractDate = '16 Feb 2026'
  ContractConclTime = '10:24'
  Trader = 'M. Novak'
  Reference = '—'
  Assignment = '—'
  Characteristics = 'Standard'
  InternalReference = '—'
  TradingPlatformID = '360T'
  Hedgerequest = '—'
  EnteredOn = '16 Feb 2026'
  ExpireExercise = '—'
  ActiveStatus = 'Active'
  ReleaseStatus = 'Released'
  Activeactivity = 'Contract'
  Marketspotrate = '1.0850'
}
$txnId['CH061000000070312'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['FX']
  DailyReportCheckID = $checkId['FX|2']
  TxnKey = 'FX|CH061000000070318'
  ReportType = 'FX'
  CheckNumber = 2
  TransactionNo = 'CH061000000070318'
  ProductTypeWf = '60B'
  TxnTypeName = 'Forward-Exposure'
  Amount = -2000000
  Currency = 'EUR'
  MOReason = ''
  MOComment = ''
  FlaggedToFO = $false
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting MO review'
  IsLate = $false
  DaysLate = 0
  FOSent = $false
  FOReviewer = ''
  CompanyCode = 'CH06'
  Transaction = 'CH061000000070318'
  BusinessPartner = 'I_US10'
  ProductType = '60B'
  Producttypename = 'FX Forward'
  TransactionType = '102'
  NameofTransactionType = 'Forward-Exposure'
  BuySellIndicator = 'Buy'
  ValueDate = '16 Mar 2026'
  ExpirationDate = '—'
  TradedCurrency = 'EUR'
  PaymentAmountinPaymentCurrency = '-2 000 000'
  OpositCurrency = 'USD'
  OpositAmount = '0'
  PremiumCurrency = '—'
  PremiumAmount = '—'
  TransactionRate = '1.0850'
  LeadingCurrency = 'EUR'
  FollowingCurrency = 'USD'
  ContractDate = '16 Feb 2026'
  ContractConclTime = '10:24'
  Trader = 'M. Novak'
  Reference = '—'
  Assignment = '—'
  Characteristics = 'Exposure'
  InternalReference = '—'
  TradingPlatformID = '360T'
  Hedgerequest = '—'
  EnteredOn = '16 Feb 2026'
  ExpireExercise = '—'
  ActiveStatus = 'Active'
  ReleaseStatus = 'Released'
  Activeactivity = 'Contract'
  Marketspotrate = '1.0850'
}
$txnId['CH061000000070318'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['FX']
  DailyReportCheckID = $checkId['FX|4']
  TxnKey = 'FX|CH061000000091120'
  ReportType = 'FX'
  CheckNumber = 4
  TransactionNo = 'CH061000000091120'
  ProductTypeWf = '60C'
  MOReason = 'Hedge rate'
  MOComment = ''
  FlaggedToFO = $false
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting MO review'
  IsLate = $false
  DaysLate = 0
  FOSent = $false
  FOReviewer = ''
  CompanyCode = 'CH06'
  Transaction = 'CH061000000091120'
  BusinessPartner = '—'
  ProductType = '60C'
  Producttypename = 'FX Forward'
  TransactionType = '102'
  NameofTransactionType = 'Forward'
  BuySellIndicator = 'Buy'
  ValueDate = '16 Mar 2026'
  ExpirationDate = '—'
  TradedCurrency = 'USD'
  PaymentAmountinPaymentCurrency = '0'
  OpositCurrency = 'USD'
  OpositAmount = '0'
  PremiumCurrency = '—'
  PremiumAmount = '—'
  TransactionRate = '1.1840'
  LeadingCurrency = 'EUR'
  FollowingCurrency = 'USD'
  ContractDate = '16 Feb 2026'
  ContractConclTime = '10:24'
  Trader = 'M. Novak'
  Reference = '—'
  Assignment = '—'
  Characteristics = 'Standard'
  InternalReference = '—'
  TradingPlatformID = '360T'
  Hedgerequest = '—'
  EnteredOn = '16 Feb 2026'
  ExpireExercise = '—'
  ActiveStatus = 'Active'
  ReleaseStatus = 'Released'
  Activeactivity = 'Contract'
  Marketspotrate = '1.1010'
}
$txnId['CH061000000091120'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['FX']
  DailyReportCheckID = $checkId['FX|4']
  TxnKey = 'FX|CH061000000091150'
  ReportType = 'FX'
  CheckNumber = 4
  TransactionNo = 'CH061000000091150'
  ProductTypeWf = '60A'
  MOReason = 'Other'
  MOComment = 'Rate looks off, please explain.'
  FlaggedToFO = $true
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting FO review'
  IsLate = $false
  DaysLate = 0
  FOSent = $false
  FOReviewer = 'ivan.horvat@mdlz.com'
  CompanyCode = 'CH06'
  Transaction = 'CH061000000091150'
  BusinessPartner = '—'
  ProductType = '60A'
  Producttypename = 'FX Forward'
  TransactionType = '—'
  NameofTransactionType = 'Forward'
  BuySellIndicator = 'Buy'
  ValueDate = '16 Mar 2026'
  ExpirationDate = '—'
  TradedCurrency = 'USD'
  PaymentAmountinPaymentCurrency = '0'
  OpositCurrency = 'USD'
  OpositAmount = '0'
  PremiumCurrency = '—'
  PremiumAmount = '—'
  TransactionRate = '1.0710'
  LeadingCurrency = 'EUR'
  FollowingCurrency = 'USD'
  ContractDate = '16 Feb 2026'
  ContractConclTime = '10:24'
  Trader = 'M. Novak'
  Reference = '—'
  Assignment = '—'
  Characteristics = 'Standard'
  InternalReference = '—'
  TradingPlatformID = '360T'
  Hedgerequest = '—'
  EnteredOn = '16 Feb 2026'
  ExpireExercise = '—'
  ActiveStatus = 'Active'
  ReleaseStatus = 'Released'
  Activeactivity = 'Contract'
  Marketspotrate = '0.9950'
}
$txnId['CH061000000091150'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['FX']
  DailyReportCheckID = $checkId['FX|5']
  TxnKey = 'FX|CH061000000072201'
  ReportType = 'FX'
  CheckNumber = 5
  TransactionNo = 'CH061000000072201'
  ProductTypeWf = '60B'
  Amount = 1500000
  MOReason = 'Processing error'
  MOComment = 'Entered 3 days after contract.'
  FlaggedToFO = $false
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting MO review'
  IsLate = $true
  DaysLate = 3
  FOSent = $false
  FOReviewer = ''
  CompanyCode = 'CH06'
  Transaction = 'CH061000000072201'
  BusinessPartner = '—'
  ProductType = '60B'
  Producttypename = 'FX Forward'
  TransactionType = '102'
  NameofTransactionType = 'Forward'
  BuySellIndicator = 'Buy'
  ValueDate = '16 Mar 2026'
  ExpirationDate = '—'
  TradedCurrency = 'EUR'
  PaymentAmountinPaymentCurrency = '1 500 000'
  OpositCurrency = 'USD'
  OpositAmount = '0'
  PremiumCurrency = '—'
  PremiumAmount = '—'
  TransactionRate = '1.0850'
  LeadingCurrency = 'EUR'
  FollowingCurrency = 'USD'
  ContractDate = '09 Feb 2026'
  ContractConclTime = '10:24'
  Trader = 'M. Novak'
  Reference = '—'
  Assignment = '—'
  Characteristics = 'Standard'
  InternalReference = '—'
  TradingPlatformID = '360T'
  Hedgerequest = '—'
  EnteredOn = '12 Feb 2026'
  ExpireExercise = '—'
  ActiveStatus = 'Active'
  ReleaseStatus = 'Released'
  Activeactivity = 'Contract'
  Marketspotrate = '1.0850'
}
$txnId['CH061000000072201'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['FX']
  DailyReportCheckID = $checkId['FX|6']
  TxnKey = 'FX|CH061000000088210'
  ReportType = 'FX'
  CheckNumber = 6
  TransactionNo = 'CH061000000088210'
  ProductTypeWf = '60C'
  Characteristics = 'Exceptional'
  Amount = 4200000
  MOReason = 'Request FO explanation'
  MOComment = 'Attach Vitus approval please.'
  FlaggedToFO = $true
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting FO review'
  IsLate = $false
  DaysLate = 0
  FOSent = $false
  FOReviewer = 'ana.kovac@mdlz.com'
  CompanyCode = 'CH06'
  Transaction = 'CH061000000088210'
  BusinessPartner = '—'
  ProductType = '60C'
  Producttypename = 'FX Forward'
  TransactionType = '102'
  NameofTransactionType = 'Forward'
  BuySellIndicator = 'Buy'
  ValueDate = '16 Mar 2026'
  ExpirationDate = '—'
  TradedCurrency = 'EUR'
  PaymentAmountinPaymentCurrency = '4 200 000'
  OpositCurrency = 'USD'
  OpositAmount = '0'
  PremiumCurrency = '—'
  PremiumAmount = '—'
  TransactionRate = '1.0850'
  LeadingCurrency = 'EUR'
  FollowingCurrency = 'USD'
  ContractDate = '16 Feb 2026'
  ContractConclTime = '10:24'
  Trader = 'M. Novak'
  Reference = '—'
  Assignment = '—'
  Characteristics = 'Exceptional'
  InternalReference = '—'
  TradingPlatformID = '360T'
  Hedgerequest = '—'
  EnteredOn = '16 Feb 2026'
  ExpireExercise = '—'
  ActiveStatus = 'Active'
  ReleaseStatus = 'Released'
  Activeactivity = 'Contract'
  Marketspotrate = '1.0850'
}
$txnId['CH061000000088210'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['MM']
  DailyReportCheckID = $checkId['MM|1']
  TxnKey = 'MM|MM0000000055120'
  ReportType = 'MM'
  CheckNumber = 1
  TransactionNo = 'MM0000000055120'
  Amount = 10000000
  MOReason = 'Request FO explanation'
  MOComment = 'Borrowing leg not posted — please post or confirm.'
  FlaggedToFO = $true
  FOReason = 'Technical Issue'
  FOComment = '[15 Feb 16:40 - Technical Issue] Borrowing leg will be posted today, SAP ticket raised.'
  FOResponded = $false
  Status = 'Awaiting MO review'
  IsLate = $false
  DaysLate = 0
  FOSent = $true
  FOSentOn = (Get-Date -Year 2026 -Month 2 -Day 15)
  FOReviewer = 'peter.cerny@mdlz.com'
  FORespondedOn = (Get-Date -Year 2026 -Month 2 -Day 15)
  CompanyCode = 'SA04'
  Transaction = 'MM0000000055120'
  ProductType = '55A'
  CompanyName = 'Mondelez CH'
  Transactioncategory = 'Investment'
  BusinessPartner = 'I_DE01'
  TransactionCurrency = 'EUR'
  Amountstart = '10 000 000'
  InterestRate = '3.10%'
  Interestamount = '—'
  EnteredOn = '16 Feb 2026'
  ContractDate = '16 Feb 2026'
  Trader = 'M. Novak'
  TermStart = '16 Feb 2026'
  TermEnd = '16 Mar 2026'
  ChangedOn = '—'
  ActivityCategory = '100'
  ActivityCategName = 'Contract'
  ActiveStatus = 'Active'
}
$txnId['MM0000000055120'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['MM']
  DailyReportCheckID = $checkId['MM|2']
  TxnKey = 'MM|MM0000000053088'
  ReportType = 'MM'
  CheckNumber = 2
  TransactionNo = 'MM0000000053088'
  ProductTypeWf = '53A'
  Amount = 25000000
  MOReason = 'Request FO explanation'
  MOComment = 'Check US bank report / SAP upload.'
  FlaggedToFO = $true
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting FO review'
  IsLate = $false
  DaysLate = 0
  FOSent = $true
  FOSentOn = (Get-Date -Year 2026 -Month 2 -Day 16)
  FOReviewer = 'peter.cerny@mdlz.com'
  CompanyCode = 'CH06'
  Transaction = 'MM0000000053088'
  ProductType = '53A'
  CompanyName = 'Mondelez CH'
  Transactioncategory = 'Commercial paper'
  BusinessPartner = 'DealerBk'
  TransactionCurrency = 'USD'
  Amountstart = '25 000 000'
  InterestRate = '3.10%'
  Interestamount = '—'
  EnteredOn = '16 Feb 2026'
  ContractDate = '16 Feb 2026'
  Trader = 'M. Novak'
  TermStart = '16 Feb 2026'
  TermEnd = '16 Mar 2026'
  ChangedOn = '—'
  ActivityCategory = '100'
  ActivityCategName = 'Contract'
  ActiveStatus = 'Active'
}
$txnId['MM0000000053088'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['MM']
  DailyReportCheckID = $checkId['MM|4']
  TxnKey = 'MM|MM000000056d44'
  ReportType = 'MM'
  CheckNumber = 4
  TransactionNo = 'MM000000056d44'
  ProductTypeWf = '56D'
  Amount = 8000000
  MOReason = 'Credit line'
  MOComment = ''
  FlaggedToFO = $false
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting MO review'
  IsLate = $true
  DaysLate = 3
  FOSent = $false
  FOReviewer = ''
  CompanyCode = 'CH06'
  Transaction = 'MM000000056d44'
  ProductType = '56D'
  CompanyName = 'Mondelez CH'
  Transactioncategory = 'Credit line'
  BusinessPartner = 'I_DE01'
  TransactionCurrency = 'EUR'
  Amountstart = '8 000 000'
  InterestRate = '3.10%'
  Interestamount = '—'
  EnteredOn = '14 Feb 2026'
  ContractDate = '11 Feb 2026'
  Trader = 'M. Novak'
  TermStart = '16 Feb 2026'
  TermEnd = '16 Mar 2026'
  ChangedOn = '—'
  ActivityCategory = '100'
  ActivityCategName = 'Contract'
  ActiveStatus = 'Active'
}
$txnId['MM000000056d44'] = Add-TzItem $tx $v
$v = @{
  DailyItemID = $itemId
  DailyReportID = $reportId['MM']
  DailyReportCheckID = $checkId['MM|4']
  TxnKey = 'MM|MM0000000055201'
  ReportType = 'MM'
  CheckNumber = 4
  TransactionNo = 'MM0000000055201'
  ProductTypeWf = '55A'
  Amount = 5000000
  MOReason = 'Processing error'
  MOComment = 'Entered 3 days late.'
  FlaggedToFO = $false
  FOReason = ''
  FOComment = ''
  FOResponded = $false
  Status = 'Awaiting MO review'
  IsLate = $true
  DaysLate = 3
  FOSent = $false
  FOReviewer = ''
  CompanyCode = 'CH06'
  Transaction = 'MM0000000055201'
  ProductType = '55A'
  CompanyName = 'Mondelez CH'
  Transactioncategory = 'Investment'
  BusinessPartner = 'I_DE01'
  TransactionCurrency = 'EUR'
  Amountstart = '5 000 000'
  InterestRate = '3.10%'
  Interestamount = '—'
  EnteredOn = '13 Feb 2026'
  ContractDate = '10 Feb 2026'
  Trader = 'M. Novak'
  TermStart = '16 Feb 2026'
  TermEnd = '16 Mar 2026'
  ChangedOn = '—'
  ActivityCategory = '100'
  ActivityCategName = 'Contract'
  ActiveStatus = 'Active'
}
$txnId['MM0000000055201'] = Add-TzItem $tx $v
Write-Information "seeded Daily Transactions"

# --- TZ01 Reason Config (ch. 14.7 production reasons) ---
$null = Add-TzItem $rc @{
  Title = 'Missing mirror (FO query pre-selected)'
  ReportType = 'FX'
  CheckNumber = 1
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Request FO explanation'
  ReportType = 'FX'
  CheckNumber = 1
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $true
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 1
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Exposure trade'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Netting trade'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Testing'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Write-off IHC balance'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Dividend Repatriation'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 5
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Request FO explanation'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $true
  Order = 6
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 7
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Manually resent from SAP'
  ReportType = 'FX'
  CheckNumber = 3
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Technical issue - ticket created'
  ReportType = 'FX'
  CheckNumber = 3
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Request FO explanation'
  ReportType = 'FX'
  CheckNumber = 3
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 3
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Hedge rate'
  ReportType = 'FX'
  CheckNumber = 4
  Role = 'MO'
  Auto = $true
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Display issue'
  ReportType = 'FX'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Request FO explanation'
  ReportType = 'FX'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Processing error'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Confirmation sent late by the bank'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Spot out of option'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Time zone difference'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Technical issue'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 5
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 6
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Approval attached (by MO)'
  ReportType = 'FX'
  CheckNumber = 6
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Missing approval (goes to FO)'
  ReportType = 'FX'
  CheckNumber = 6
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Request FO explanation'
  ReportType = 'FX'
  CheckNumber = 6
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 6
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Missing mirror (FO query pre-selected)'
  ReportType = 'MM'
  CheckNumber = 1
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Request FO explanation'
  ReportType = 'MM'
  CheckNumber = 1
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $true
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'MM'
  CheckNumber = 1
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Sum amount mismatch - corrected'
  ReportType = 'MM'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Sum amount mismatch (goes to FO)'
  ReportType = 'MM'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Request FO explanation'
  ReportType = 'MM'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'MM'
  CheckNumber = 2
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Request FO explanation'
  ReportType = 'MM'
  CheckNumber = 3
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $true
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'MM'
  CheckNumber = 3
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Credit line'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $true
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Processing error'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Confirmation sent late by bank'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Time zone difference'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Technical issue'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 5
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other reason'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 6
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Restricted cash'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 7
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Confirmation sent late by local Team'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 8
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Missing information (goes to FO)'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'MO'
  Auto = $false
  AutoFlagFO = $true
  RequiresComment = $false
  Order = 9
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Master Data'
  ReportType = 'FX'
  CheckNumber = 1
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Technical Issue'
  ReportType = 'FX'
  CheckNumber = 1
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 1
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Internal deal not created'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'One leg of swap not traded'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 2
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Wrong currency pair used'
  ReportType = 'FX'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Wrong transaction rate used'
  ReportType = 'FX'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Special condition driven by market'
  ReportType = 'FX'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Processing error'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Confirmation sent late by the bank'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Spot out of option'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Time zone difference'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Technical issue'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 5
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Driven by business'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 6
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 5
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 7
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Approval attached'
  ReportType = 'FX'
  CheckNumber = 6
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'FX'
  CheckNumber = 6
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Master Data'
  ReportType = 'MM'
  CheckNumber = 1
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Technical Issue'
  ReportType = 'MM'
  CheckNumber = 1
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'MM'
  CheckNumber = 1
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Additional trade booked'
  ReportType = 'MM'
  CheckNumber = 2
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Correction made'
  ReportType = 'MM'
  CheckNumber = 2
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Duplicate reversed'
  ReportType = 'MM'
  CheckNumber = 2
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'MM'
  CheckNumber = 2
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Deleted'
  ReportType = 'MM'
  CheckNumber = 3
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other'
  ReportType = 'MM'
  CheckNumber = 3
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Processing error'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 1
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Confirmation sent late by bank'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 2
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Time zone difference'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 3
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Technical issue'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 4
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Other reason'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $true
  Order = 5
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Restricted cash'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 6
  Active = $true
}
$null = Add-TzItem $rc @{
  Title = 'Confirmation sent late by local Team'
  ReportType = 'MM'
  CheckNumber = 4
  Role = 'FO'
  Auto = $false
  AutoFlagFO = $false
  RequiresComment = $false
  Order = 7
  Active = $true
}
Write-Information "seeded Reason Config (81 rows)"

# --- TZ01 Reviewers (role matrix: MO / FO / ADMIN) ---
$rvVals = @{
  Title = 'Martina Medvedova'
  Email = 'martina.medvedova@mdlz.com'
  Name = 'Martina Medvedova'
  Group = 'MO'
  ReportType = '*'
  CheckNumber = 0
  IsDefault = $true
  Active = $true
}
if (-not $SkipPeople){ try { $rvVals['Reviewer'] = 'martina.medvedova@mdlz.com' ; $null = Add-TzItem $rv $rvVals }
  catch { $rvVals.Remove('Reviewer'); $null = Add-TzItem $rv $rvVals; Write-Warning "reviewer martina.medvedova@mdlz.com not resolved as a person — seeded email text only" } }
else { $null = Add-TzItem $rv $rvVals }
$rvVals = @{
  Title = 'Ana Kovac'
  Email = 'ana.kovac@mdlz.com'
  Name = 'Ana Kovac'
  Group = 'FO'
  ReportType = 'FX'
  CheckNumber = 6
  IsDefault = $false
  Active = $true
}
if (-not $SkipPeople){ try { $rvVals['Reviewer'] = 'ana.kovac@mdlz.com' ; $null = Add-TzItem $rv $rvVals }
  catch { $rvVals.Remove('Reviewer'); $null = Add-TzItem $rv $rvVals; Write-Warning "reviewer ana.kovac@mdlz.com not resolved as a person — seeded email text only" } }
else { $null = Add-TzItem $rv $rvVals }
$rvVals = @{
  Title = 'Peter Cerny'
  Email = 'peter.cerny@mdlz.com'
  Name = 'Peter Cerny'
  Group = 'FO'
  ReportType = 'MM'
  CheckNumber = 0
  IsDefault = $true
  Active = $true
}
if (-not $SkipPeople){ try { $rvVals['Reviewer'] = 'peter.cerny@mdlz.com' ; $null = Add-TzItem $rv $rvVals }
  catch { $rvVals.Remove('Reviewer'); $null = Add-TzItem $rv $rvVals; Write-Warning "reviewer peter.cerny@mdlz.com not resolved as a person — seeded email text only" } }
else { $null = Add-TzItem $rv $rvVals }
$rvVals = @{
  Title = 'Ivan Horvat'
  Email = 'ivan.horvat@mdlz.com'
  Name = 'Ivan Horvat'
  Group = 'FO'
  ReportType = 'FX'
  CheckNumber = 4
  IsDefault = $false
  Active = $true
}
if (-not $SkipPeople){ try { $rvVals['Reviewer'] = 'ivan.horvat@mdlz.com' ; $null = Add-TzItem $rv $rvVals }
  catch { $rvVals.Remove('Reviewer'); $null = Add-TzItem $rv $rvVals; Write-Warning "reviewer ivan.horvat@mdlz.com not resolved as a person — seeded email text only" } }
else { $null = Add-TzItem $rv $rvVals }
$rvVals = @{
  Title = 'TZ01 Admin'
  Email = 'admin.tz01@mdlz.com'
  Name = 'TZ01 Admin'
  Group = 'ADMIN'
  ReportType = '*'
  CheckNumber = 0
  IsDefault = $false
  Active = $true
}
if (-not $SkipPeople){ try { $rvVals['Reviewer'] = 'admin.tz01@mdlz.com' ; $null = Add-TzItem $rv $rvVals }
  catch { $rvVals.Remove('Reviewer'); $null = Add-TzItem $rv $rvVals; Write-Warning "reviewer admin.tz01@mdlz.com not resolved as a person — seeded email text only" } }
else { $null = Add-TzItem $rv $rvVals }
Write-Information "seeded Reviewers"

# --- TZ01 Check Columns (ch. 8.3 quick-view sets) ---
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'FX'
  CheckNumber = 1
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'FX'
  CheckNumber = 1
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'FX'
  CheckNumber = 1
  ColumnName = 'Business Partner'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Product Type'
  Report = 'FX'
  CheckNumber = 1
  ColumnName = 'Product Type'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Name of Transaction Type'
  Report = 'FX'
  CheckNumber = 1
  ColumnName = 'Name of Transaction Type'
  Order = 5
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Traded Currency'
  Report = 'FX'
  CheckNumber = 1
  ColumnName = 'Traded Currency'
  Order = 6
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Payment Amount in Payment Currency'
  Report = 'FX'
  CheckNumber = 1
  ColumnName = 'Payment Amount in Payment Currency'
  Order = 7
  Align = 'right'
}
$null = Add-TzItem $cc @{
  Title = 'Trader'
  Report = 'FX'
  CheckNumber = 1
  ColumnName = 'Trader'
  Order = 8
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Business Partner'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Product Type'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Product Type'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Name of Transaction Type'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Name of Transaction Type'
  Order = 5
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Traded Currency'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Traded Currency'
  Order = 6
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Payment Amount in Payment Currency'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Payment Amount in Payment Currency'
  Order = 7
  Align = 'right'
}
$null = Add-TzItem $cc @{
  Title = 'Characteristics'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Characteristics'
  Order = 8
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Trader'
  Report = 'FX'
  CheckNumber = 2
  ColumnName = 'Trader'
  Order = 9
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'FX'
  CheckNumber = 3
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'FX'
  CheckNumber = 3
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'FX'
  CheckNumber = 3
  ColumnName = 'Business Partner'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Product Type'
  Report = 'FX'
  CheckNumber = 3
  ColumnName = 'Product Type'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Name of Transaction Type'
  Report = 'FX'
  CheckNumber = 3
  ColumnName = 'Name of Transaction Type'
  Order = 5
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'FX'
  CheckNumber = 4
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'FX'
  CheckNumber = 4
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'FX'
  CheckNumber = 4
  ColumnName = 'Business Partner'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Traded Currency'
  Report = 'FX'
  CheckNumber = 4
  ColumnName = 'Traded Currency'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Oposit Currency'
  Report = 'FX'
  CheckNumber = 4
  ColumnName = 'Oposit Currency'
  Order = 5
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Trader'
  Report = 'FX'
  CheckNumber = 4
  ColumnName = 'Trader'
  Order = 6
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction Rate'
  Report = 'FX'
  CheckNumber = 4
  ColumnName = 'Transaction Rate'
  Order = 7
  Align = 'right'
}
$null = Add-TzItem $cc @{
  Title = 'Market spot rate'
  Report = 'FX'
  CheckNumber = 4
  ColumnName = 'Market spot rate'
  Order = 8
  Align = 'right'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'FX'
  CheckNumber = 5
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'FX'
  CheckNumber = 5
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'FX'
  CheckNumber = 5
  ColumnName = 'Business Partner'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Contract Date'
  Report = 'FX'
  CheckNumber = 5
  ColumnName = 'Contract Date'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Entered On'
  Report = 'FX'
  CheckNumber = 5
  ColumnName = 'Entered On'
  Order = 5
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'FX'
  CheckNumber = 6
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'FX'
  CheckNumber = 6
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'FX'
  CheckNumber = 6
  ColumnName = 'Business Partner'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Product Type'
  Report = 'FX'
  CheckNumber = 6
  ColumnName = 'Product Type'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Name of Transaction Type'
  Report = 'FX'
  CheckNumber = 6
  ColumnName = 'Name of Transaction Type'
  Order = 5
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Trader'
  Report = 'FX'
  CheckNumber = 6
  ColumnName = 'Trader'
  Order = 6
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'MM'
  CheckNumber = 1
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'MM'
  CheckNumber = 1
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Product Type'
  Report = 'MM'
  CheckNumber = 1
  ColumnName = 'Product Type'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'MM'
  CheckNumber = 1
  ColumnName = 'Business Partner'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Trader'
  Report = 'MM'
  CheckNumber = 1
  ColumnName = 'Trader'
  Order = 5
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'MM'
  CheckNumber = 2
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'MM'
  CheckNumber = 2
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Product Type'
  Report = 'MM'
  CheckNumber = 2
  ColumnName = 'Product Type'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'MM'
  CheckNumber = 2
  ColumnName = 'Business Partner'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Amount/start'
  Report = 'MM'
  CheckNumber = 2
  ColumnName = 'Amount/start'
  Order = 5
  Align = 'right'
}
$null = Add-TzItem $cc @{
  Title = 'Entered On'
  Report = 'MM'
  CheckNumber = 2
  ColumnName = 'Entered On'
  Order = 6
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Contract Date'
  Report = 'MM'
  CheckNumber = 2
  ColumnName = 'Contract Date'
  Order = 7
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Trader'
  Report = 'MM'
  CheckNumber = 2
  ColumnName = 'Trader'
  Order = 8
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'MM'
  CheckNumber = 3
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'MM'
  CheckNumber = 3
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Product Type'
  Report = 'MM'
  CheckNumber = 3
  ColumnName = 'Product Type'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Trader'
  Report = 'MM'
  CheckNumber = 3
  ColumnName = 'Trader'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Company Code'
  Report = 'MM'
  CheckNumber = 4
  ColumnName = 'Company Code'
  Order = 1
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Transaction'
  Report = 'MM'
  CheckNumber = 4
  ColumnName = 'Transaction'
  Order = 2
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Product Type'
  Report = 'MM'
  CheckNumber = 4
  ColumnName = 'Product Type'
  Order = 3
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Business Partner'
  Report = 'MM'
  CheckNumber = 4
  ColumnName = 'Business Partner'
  Order = 4
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Entered On'
  Report = 'MM'
  CheckNumber = 4
  ColumnName = 'Entered On'
  Order = 5
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Contract Date'
  Report = 'MM'
  CheckNumber = 4
  ColumnName = 'Contract Date'
  Order = 6
  Align = 'left'
}
$null = Add-TzItem $cc @{
  Title = 'Trader'
  Report = 'MM'
  CheckNumber = 4
  ColumnName = 'Trader'
  Order = 7
  Align = 'left'
}
Write-Information "seeded Check Columns (65 rows)"

# --- TZ01 Top Report (monthly late-entry snapshot) ---
$v = @{
  Title = 'CH061000000072201'
  MonthKey = '2026-02'
  DayKey = '2026-02-16'
  ReportType = 'FX'
  TransactionNo = 'CH061000000072201'
  ProductType = '60B'
  EnteredOn = (Get-Date -Year 2026 -Month 2 -Day 12)
  ContractDate = (Get-Date -Year 2026 -Month 2 -Day 9)
  DaysLate = 3
  Amount = 1500000
  Reason = 'Late booking'
}
if ($txnId.ContainsKey('CH061000000072201')){ $v['SourceTxnID'] = $txnId['CH061000000072201'] }
$null = Add-TzItem $tr $v
$v = @{
  Title = 'MM000000056d44'
  MonthKey = '2026-02'
  DayKey = '2026-02-16'
  ReportType = 'MM'
  TransactionNo = 'MM000000056d44'
  ProductType = '56D'
  EnteredOn = (Get-Date -Year 2026 -Month 2 -Day 14)
  ContractDate = (Get-Date -Year 2026 -Month 2 -Day 11)
  DaysLate = 3
  Amount = 8000000
  Reason = 'Credit line'
}
if ($txnId.ContainsKey('MM000000056d44')){ $v['SourceTxnID'] = $txnId['MM000000056d44'] }
$null = Add-TzItem $tr $v
$v = @{
  Title = 'MM0000000055201'
  MonthKey = '2026-02'
  DayKey = '2026-02-16'
  ReportType = 'MM'
  TransactionNo = 'MM0000000055201'
  ProductType = '55A'
  EnteredOn = (Get-Date -Year 2026 -Month 2 -Day 13)
  ContractDate = (Get-Date -Year 2026 -Month 2 -Day 10)
  DaysLate = 3
  Amount = 5000000
  Reason = 'Late booking'
}
if ($txnId.ContainsKey('MM0000000055201')){ $v['SourceTxnID'] = $txnId['MM0000000055201'] }
$null = Add-TzItem $tr $v
Write-Information "seeded Top Report"

# --- TZ01 Input Files (received/uploaded metadata) ---
$null = Add-TzItem $inf @{
  Title = 'ZTRM_export_2026-02-16.htm'
  DayKey = '2026-02-16'
  FileKind = 'FX Listing'
  ReportType = 'FX'
  FileName = 'ZTRM_export_2026-02-16.htm'
  ReceivedOn = (Get-Date -Year 2026 -Month 2 -Day 16)
  Source = 'Email flow'
  Validated = $true
}
$null = Add-TzItem $inf @{
  Title = 'TM00_export_2026-02-16.htm'
  DayKey = '2026-02-16'
  FileKind = 'MM Listing'
  ReportType = 'MM'
  FileName = 'TM00_export_2026-02-16.htm'
  ReceivedOn = (Get-Date -Year 2026 -Month 2 -Day 16)
  Source = 'Email flow'
  Validated = $true
}
Write-Information "seeded Input Files"

Write-Information "TZ01 provisioning + seed complete."
Disconnect-PnPOnline
