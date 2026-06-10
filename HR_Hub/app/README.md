# HR Hub – aplikácia

Multi-obrazovková aplikácia na správu zamestnancov a školení (React +
TypeScript + Vite), pripravená ako základ **Power Apps code app** bežiacej
v Microsoft Teams so SharePoint listami ako backendom.

## Spustenie

```bash
npm install
npm run dev      # http://localhost:3000
npm run build    # produkčný build (tsc + vite)
```

## Obrazovky

| Cesta | Obrazovka | Prístup |
|---|---|---|
| `/` | Domov / Dashboard – KPI dlaždice, hľadanie, rýchle filtre | všetci |
| `/zamestnanci` | Zoznam zamestnancov – hľadanie, filtre, karty | admin, manažér |
| `/zamestnanci/:id` | Detail – Prehľad, Školenia, Certifikáty, História | admin, manažér |
| `/katalog` | Katalóg školení – pridanie/úprava len HR Admin | admin, manažér |
| `/zaznamy` | Záznamy školení – filtre, úprava, hromadné pridanie | admin, manažér |
| `/zaznamy/novy` | Nový záznam – combobox výber, auto-expirácia, upload PDF | admin, manažér |
| `/moje-skolenia` | Moje školenia – upozornenia, certifikáty | všetci |
| `/reporty` | Reporty – školenia podľa oddelení, súlad tímov | admin, manažér |

## Roly (demo)

Rola sa v mock režime odvodzuje z dát (v produkcii z Entra ID skupín voči
`User().Email`): HR oddelenie = **HR Admin**, zamestnanec s podriadenými =
**Manažér** (edituje len záznamy priamych podriadených), ostatní =
**Zamestnanec** (len Domov a Moje školenia). Používateľa prepnete selectom
v pravom hornom rohu.

## Architektúra dát

- `src/data/dataService.ts` – rozhranie; všetky filtre zodpovedajú
  delegovateľným SharePoint dotazom (StartsWith na FullName/EmployeeID,
  rovnosť na indexovaných stĺpcoch).
- `src/data/mockDataService.ts` – in-memory implementácia nad
  `mockData.ts` (generované z `HR_Hub/data/*.csv` skriptom
  `scripts/csv_to_mockdata.py`). Mutácie zapisujú do AuditLogu, mazanie je
  len soft-delete (`Status = Inactive`), expirácia
  `= DateAdd(CompletionDate, ValidityMonths, Months)`.
- `src/data/sharePointDataService.ts` – stub s postupom napojenia na
  reálny SharePoint cez `pac code init` / `pac code add-data-source`.

Stav záznamov sa zobrazuje ako *live* stav prepočítaný k dnešku
(`liveStatus`), takže Valid/Expiring/Expired nezastará ani bez Power
Automate flow.

## Dizajn

Teams light/dark téma (prepínač v top bare, pamätá si voľbu), primárna
farba Teams purple `#5B5FC7`, Segoe UI, stavové farby zelená/jantárová/
červená/sivá, responzívny layout (nav rail sa na mobile zúži na ikony),
loading skeletony, empty states, inline validácia, WCAG AA fokus a
kontrasty.
