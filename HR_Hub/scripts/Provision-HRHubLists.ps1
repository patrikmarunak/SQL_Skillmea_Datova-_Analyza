<#
.SYNOPSIS
    Vytvorí SharePoint listy pre aplikáciu HR Hub a naplní ich simulovanými
    dátami z CSV súborov v ../data/.

.DESCRIPTION
    Skript pomocou PnP.PowerShell:
      1. vytvorí listy Departments, Positions, Employees, TrainingsCatalog,
         TrainingRecords a AuditLog so správnymi typmi stĺpcov (Text, Choice,
         Number, DateTime, Lookup, Hyperlink, Note),
      2. zaindexuje stĺpce používané vo filtroch (delegovateľné dotazy,
         limit 5000 položiek),
      3. vytvorí knižnicu dokumentov "Certificates",
      4. naimportuje CSV dáta – lookup hodnoty (DepartmentCode, PositionName,
         EmployeeID, TrainingName) preloží na ID položiek v cieľových listoch.

    Skript je idempotentný na úrovni schémy (existujúce listy/stĺpce preskočí),
    dáta importuje len do prázdnych listov.

.PARAMETER SiteUrl
    URL komunikačného situ HR Hub, napr. https://contoso.sharepoint.com/sites/HRHub

.EXAMPLE
    ./Provision-HRHubLists.ps1 -SiteUrl https://contoso.sharepoint.com/sites/HRHub

.NOTES
    Vyžaduje modul PnP.PowerShell:  Install-Module PnP.PowerShell -Scope CurrentUser
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl
)

$ErrorActionPreference = 'Stop'
$DataDir = Join-Path $PSScriptRoot '..\data'

Connect-PnPOnline -Url $SiteUrl -Interactive

function Ensure-List {
    param([string]$Title, [string]$Template = 'GenericList')
    $list = Get-PnPList -Identity $Title -ErrorAction SilentlyContinue
    if (-not $list) {
        Write-Host "Vytváram list '$Title'..."
        $list = New-PnPList -Title $Title -Template $Template -OnQuickLaunch
    }
    return $list
}

function Ensure-Field {
    param([string]$List, [string]$Name, [string]$Xml)
    $existing = Get-PnPField -List $List -Identity $Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        Add-PnPFieldFromXml -List $List -FieldXml $Xml | Out-Null
        Write-Host "  + stĺpec $List.$Name"
    }
}

function Ensure-Index {
    param([string]$List, [string]$Name)
    $field = Get-PnPField -List $List -Identity $Name
    if (-not $field.Indexed) {
        $field.Indexed = $true
        $field.Update()
        Invoke-PnPQuery
        Write-Host "  ~ index na $List.$Name"
    }
}

function Get-LookupListId {
    param([string]$Title)
    return (Get-PnPList -Identity $Title).Id
}

# ----------------------------------------------------------------- 1. schéma
Ensure-List 'Departments' | Out-Null
Ensure-Field 'Departments' 'DepartmentCode' '<Field Type="Text" DisplayName="DepartmentCode" Name="DepartmentCode" StaticName="DepartmentCode" EnforceUniqueValues="TRUE" Indexed="TRUE" />'
Ensure-Field 'Departments' 'Manager'        '<Field Type="Text" DisplayName="Manager" Name="Manager" StaticName="Manager" />'
# Title = DepartmentName
Set-PnPField -List 'Departments' -Identity 'Title' -Values @{Title = 'DepartmentName'}

Ensure-List 'Positions' | Out-Null
Ensure-Field 'Positions' 'Level' '<Field Type="Choice" DisplayName="Level" Name="Level" StaticName="Level"><CHOICES><CHOICE>Junior</CHOICE><CHOICE>Specialist</CHOICE><CHOICE>Senior</CHOICE><CHOICE>Manager</CHOICE></CHOICES></Field>'
Set-PnPField -List 'Positions' -Identity 'Title' -Values @{Title = 'PositionName'}

