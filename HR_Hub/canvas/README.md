# HR Hub – Canvas aplikácia (.msapp)

Canvas verzia HR Hub. **`HRHub.msapp`** je hotový balíček, adresár **`src/`**
sú rozbalené PASopa zdroje (`Src/*.fx.yaml` + metadáta). Generuje sa skriptom
`../scripts/build_canvas.py`.

**9 obrazoviek:** Domov, Zamestnanci, Detail zamestnanca, **Nový/Upraviť
zamestnanec** (`scrEmployeeForm` – plný CRUD profilu s číselníkmi Oddelenie/
Pozícia, validáciou e-mailu a unikátnosti EmployeeID, Audit + LIVE Patch),
Katalóg školení, Záznamy školení, Pridať záznam, Moje školenia, Reporty.

**Nice-to-have:** hromadné priradenie školenia viacerým zamestnancom naraz
(multi-select combobox → `colPickedEmps`), jednoklikové **„✓ Absolvované"** na
naplánovaných záznamoch (Planned → Valid k dnešku), pole na odkaz certifikátu
v záznamoch.

## Import do Power Apps

1. https://make.powerapps.com → **Apps** → **Upload a canvas app** → `HRHub.msapp`.
2. Otvoriť na úpravu, spustiť **Run OnStart** (alebo Alt+spustiť), čím sa
   naplnia demo kolekcie.
3. Publikovať / zdieľať.

## Responzívne rozloženie (verzia 2)

Rozloženie je postavené na **auto-layout kontajneroch** namiesto absolútnych
súradníc:

- Každá obrazovka = jeden `frame` (horizontálny kontajner `Parent.Width ×
  Parent.Height`) → **navigačný rail** (pevných 220 px) + **main** (rastie,
  `FillPortions`).
- `main` = vertikálny kontajner: hlavička (`SpaceBetween`) → filtre → galéria,
  ktorá vypĺňa zvyšok (`FillPortions = 1`) a vnútorne skroluje.
- Flexbox model: kontajnery majú `LayoutGap`, `Padding*`, `LayoutAlignItems`,
  `LayoutJustifyContent`; deti `FillPortions` (rast po hlavnej osi) a
  `AlignInContainer`. KPI dlaždice a filter-chipy sa pri zúžení
  preusporiadajú / horizontálne skrolujú.
- **Document settings**: `Scale to fit = Off`, `Lock aspect ratio = Off`,
  orientácia *landscape* (1366×768). Vďaka tomu `Screen.Width/Height` sledujú
  okno a obsah reaguje na veľkosť (Teams desktop aj mobil).

> Pozn. k v1: galérie predtým padali do horizontálneho renderu, lebo im chýbala
> vlastnosť `Layout = Layout.Vertical`, a celý canvas bol nastavený ako telefón
> na výšku so `Scale to fit = On`. Oboje je v tejto verzii opravené.

## Dátový model – kolekcie + Patch/refresh

Aplikácia pracuje presne podľa tvojho zámeru:

1. **Štart** (`App.OnStart`) načíta dáta do kolekcií: `colEmployees`,
   `colDepartments`, `colTrainingsCatalog`, `colRecordsBase`, `colAudit`.
2. Z `colRecordsBase` sa dopočíta **`colRecords`** (join lookupov,
   `ExpirationDate = DateAdd(CompletionDate, ValidityMonths, Months)`,
   `LiveStatus` k dnešku). Tento prepočet je inlinovaný a opakuje sa po
   každej zmene.
3. Obrazovky **čítajú a píšu kolekcie** (rýchle, bez sieťovej latencie).
4. Pri pridaní/úprave/deaktivácii sa zmena zapíše do kolekcie **a** (v LIVE
   režime) Patchne do SharePointu; dotknutá kolekcia sa prepočíta.

V `.fx.yaml` sú LIVE riadky pripravené ako komentáre `/* LIVE: Patch(...) */`
pri každej mutácii (scrAddRecord, scrCatalog, scrEmployeeDetail).

## Napojenie na SharePoint (LIVE režim)

**Áno – listy pridaj ako dátové zdroje v Studiu.** Z tohto prostredia ich
zapojiť neviem (vyžaduje to tvoje tenant pripojenie), ale appka je na to
pripravená. Postup:

1. V Studiu **Data → Add data → SharePoint**, vyber site „HR Hub" a pridaj
   listy: `Employees`, `Departments`, `Positions`, `TrainingsCatalog`,
   `TrainingRecords`, `AuditLog`.
