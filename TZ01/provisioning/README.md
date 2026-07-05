# TZ01 — SharePoint provisioning

`TZ01_provision_full.ps1` vytvorí všetkých 9 TZ01 listov (proposal kap. 14) a naplní
ich test dátami, ktoré má appka v kolekciách. Generuje sa z `App.OnStart` skriptom
`gen_provision.py` (spúšťaj z rootu repa: `python3 TZ01/provisioning/gen_provision.py`).

Delta skripty (`*_v2/_v3/_v3_1/_v4_delta.ps1`) sú **čiastočné** – menia len pár listov.
Kompletný „všetko od nuly" je **`TZ01_provision_full.ps1`**.

---

## Kroky spustenia

### 1) PowerShell 7 + modul PnP.PowerShell (raz)
```powershell
# over verziu – musí byť 7.x
$PSVersionTable.PSVersion

# nainštaluj PnP.PowerShell
Install-Module PnP.PowerShell -Scope CurrentUser -Force
```

### 2) Registrácia Entra (Azure AD) appky pre PnP prihlásenie (raz za tenant)
Novšie PnP.PowerShell už nemá vstavanú prihlasovaciu appku – treba vlastný **ClientId**.
Buď použi existujúci App registration, alebo vytvor jednorazovo cez PnP:
```powershell
Register-PnPEntraIDAppForInteractiveLogin `
  -ApplicationName "PnP-TZ01-Provisioning" `
  -Tenant "<tenant>.onmicrosoft.com" `
  -Interactive
```
Príkaz vypíše **Client Id** (GUID) – skopíruj si ho. (Prvýkrát vyžaduje admin súhlas
na delegované SharePoint práva.)

### 3) Cieľový SharePoint site
Skript vytvára **listy v existujúcom site** – site vopred maj hotový
(napr. cez portál „+ Create site → Team/Communication site"), alebo cez PnP:
```powershell
# voliteľné – vyžaduje SharePoint admin
Connect-PnPOnline -Url "https://<tenant>-admin.sharepoint.com" -Interactive -ClientId "<ClientId>"
New-PnPSite -Type CommunicationSite -Title "TZ01" -Url "https://<tenant>.sharepoint.com/sites/TZ01"
```

### 4) Spustenie skriptu
```powershell
cd TZ01/provisioning

./TZ01_provision_full.ps1 `
  -SiteUrl  "https://<tenant>.sharepoint.com/sites/TZ01" `
  -ClientId "<ClientId>"
```
Otvorí sa prihlasovacie okno (interaktívne). Skript je **idempotentný** – existujúce
listy/stĺpce preskočí, takže sa dá pustiť opakovane.

### Prepínače
| Prepínač | Účinok |
|---|---|
| `-Reseed` | najprv **zmaže položky** v každom liste a naseeduje nanovo (stĺpce nechá) |
| `-SkipPeople` | neresolvuje Reviewer ako osobu – zapíše len email do text stĺpca |
| `-ClientId <guid>` | app registration pre prihlásenie (viď krok 2) |

Príklad čistého reseedu:
```powershell
./TZ01_provision_full.ps1 -SiteUrl "https://<tenant>.sharepoint.com/sites/TZ01" -ClientId "<guid>" -Reseed
```

### 5) Overenie
V site → **Site contents** by malo byť 9 TZ01 listov naplnených dátami:
Daily Item (1), Daily Reports (2), Daily Report Checks (10), Daily Transactions (10),
Reason Config (81), Reviewers (5), Check Columns (65), Top Report (3), Input Files (2).
```powershell
Connect-PnPOnline -Url "https://<tenant>.sharepoint.com/sites/TZ01" -Interactive -ClientId "<guid>"
Get-PnPList | Where-Object Title -like "TZ01*" | Select-Object Title, ItemCount
```

---

## Poznámky
- **Placeholder emaily** reviewerov (`*@mdlz.com`) sa v cudzom tenante nemusia
  resolvnúť ako osoby → skript vypíše warning a nechá len email text (alebo použi
  `-SkipPeople`). Pre ostrý beh nahraď emaily reálnymi používateľmi tenantu.
- App-only (bez okna, napr. z pipeline): zaregistruj appku s **certifikátom** a
  SharePoint app-only právami a uprav `Connect-PnPOnline` na
  `-ClientId <id> -Tenant <tenant> -CertificatePath <pfx>`.
- Po naplnení listov: v appke odkomentuj **PRODUCTION SWAP** blok v `App.OnStart`
  (načíta kolekcie z týchto listov namiesto seedu) – názvy a rename mapy už sedia.