Ensure-List 'Employees' | Out-Null
$deptListId = Get-LookupListId 'Departments'
$posListId  = Get-LookupListId 'Positions'
Ensure-Field 'Employees' 'EmployeeID'   '<Field Type="Text" DisplayName="EmployeeID" Name="EmployeeID" StaticName="EmployeeID" EnforceUniqueValues="TRUE" Indexed="TRUE" />'
Ensure-Field 'Employees' 'Email'        '<Field Type="Text" DisplayName="Email" Name="Email" StaticName="Email" Indexed="TRUE" />'
Ensure-Field 'Employees' 'Department'   "<Field Type='Lookup' DisplayName='Department' Name='Department' StaticName='Department' List='{$deptListId}' ShowField='Title' />"
Ensure-Field 'Employees' 'Position'     "<Field Type='Lookup' DisplayName='Position' Name='Position' StaticName='Position' List='{$posListId}' ShowField='Title' />"
Ensure-Field 'Employees' 'ManagerEmail' '<Field Type="Text" DisplayName="ManagerEmail" Name="ManagerEmail" StaticName="ManagerEmail" Indexed="TRUE" />'
Ensure-Field 'Employees' 'HireDate'     '<Field Type="DateTime" DisplayName="HireDate" Name="HireDate" StaticName="HireDate" Format="DateOnly" />'
Ensure-Field 'Employees' 'Status'       '<Field Type="Choice" DisplayName="Status" Name="Status" StaticName="Status" Indexed="TRUE"><Default>Active</Default><CHOICES><CHOICE>Active</CHOICE><CHOICE>Inactive</CHOICE></CHOICES></Field>'
Ensure-Field 'Employees' 'PhotoUrl'     '<Field Type="URL" DisplayName="PhotoUrl" Name="PhotoUrl" StaticName="PhotoUrl" Format="Hyperlink" />'
Set-PnPField -List 'Employees' -Identity 'Title' -Values @{Title = 'FullName'}
Ensure-Index 'Employees' 'Title'   # StartsWith vyhľadávanie na FullName

Ensure-List 'TrainingsCatalog' | Out-Null
Ensure-Field 'TrainingsCatalog' 'TrainingType'   '<Field Type="Choice" DisplayName="TrainingType" Name="TrainingType" StaticName="TrainingType" Indexed="TRUE"><CHOICES><CHOICE>Mandatory</CHOICE><CHOICE>Optional</CHOICE><CHOICE>Certification</CHOICE><CHOICE>Safety</CHOICE></CHOICES></Field>'
Ensure-Field 'TrainingsCatalog' 'ValidityMonths' '<Field Type="Number" DisplayName="ValidityMonths" Name="ValidityMonths" StaticName="ValidityMonths" Decimals="0" Min="0" />'
Ensure-Field 'TrainingsCatalog' 'Description'    '<Field Type="Note" DisplayName="Description" Name="Description" StaticName="Description" NumLines="4" />'
Ensure-Field 'TrainingsCatalog' 'Provider'       '<Field Type="Text" DisplayName="Provider" Name="Provider" StaticName="Provider" />'
Set-PnPField -List 'TrainingsCatalog' -Identity 'Title' -Values @{Title = 'TrainingName'}

Ensure-List 'TrainingRecords' | Out-Null
$empListId   = Get-LookupListId 'Employees'
$trainListId = Get-LookupListId 'TrainingsCatalog'
Ensure-Field 'TrainingRecords' 'Employee'        "<Field Type='Lookup' DisplayName='Employee' Name='Employee' StaticName='Employee' List='{$empListId}' ShowField='Title' Indexed='TRUE' />"
Ensure-Field 'TrainingRecords' 'Training'        "<Field Type='Lookup' DisplayName='Training' Name='Training' StaticName='Training' List='{$trainListId}' ShowField='Title' Indexed='TRUE' />"
Ensure-Field 'TrainingRecords' 'CompletionDate'  '<Field Type="DateTime" DisplayName="CompletionDate" Name="CompletionDate" StaticName="CompletionDate" Format="DateOnly" />'
Ensure-Field 'TrainingRecords' 'ExpirationDate'  '<Field Type="DateTime" DisplayName="ExpirationDate" Name="ExpirationDate" StaticName="ExpirationDate" Format="DateOnly" Indexed="TRUE" />'
Ensure-Field 'TrainingRecords' 'Status'          '<Field Type="Choice" DisplayName="Status" Name="Status" StaticName="Status" Indexed="TRUE"><CHOICES><CHOICE>Valid</CHOICE><CHOICE>Expiring</CHOICE><CHOICE>Expired</CHOICE><CHOICE>Planned</CHOICE></CHOICES></Field>'
Ensure-Field 'TrainingRecords' 'CertificateLink' '<Field Type="URL" DisplayName="CertificateLink" Name="CertificateLink" StaticName="CertificateLink" Format="Hyperlink" />'
Ensure-Field 'TrainingRecords' 'Notes'           '<Field Type="Note" DisplayName="Notes" Name="Notes" StaticName="Notes" NumLines="3" />'

Ensure-List 'AuditLog' | Out-Null
Ensure-Field 'AuditLog' 'EntityType' '<Field Type="Choice" DisplayName="EntityType" Name="EntityType" StaticName="EntityType" Indexed="TRUE"><CHOICES><CHOICE>Employee</CHOICE><CHOICE>TrainingRecord</CHOICE><CHOICE>TrainingCatalog</CHOICE></CHOICES></Field>'
Ensure-Field 'AuditLog' 'EntityID'   '<Field Type="Text" DisplayName="EntityID" Name="EntityID" StaticName="EntityID" Indexed="TRUE" />'
Ensure-Field 'AuditLog' 'ChangedBy'  '<Field Type="Text" DisplayName="ChangedBy" Name="ChangedBy" StaticName="ChangedBy" Indexed="TRUE" />'
Ensure-Field 'AuditLog' 'ChangedOn'  '<Field Type="DateTime" DisplayName="ChangedOn" Name="ChangedOn" StaticName="ChangedOn" Format="DateTime" />'
Ensure-Field 'AuditLog' 'Details'    '<Field Type="Note" DisplayName="Details" Name="Details" StaticName="Details" NumLines="4" />'
Set-PnPField -List 'AuditLog' -Identity 'Title' -Values @{Title = 'Action'}

