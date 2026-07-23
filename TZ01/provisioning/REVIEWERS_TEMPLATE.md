# TZ01 Reviewers — Šablóna na vyplnenie

Táto šablóna slúži na definovanie konkrétnych ľudí (MO/FO reviewers), ktoré bude systém TZ01 používať na schvaľovanie a routing.

## Ako vyplniť (Postup)

1. **Skopíruj si tabuľku nižšie** do Excel / Google Sheets
2. **Vyplň konkrétnych ľudí z vašej organizácie**
3. **Pošli vyplnenú tabuľku na doplnenie do TZ01**
4. Po vyplnení: spustí sa skript, ktorý automaticky naplní SharePoint list

---

## Tabuľka na vyplnenie

| Meno | Email | Rola | Typ reportu | Check | Default | Aktívny | Poznámky |
|---|---|---|---|---|---|---|---|
| Martina Medvedova | martina.medvedova@mdlz.com | **MO** | * | 0 | ✓ | ✓ | MO Default — všetky reports |
| Ana Kovac | ana.kovac@mdlz.com | **FO** | FX | 6 | | ✓ | FX Check 6 (Approvals) |
| Peter Cerny | peter.cerny@mdlz.com | **FO** | MM | 0 | ✓ | ✓ | MM Default — všetky MM checks |
| Ivan Horvat | ivan.horvat@mdlz.com | **FO** | FX | 4 | | ✓ | FX Checks 1,2,4,5 |
| **[Doplň nového člena]** | **meno@mdlz.com** | MO / FO / ADMIN | FX / MM / * | číslo | ✓ / | ✓ | textový popis |

---

## Vysvetlenie stĺpcov

### Meno
**Typ:** Text  
**Príklad:** `Jozef Varga`  
**Poznámka:** Meno v plnej forme; bude sa zobrazovať v aplikácii

### Email
**Typ:** Email adresa  
**Príklad:** `jozef.varga@mdlz.com`  
**Poznámka:** 
- Musí byť validná e-mailová adresa
- Potrebná na rozoslanie notifikácií
- Ak email neexistuje v tenante, systém ho zapíše ako text (skript s `-SkipPeople`)

### Rola (Group)
**Typ:** Voľba — vyber jeden  
**Možnosti:**

| Voľba | Účel | Popis |
|---|---|---|
| **MO** | Money Market Operations | Operátor, ktorý robí schvaľovanie (treasury team) |
| **FO** | Front Office | FO trader — berie notifikácie na schválenie |
| **ADMIN** | Admin | Správca systému — má prístup na všetko |

**Príklad:** `FO`

### Typ reportu (ReportType)
**Typ:** Voľba — vyber jeden  
**Možnosti:**

| Voľba | Použitie |
|---|---|
| **FX** | Foreign Exchange — len FX checks (1–6) |
| **MM** | Money Market — len MM checks (1–4) |
| **\*** | Všetko — FX aj MM checks |

**Príklad:** `FX` = zvláda len FX checks

**Poznámka:** 
- MO operátor zvyčajne má `*` (všetky)
- FO trader zvyčajne má `FX` alebo `MM` (špecializácia)

### Check (CheckNumber)
**Typ:** Číslo (0 = všetky checks daného typu)  
**Možnosti:**

| Číslo | Čo znamená |
|---|---|
| **0** | Všetky checks daného ReportType |
| **1–6** | Konkrétny FX check (1=Internal deals, 2=Matched, 4=Hedge rate, 5=Late, 6=Approvals) |
| **1–4** | Konkrétny MM check (1=Internal deals, 2=Amount mismatch, 3=Booked trades, 4=Credit line) |

**Príklady:**
- `CheckNumber=0, ReportType=FX` → zvláda všetky FX checks
- `CheckNumber=6, ReportType=FX` → zvláda len FX Check 6 (Approvals)
- `CheckNumber=4, ReportType=MM` → zvláda len MM Check 4 (Credit line)

### Default
**Typ:** Áno/Nie (TRUE / FALSE alebo ✓)  
**Použitie:** Ak je **CheckNumber=0** (všetky checks), nastaví sa ako default reviewer pre tento typ  
**Príklady:**
- MO: `Default=TRUE` (MO operátor dostane všetky FX+MM notifikácie)
- Peter (MM group lead): `Default=TRUE` (dostane všetky MM notifikácie; sám ich distribuuje)
- Ana (Check 6 only): `Default=FALSE` (dostane len Check 6, nie všetky)

**Pravidlo:** V jednom ReportType by malo byť iba jeden `Default=TRUE`

### Aktívny (Active)
**Typ:** Áno/Nie (TRUE / FALSE alebo ✓)  
**Použitie:** Je táto osoba aktívna? Ak NIE, nebudú jej chodiť notifikácie  
**Príklad:**
- Nový zaměstnanec → `TRUE`
- Odchádza do materskej → `FALSE` (soft delete, bez vymazania z histórie)

---

## Príklady vyplnenia

### Príklad 1: Standard (MO + 2 FX traders + 1 MM lead)

| Meno | Email | Rola | ReportType | CheckNumber | Default | Aktívny |
|---|---|---|---|---|---|---|
| Martina Medvedova | m.medvedova@company.com | MO | * | 0 | ✓ | ✓ |
| Ana Kovac | a.kovac@company.com | FO | FX | 6 | | ✓ |
| Ivan Horvat | i.horvat@company.com | FO | FX | 4 | | ✓ |
| Peter Cerny | p.cerny@company.com | FO | MM | 0 | ✓ | ✓ |

