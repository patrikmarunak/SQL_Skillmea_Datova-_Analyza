# HR Hub – simulované dáta pre SharePoint listy

Simulované (mock) dáta pre zdrojové tabuľky aplikácie **HR Hub** – Power Apps
code app bežiacej v Microsoft Teams so SharePoint listami na komunikačnom site
„HR Hub" ako jediným backendom.

## Štruktúra

```
HR_Hub/
├── app/                           # aplikácia HR Hub (React + TS + Vite) – pozri app/README.md
├── data/                          # CSV súbory pripravené na import
│   ├── Departments.csv            # 8 oddelení
│   ├── Positions.csv              # 20 pozícií
│   ├── Employees.csv              # 47 zamestnancov (43 Active, 4 Inactive)
│   ├── TrainingsCatalog.csv       # 16 školení (Mandatory/Optional/Certification/Safety)
│   ├── TrainingRecords.csv        # 325 záznamov školení
│   └── AuditLog.csv               # 40 audit záznamov
└── scripts/
    ├── generate_data.py           # generátor dát (Python 3, deterministický seed)
    ├── csv_to_mockdata.py         # CSV -> app/src/data/mockData.ts (mock vrstva appky)
    └── Provision-HRHubLists.ps1   # PnP.PowerShell – vytvorenie listov + import
```

## Dátový model a väzby

CSV súbory používajú **prirodzené kľúče**, ktoré provision skript pri importe
preloží na SharePoint lookup ID:

| List            | Stĺpec        | Odkazuje na                      |
|-----------------|---------------|----------------------------------|
| Employees       | Department    | Departments.DepartmentCode       |
| Employees       | Position      | Positions.PositionName           |
| Employees       | ManagerEmail  | e-mail manažéra oddelenia        |
| TrainingRecords | Employee      | Employees.EmployeeID             |
| TrainingRecords | Training      | TrainingsCatalog.TrainingName    |
| AuditLog        | EntityID      | EmployeeID alebo ID záznamu      |

V SharePointe je `Title` stĺpec premapovaný: Departments → DepartmentName,
Positions → PositionName, Employees → FullName, TrainingsCatalog →
TrainingName, AuditLog → Action.

## Logika simulovaných dát

Dáta sú generované voči referenčnému dátumu **2026-06-10** tak, aby KPI
dlaždice na dashboarde mali čo zobrazovať:

- `ExpirationDate = DateAdd(CompletionDate, ValidityMonths, Months)`;
  školenia s `ValidityMonths = 0` (napr. certifikácie Scrum, AZ-900,
  voliteľné kurzy) neexspirujú.
- Stavy TrainingRecords: **232 Valid**, **40 Expiring** (exspirácia do
  30 dní), **32 Expired**, **21 Planned** (budúci termín, bez certifikátu).
- 4 zamestnanci majú `Status = Inactive` (soft-delete scenár) a len
  historické exspirované záznamy.
- Manažérska hierarchia: každé oddelenie má manažéra (riadok v Employees aj
  v Departments.Manager); radoví zamestnanci majú v `ManagerEmail` e-mail
  svojho manažéra → funguje rola **Manager** (filter
  `Employees.ManagerEmail = User().Email`).
- `CertificateLink` odkazuje do knižnice `/sites/HRHub/Certificates/` –
  samotné PDF súbory treba nahrať zvlášť (alebo ponechať ako demo linky).
- E-maily sú na demo doméne `contoso.sk`; pre test rolí ich prepíšte na
  reálne účty z vášho tenanta (stačí upraviť `DOMAIN` v generátore).
- Stĺpce používané vo filtroch aplikácie (EmployeeID, FullName, Email,
  ManagerEmail, Status, ExpirationDate, lookupy) provision skript
  **indexuje** kvôli delegovateľným dotazom a limitu 5000 položiek.

## Ako naplniť SharePoint

### Možnosť A – PnP.PowerShell (odporúčané)

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
cd HR_Hub/scripts
./Provision-HRHubLists.ps1 -SiteUrl https://<tenant>.sharepoint.com/sites/HRHub
```

Skript vytvorí všetkých 6 listov so správnymi typmi stĺpcov, knižnicu
**Certificates**, nastaví indexy a naimportuje CSV dáta v správnom poradí
(číselníky → Employees → TrainingRecords → AuditLog). Je idempotentný –
existujúce listy preskočí a dáta importuje len do prázdnych listov.

### Možnosť B – ručný import

1. Vytvorte listy podľa schémy vyššie (lookup stĺpce až po vytvorení
   cieľových listov).
2. Importujte CSV cez *Edit in grid view* / Quick Edit v poradí:
   Departments, Positions, TrainingsCatalog, Employees, TrainingRecords,
   AuditLog.
3. Lookup hodnoty vyberte ručne podľa prirodzených kľúčov v CSV.

## Pregenerovanie dát

```bash
python3 HR_Hub/scripts/generate_data.py
```

Generátor je deterministický (seed 42). Referenčný dátum upravíte konštantou
`TODAY`, veľkosť oddelení v `DEPT_HEADCOUNT`, doménu e-mailov v `DOMAIN`.