# knižnica certifikátov
Ensure-List 'Certificates' -Template 'DocumentLibrary' | Out-Null

# ----------------------------------------------------------------- 2. import
function Import-IfEmpty {
    param([string]$List, [scriptblock]$ImportBlock)
    $count = (Get-PnPList -Identity $List).ItemCount
    if ($count -gt 0) {
        Write-Host "List '$List' už obsahuje $count položiek – import preskakujem."
        return
    }
    Write-Host "Importujem dáta do '$List'..."
    & $ImportBlock
}

Import-IfEmpty 'Departments' {
    Import-Csv (Join-Path $DataDir 'Departments.csv') | ForEach-Object {
        Add-PnPListItem -List 'Departments' -Values @{
            Title = $_.DepartmentName; DepartmentCode = $_.DepartmentCode; Manager = $_.Manager
        } | Out-Null
    }
}

Import-IfEmpty 'Positions' {
    Import-Csv (Join-Path $DataDir 'Positions.csv') | ForEach-Object {
        Add-PnPListItem -List 'Positions' -Values @{ Title = $_.PositionName; Level = $_.Level } | Out-Null
    }
}

# mapy prirodzený kľúč -> ID položky pre lookup stĺpce
$deptIdByCode = @{}
Get-PnPListItem -List 'Departments' -PageSize 500 | ForEach-Object { $deptIdByCode[$_['DepartmentCode']] = $_.Id }
$posIdByName = @{}
Get-PnPListItem -List 'Positions' -PageSize 500 | ForEach-Object { $posIdByName[$_['Title']] = $_.Id }

Import-IfEmpty 'Employees' {
    Import-Csv (Join-Path $DataDir 'Employees.csv') | ForEach-Object {
        $values = @{
            Title        = $_.FullName
            EmployeeID   = $_.EmployeeID
            Email        = $_.Email
            Department   = $deptIdByCode[$_.Department]
            Position     = $posIdByName[$_.Position]
            ManagerEmail = $_.ManagerEmail
            HireDate     = [datetime]$_.HireDate
            Status       = $_.Status
            PhotoUrl     = $_.PhotoUrl
        }
        Add-PnPListItem -List 'Employees' -Values $values | Out-Null
    }
}

Import-IfEmpty 'TrainingsCatalog' {
    Import-Csv (Join-Path $DataDir 'TrainingsCatalog.csv') | ForEach-Object {
        Add-PnPListItem -List 'TrainingsCatalog' -Values @{
            Title          = $_.TrainingName
            TrainingType   = $_.TrainingType
            ValidityMonths = [int]$_.ValidityMonths
            Description    = $_.Description
            Provider       = $_.Provider
        } | Out-Null
    }
}

$empIdByCode = @{}
Get-PnPListItem -List 'Employees' -PageSize 500 | ForEach-Object { $empIdByCode[$_['EmployeeID']] = $_.Id }
$trainIdByName = @{}
Get-PnPListItem -List 'TrainingsCatalog' -PageSize 500 | ForEach-Object { $trainIdByName[$_['Title']] = $_.Id }

Import-IfEmpty 'TrainingRecords' {
    Import-Csv (Join-Path $DataDir 'TrainingRecords.csv') | ForEach-Object {
        $values = @{
            Title    = "$($_.Employee) – $($_.Training)"
            Employee = $empIdByCode[$_.Employee]
            Training = $trainIdByName[$_.Training]
            Status   = $_.Status
        }
        if ($_.CompletionDate)  { $values.CompletionDate  = [datetime]$_.CompletionDate }
        if ($_.ExpirationDate)  { $values.ExpirationDate  = [datetime]$_.ExpirationDate }
        if ($_.CertificateLink) { $values.CertificateLink = $_.CertificateLink }
        if ($_.Notes)           { $values.Notes           = $_.Notes }
        Add-PnPListItem -List 'TrainingRecords' -Values $values | Out-Null
    }
}

Import-IfEmpty 'AuditLog' {
    Import-Csv (Join-Path $DataDir 'AuditLog.csv') | ForEach-Object {
        Add-PnPListItem -List 'AuditLog' -Values @{
            Title      = $_.Action
            EntityType = $_.EntityType
            EntityID   = $_.EntityID
            ChangedBy  = $_.ChangedBy
            ChangedOn  = [datetime]$_.ChangedOn
            Details    = $_.Details
        } | Out-Null
    }
}

Write-Host "`nHotovo. Listy HR Hub sú vytvorené a naplnené simulovanými dátami."