**Logika:**
- Martina (MO) dostane všetky notifikácie (Default MO)
- Ana dostane len FX Check 6 (Approvals)
- Ivan dostane FX Checks 1,2,4,5 (Reconciliation)
- Peter dostane všetky MM checks (Default MM group lead)

---

### Príklad 2: Rozšírený tím (s náhradníkami)

| Meno | Email | Rola | ReportType | CheckNumber | Default | Aktívny | Poznámky |
|---|---|---|---|---|---|---|---|
| Martina Medvedova | m.medvedova@company.com | MO | * | 0 | ✓ | ✓ | Primary MO |
| Ivan Horvat | i.horvat@company.com | FO | FX | 4 | | ✓ | FX Checks 1,2,4,5 |
| Ana Kovac | a.kovac@company.com | FO | FX | 6 | | ✓ | FX Check 6 (Approvals) |
| Jozef Varga | j.varga@company.com | FO | FX | 4 | | ✓ | Náhrada za Ivana |
| Peter Cerny | p.cerny@company.com | FO | MM | 0 | ✓ | ✓ | MM Group Lead |
| Stefan Kutil | s.kutil@company.com | FO | MM | 0 | | ✓ | Náhrada za Petra (MM) |

**Logika s routing:**
- Ak Ivan nie je dostupný → notifikácia pojde Jozefovi (oba majú CheckNumber=4)
- Ak Peter nie je dostupný → notifikácia pojde Stefanovi (oba majú ReportType=MM)
- Výber sa robí v Power Apps podľa `Default=TRUE` (Peter dostane všetky MM)

---

## Ako sa to prepojí s FO Groups

**TZ01 FO Groups** (tabuľka s politikami):

| GroupID | GroupName | ReportType | CheckNumbers | RoutingPolicy |
|---|---|---|---|---|
| FX\|Traders | FX Traders | FX | 1,2,4,5,6 | Notify Assigned |
| MM\|Traders | MM Reconciliation | MM | 1,2,3,4 | Notify All |

**TZ01 Reviewers** (táto šablóna — konkrétni ľudia):

| Name | Email | Group | ReportType | CheckNumber |
|---|---|---|---|---|
| Ivan Horvat | ivan.horvat@company.com | FO | FX | 4 |
| Peter Cerny | peter.cerny@company.com | FO | MM | 0 |

**Prepojenie v app:**
1. MO flaguje transakciu pre Check 4 (FX)
2. App hľadá v **TZ01 FO Groups**: `ReportType=FX, CheckNumbers like "4"` → **RoutingPolicy="Notify Assigned"**
3. App hľadá v **TZ01 Reviewers**: `Group=FO, ReportType=FX, CheckNumber=4` → **Ivan Horvat**
4. Popup: "Notify Ivan Horvat (FX Check 4 — Hedge rate)"

---

## CSV formát (ak chceš naplniť cez skript)

Skopíruj si `REVIEWERS_TEMPLATE.csv` a vyplň:

```csv
Name,Email,Group,ReportType,CheckNumber,IsDefault,Active,Notes
Martina Medvedova,martina.medvedova@mdlz.com,MO,*,0,TRUE,TRUE,MO Default
Ana Kovac,ana.kovac@mdlz.com,FO,FX,6,FALSE,TRUE,FX Check 6
Peter Cerny,peter.cerny@mdlz.com,FO,MM,0,TRUE,TRUE,MM Group Lead
```

Potom sa dá automaticky importovať do SharePoint:

```powershell
$csv = Import-Csv REVIEWERS_TEMPLATE.csv
foreach ($row in $csv) {
  Add-PnPListItem -List "TZ01 Reviewers" -Values @{
    Title = $row.Name
    Name = $row.Name
    Email = $row.Email
    Group = $row.Group
    ReportType = $row.ReportType
    CheckNumber = [int]$row.CheckNumber
    IsDefault = ($row.IsDefault -eq "TRUE")
    Active = ($row.Active -eq "TRUE")
  }
}
```

---

## Kontrolný zoznam pred submisiou

Pred tým, ako pošleš vyplnenú tabuľku:

- [ ] Všetci ľudia majú platný **Email** (formát: meno@domena)
- [ ] Všetci ľudia majú zvolenú **Rolu** (MO / FO / ADMIN)
- [ ] Všetci FO majú **ReportType** (FX alebo MM, nie *)
- [ ] Všetci MO majú **ReportType=\*** (všetko)
- [ ] Jeden a len jeden **Default=TRUE** per ReportType (MO Default + FX/MM Defaults)
- [ ] **CheckNumber** je 0 alebo platné číslo (1–6 pre FX, 1–4 pre MM)
- [ ] Všetci majú **Active=TRUE** (pokiaľ nejde o stavy medzi zmenami)
- [ ] Máte aspoň 1 MO a 1 FO per ReportType

---

## Odoslanie

1. Vyplní **zákazník**
2. Pošle **tabuľku / CSV** na doplnenie
3. **Ján** spustí skript na naplnenie SharePoint listu:
   ```powershell
   ./TZ01_provision_full.ps1 -SiteUrl "..." -Reseed
   ```
4. Všetci ľudia sú v systéme a dostávajú notifikácie 📧

---

## Súbory

| Súbor | Účel |
|---|---|
| `REVIEWERS_TEMPLATE.md` | Táto inštrukcia (Slovák) |
| `REVIEWERS_TEMPLATE.csv` | CSV export — otvor v Exceli |
| `TZ01_provision_full.ps1` | PowerShell skript — spustí sa po vyplnení |
| `FO_ROUTING.md` | Detailný design FO routing politík |
| `FO_GROUPS_MATRIX.md` | Vizuálna matica (Check → Trader → Policy) |