2. V `App.OnStart` nahraď **DEMO blok** (medzi značkami `=== DEMO ZDROJ ===`)
   načítaním z listov. Kolekcie majú zámerne rovnaké názvy stĺpcov, takže
   obrazovky netreba meniť:

   ```powerappsfx
   // číselníky
   ClearCollect(colDepartments,
       ShowColumns(AddColumns(Departments, "DepartmentName", Title),
                   "ID", "DepartmentName", "DepartmentCode", "Manager"));
   ClearCollect(colPositions,
       ShowColumns(AddColumns(Positions, "PositionName", Title, "Level", Level.Value),
                   "ID", "PositionName", "Level"));
   ClearCollect(colTrainingsCatalog,
       ShowColumns(AddColumns(TrainingsCatalog,
                       "TrainingName", Title, "TrainingType", TrainingType.Value),
                   "ID", "TrainingName", "TrainingType", "ValidityMonths", "Provider"));

   // zamestnanci – lookup/choice stĺpce cez .Value, DepartmentCode dohľadáme
   ClearCollect(colEmployees,
       ForAll(Employees As e,
           { ID: e.ID, EmployeeID: e.EmployeeID, FullName: e.Title, Email: e.Email,
             Department: e.Department.Value,
             DepartmentCode: LookUp(colDepartments, DepartmentName = e.Department.Value, DepartmentCode),
             Position: e.Position.Value, ManagerEmail: e.ManagerEmail,
             HireDate: e.HireDate, Status: e.Status.Value, PhotoUrl: e.PhotoUrl }));
   ```

3. **`colRecords`** v LIVE režime načítaj priamo s reálnymi dátumami (demo
   používa relatívny `Off`, tu máme skutočný `CompletionDate`). Tento blok daj
   namiesto inlinovaného prepočtu – a zavolaj ho aj po každej zmene záznamu:

   ```powerappsfx
   ClearCollect(colRecords,
       ForAll(TrainingRecords As r,
           With({ comp: r.CompletionDate,
                  vm: LookUp(colTrainingsCatalog, ID = r.Training.Id, ValidityMonths),
                  pl: (r.Status.Value = "Planned"),
                  emp: LookUp(colEmployees, ID = r.Employee.Id) },
               With({ exp: If(pl || vm = 0, Blank(), DateAdd(comp, vm, TimeUnit.Months)) },
                   { ID: r.ID, Emp: emp.EmployeeID, Tr: r.Training.Id,
                     EmployeeID: emp.EmployeeID, EmployeeName: emp.FullName,
                     DepartmentCode: emp.DepartmentCode, ManagerEmail: emp.ManagerEmail,
                     TrainingName: r.Training.Value, ValidityMonths: vm,
                     Pl: pl, Cert: r.CertificateLink, Notes: r.Notes,
                     CompletionDate: comp, ExpirationDate: exp,
                     LiveStatus: If(pl, "Planned",
                         IsBlank(exp), "Valid",
                         exp < Today(), "Expired",
                         exp <= DateAdd(Today(), 30, TimeUnit.Days), "Expiring", "Valid") }))));
   ```

4. Pri mutáciách **odkomentuj LIVE riadky** (`/* LIVE: ... */`) a po Patchi
   znovu načítaj dotknutú kolekciu. Vzor (pridanie záznamu):

   ```powerappsfx
   Patch(TrainingRecords, Defaults(TrainingRecords),
         { Employee: { Id: varPickedEmp.ID, Value: varPickedEmp.FullName },
           Training: { Id: varPickedTraining.ID, Value: varPickedTraining.TrainingName },
           CompletionDate: DateValue(txtDateAdd.Text),
           Status: { Value: If(chkPlanned.Value, "Planned", "Valid") } });
   Patch(AuditLog, Defaults(AuditLog),
         { Title: "Create", EntityType: { Value: "TrainingRecord" },
           EntityID: varPickedEmp.EmployeeID, ChangedBy: User().Email,
           ChangedOn: Now(), Details: "Pridaný záznam školenia…" });
   // refresh: znova načítaj colRecords (blok z kroku 3)
   ```

   `ExpirationDate` môžeš počítať v appke (ako vyššie) alebo ho nechať
   dopočítať Power Automate flowom na liste `TrainingRecords`.

