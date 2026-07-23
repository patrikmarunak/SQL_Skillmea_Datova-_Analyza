<#
  Import TZ01 Reviewers from CSV template
  Usage: ./import_reviewers.ps1 -CsvPath "./REVIEWERS_TEMPLATE.csv" -SiteUrl "https://<tenant>.sharepoint.com/sites/TZ01"

  This script reads the CSV template filled by customer and populates the
  TZ01 Reviewers list in SharePoint.
#>
param(
  [Parameter(Mandatory)][string]$CsvPath,
  [Parameter(Mandatory)][string]$SiteUrl,
  [string]$ClientId
)

$ErrorActionPreference = 'Stop'

# Connect to SharePoint
if ($ClientId) { Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId }
else           { Connect-PnPOnline -Url $SiteUrl -Interactive }
Write-Information "Connected to $SiteUrl"

# Import CSV
$rows = @(Import-Csv $CsvPath)
Write-Information "Loaded $($rows.Count) rows from $CsvPath"

# Ensure list exists
$rv = Get-PnPList -Identity "TZ01 Reviewers" -ErrorAction SilentlyContinue
if (-not $rv) {
  Write-Error "TZ01 Reviewers list not found — run TZ01_provision_full.ps1 first"
}

# Clear existing items (optional; uncomment if you want to replace all)
# Get-PnPListItem -List "TZ01 Reviewers" -PageSize 500 |
#   ForEach-Object { Remove-PnPListItem -List "TZ01 Reviewers" -Identity $_.Id -Force }
# Write-Information "Cleared TZ01 Reviewers"

# Import each row
$added = 0
foreach ($row in $rows) {
  $name = $row.Name.Trim()
  if (-not $name) { continue }  # Skip empty rows

  $vals = @{
    Title = $name
    Name = $name
    Email = $row.Email.Trim()
    Group = $row.Group.Trim()
    ReportType = $row.ReportType.Trim()
    CheckNumber = [int]$row.CheckNumber
    IsDefault = ($row.IsDefault.ToUpper() -eq "TRUE")
    Active = ($row.Active.ToUpper() -eq "TRUE")
  }

  # Try to resolve person (email → SharePoint user)
  $skipPerson = $false
  try {
    $vals['Reviewer'] = $vals['Email']
    $null = Add-PnPListItem -List "TZ01 Reviewers" -Values $vals
    Write-Host "✓ Added: $name ($($vals['Group'])) — ReportType=$($vals['ReportType']), Check=$($vals['CheckNumber'])"
    $added++
  }
  catch {
    $vals.Remove('Reviewer')
    try {
      $null = Add-PnPListItem -List "TZ01 Reviewers" -Values $vals
      Write-Warning "⚠ Added: $name — email not resolved as person, stored as text only"
      $added++
    }
    catch {
      Write-Error "✗ Failed to add $name : $_"
    }
  }
}

Write-Information ""
Write-Information "Imported $added reviewer(s)"
Write-Information ""
Write-Information "Verify in SharePoint:"
Write-Information "  Get-PnPListItem -List 'TZ01 Reviewers' -PageSize 500 | Select Title, Group, ReportType, CheckNumber"
