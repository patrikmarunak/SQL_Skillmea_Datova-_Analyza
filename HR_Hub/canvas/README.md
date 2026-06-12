# HR Hub – Canvas aplikácia (.msapp)

Canvas verzia aplikácie HR Hub ako doplnok ku code appke v `../app/`.
Súbor **`HRHub.msapp`** je hotový balíček; adresár **`src/`** obsahuje
rozbalené zdroje v PASopa formáte (`Src/*.fx.yaml` + metadáta), z ktorých
sa balíček skladá.

## Import do Power Apps

1. https://make.powerapps.com → **Apps** → **Upload a canvas app** →
   vyberte `HRHub.msapp` (alebo v Power Apps Studiu *File → Open →
   Browse*).
2. Aplikácia po otvorení spustí `App.OnStart` (v Studiu tlačidlo
   **Run OnStart**), ktorý naplní demo kolekcie.
3. Publikujte / zdieľajte štandardne.

## Čo appka obsahuje

Rovnakých 8 obrazoviek ako code appka, slovenské UI, Teams purple
(#5B5FC7), ľavý navigačný rail na každej obrazovke:

| Obrazovka | Obsah |
|---|---|
| `scrHome` | KPI dlaždice (klikateľné), hľadanie, chips oddelení, **demo prepínač rolí** |
| `scrEmployees` | StartsWith vyhľadávanie, filtre oddelenie/stav, galéria s kartami |
| `scrEmployeeDetail` | hlavička profilu, školenia s farebnými stavmi, AuditLog história, Deaktivovať (soft-delete) |
| `scrCatalog` | katalóg školení, pridávanie len pre HR Admina (inline validácia) |
| `scrRecords` | filtre (zamestnanec, stav), manažérsky rozsah, úprava záznamu |
| `scrAddRecord` | našeptávač zamestnanca, výber školenia, auto `ExpirationDate = DateAdd(..., ValidityMonths, Months)`, plánované termíny |
| `scrMyTrainings` | záznamy prihláseného + výstražné bannery |
| `scrReports` | 3 bar-charty: školenia podľa oddelení, exspirujúce, miera súladu |

**Demo roly** – tlačidlá vpravo hore na Domov: HR Admin (Katarína
Bieliková), Manažér (Milan Urban – vidí a edituje len podriadených),
Zamestnanec (read-only, zúžené menu). V produkcii rolu určia Entra ID
skupiny voči `User().Email`.

**Demo dáta** – `App.OnStart` plní kolekcie (`colEmployees`,
`colTrainingsCatalog`, `colRecords`, `colDepartments`, `colAudit`)
podmnožinou dát z `../data/*.csv` (14 zamestnancov, 105 záznamov).
Dátumy sú relatívne k `Today()`, takže stavy Platné / Čoskoro exspiruje /
Exspirované / Naplánované sú vždy aktuálne. Mutácie zapisujú do
`colAudit`, mazanie je len soft-delete.

## Prepojenie na SharePoint

Po vytvorení listov (`../scripts/Provision-HRHubLists.ps1`):

1. V Studiu pridajte SharePoint dátové zdroje: Employees, Departments,
   Positions, TrainingsCatalog, TrainingRecords, AuditLog.
2. V `App.OnStart` nahraďte `ClearCollect(...)` bloky čítaním listov
   (napr. `ClearCollect(colEmployees, AddColumns(Employees, ...))`)
   alebo galérie prepnite priamo na listy – formuly už používajú
   delegovateľné vzory (StartsWith, rovnosť na indexovaných stĺpcoch).
3. `Collect(colAudit, ...)` zameňte za `Patch(AuditLog, Defaults(AuditLog), ...)`.

## Práca so zdrojmi

`.msapp` sa skladá/rozoberá nástrojom PASopa z repa
[microsoft/PowerApps-Tooling](https://github.com/microsoft/PowerApps-Tooling)
(`dotnet build src/PASopa`):

```bash
PASopa -pack   HRHub.msapp src   # zdroje -> msapp
PASopa -unpack HRHub.msapp src   # msapp  -> zdroje
```

Pozn.: `pac canvas pack` (CLI 2.6–2.8) na Linuxe pri SourceCode/legacy
formáte padá, preto je použitý priamo open-source PASopa. Balíček prešiel
round-trip verifikáciou (pack → unpack → zhodné formuly).