### PDF certifikáty – upload priamo cez formulár (bez flow)

Jediná no-flow cesta v canvas je **Attachments control**. PDF sa uloží ako
**príloha na položku listu `TrainingRecords`** (do poľa `{Attachments}`), nie do
samostatnej knižnice „Certificates" – tá by si vyžadovala flow. Príloha na
zázname je pre certifikáty úplne postačujúca.

Attachments control sa viaže na živý SharePoint zdroj, takže sa pridáva v Studiu
(nedá sa predzabaliť bez tvojho pripojenia). Postup, ktorý sedí s našou
kolekcia+Patch architektúrou:

1. List `TrainingRecords` musí mať povolené prílohy (List settings → Advanced
   settings → Attachments = Enabled; štandardne zapnuté).
2. Pridaj `TrainingRecords` ako dátový zdroj.
3. Na obrazovku úpravy záznamu (`scrAddRecord`) vlož **Edit form** `frmRecord`:
   - `DataSource = TrainingRecords`
   - `Item = If(IsBlank(varEditRecord), Blank(), LookUp(TrainingRecords, ID = varEditRecord.ID))`
   - `DefaultMode = If(IsBlank(varEditRecord), FormMode.New, FormMode.Edit)`
4. Z formu nechaj len **Attachments DataCard** (`typedDataCard.attachmentsEditCard`,
   `DataField = "{Attachments}"`) – jej attachments control (`DataCardValue2`) je
   tá drag&drop plocha na PDF. Ostatné karty zmaž/skry.
5. Ukladanie – dve varianty:
   - **Cez form (najčistejšie):** daj na form aj karty pre Employee / Training /
     CompletionDate / Status / Notes a ulož všetko naraz cez `SubmitForm(frmRecord)`;
     v `OnSuccess` zavolaj refresh `colRecords` + `Navigate`. Príloha sa pripne na
     práve vytvorenú/upravenú položku.
   - **Tvoj Patch pattern:** nechaj na forme len attachments kartu a priloženie
     zahrň do existujúceho Patchu poľom `Attachments`:
     ```powerappsfx
     Patch(TrainingRecords,
           If(IsBlank(varEditRecord), Defaults(TrainingRecords),
              LookUp(TrainingRecords, ID = varEditRecord.ID)),
           { Employee: {Id: varPickedEmp.ID, Value: varPickedEmp.FullName},
             Training: {Id: varPickedTraining.ID, Value: varPickedTraining.TrainingName},
             CompletionDate: DateValue(txtDateAdd.Text),
             Status: {Value: If(chkPlanned.Value, "Planned", "Valid")},
             Attachments: DataCardValue2.Attachments });   // <- prílohy z attachments controlu
     ```
6. Hromadné priradenie (viacerým naraz) ostáva bez prílohy – certifikát sa
   prikladá per-záznam pri úprave; to je aj rozumnejšie UX.

Pole „odkaz na certifikát" (`CertificateLink`) v appke ponechaj ako manuálny
fallback / pre demo bez pripojeného listu.

### Delegovateľnosť

Filtre používajú `StartsWith` a rovnosť na indexovaných stĺpcoch. Keďže appka
po štarte pracuje s kolekciami v pamäti, 5000-limit sa týka len **úvodného
načítania** – `ClearCollect` natiahne max. 2000/`DataRowLimit` na stránku, preto
pri väčších listoch načítavaj po stránkach alebo filtruj už pri načítaní
(napr. len `Status = "Active"`).

## Roly (demo)

Na Domove sú tlačidlá **HR Admin / Manažér / Zamestnanec** (prepnú
`varCurrentUser` a `varRole`). V produkcii rolu urči cez Entra ID skupiny voči
`User().Email` (Office 365 Users / `AzureAD.CheckMembership`-vzor).

## Práca so zdrojmi

```bash
python3 ../scripts/build_canvas.py          # vygeneruje Src/*.fx.yaml + manifest
PASopa -pack   HRHub.msapp src               # zdroje -> msapp
PASopa -unpack HRHub.msapp src               # msapp  -> zdroje
```

PASopa = `dotnet build` z [microsoft/PowerApps-Tooling](https://github.com/microsoft/PowerApps-Tooling).
`pac canvas pack` (CLI 2.6–2.8) na Linuxe pri tomto formáte padá, preto PASopa.
Balíček prešiel round-trip verifikáciou (pack → unpack → 0 chýb).
