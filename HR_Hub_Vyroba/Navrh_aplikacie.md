# Evidencia zamestnancov výroby – návrh Power Apps aplikácie

> **Verzia 2 aplikácie HR Hub** zameraná na výrobný personál v automotive prostredí
> (dodávateľ pre **Stellantis**, zákaznícke audity **IATF 16949**).
> Dokument je **solution design** – riešiteľný návrh, podľa ktorého sa aplikácia
> postaví. Nie je to implementácia.

---

## 0. Zhrnutie a kľúčové odporúčania

| Oblasť | Odporúčanie | Dôvod (skrátene) |
|--------|-------------|------------------|
| **Úložisko** | **Dataverse** (nie SharePoint) | relačná integrita, **natívny audit log** pre IATF, role na úrovni riadkov, kalkulované polia pre termíny |
| **Skeny** | Dataverse **File** stĺpce | jeden zabezpečený a auditovaný sklad; pri veľkom objeme presunúť do SharePoint knižnice |
| **Fotka** | Dataverse **Image** stĺpec | natívne v Power Apps, miniatúry zadarmo |
| **Termíny** | Kalkulované stĺpce + **scheduled Power Automate** | automatický výpočet aj proaktívne notifikácie |
| **Reporting** | Natívny **export do Excelu/PDF** z appky + voliteľne Power BI | personalista bez IT to zvládne tlačidlom; Power BI pre bohatší audit dashboard |
| **Aplikácia** | **Canvas app** (Teams/web) | jednoduché, prehľadné UI pre netechnického používateľa |
| **Licencie** | **Power Apps Premium** per-user pre pár používateľov + 1 Power Automate Premium pre servisné konto | malý počet používateľov → per-user lacnejší než per-flow |

**Hlavný používateľ:** personalista/personalistka bez IT skúseností → dôraz na minimum klikov,
jasné stavové farby, žiadne „SharePoint surovosti".

---

## 1. Dátový model

### 1.1 Prehľad tabuliek

| # | Tabuľka (logický názov) | Typ | Účel |
|---|--------------------------|-----|------|
| 1 | `cr_Zamestnanec` (Zamestnanci) | hlavná | osobné údaje, fotka, stav |
| 2 | `cr_Stredisko` (Strediská) | číselník | oddelenia/nákladové strediská |
| 3 | `cr_Pozicia` (Pozície) | číselník | pracovné pozície |
| 4 | `cr_Operacia` (Operácie/Pracoviská) | číselník | výrobné operácie pre maticu |
| 5 | `cr_LekarskaPrehliadka` (Lekárske prehliadky) | 1:N k zamestnancovi | vstupná/preventívna prehliadka |
| 6 | `cr_Dokument` (Dokumenty/Skeny) | 1:N k zamestnancovi (voliteľne k školeniu) | adaptačný list, vstupný test, papiere |
| 7 | `cr_TypSkolenia` (Typy školení) | číselník | ročné preškolenie, kontrolór, … |
| 8 | `cr_Skolenie` (Školenia – záznamy) | 1:N k zamestnancovi | plán/vykonané + % úspešnosti |
| 9 | `cr_MaticaZaskolenia` (Matica zaškolenia) | N:N väzba Zamestnanec × Operácia | úroveň ILUO/0–4, zastupiteľnosť |
| 10 | `cr_FasovanieOOPP` (Fasovanie OOPP) | 1:N k zamestnancovi | oblečenie/OOPP + ďalší termín |

> Použité prefixy stĺpcov sú ilustračné (`cr_` = custom publisher). Pri implementácii sa
> nahradia prefixom riešenia (solution publisher).

### 1.2 Polia podľa tabuliek

**1) Zamestnanci `cr_Zamestnanec`**

| Pole | Dátový typ | Pozn. |
|------|-----------|-------|
| Meno a priezvisko | Text (Primary Name) | povinné |
| Osobné číslo | Text (Alternate Key, unikátne) | natívna kontrola duplicity |
| Stredisko | Lookup → `cr_Stredisko` | |
| Pozícia | Lookup → `cr_Pozicia` | |
| Fotka | **Image** | miniatúra v zoznamoch |
| Dátum nástupu | Date Only | vstup pre výpočet 1. preventívnej prehliadky |
| Stav | Choice: `Aktívny` / `Neaktívny` | soft-delete, defaultne Aktívny |
| E-mail | Text (Email format) | voliteľné, pre notifikácie zamestnancovi |
| (rollup) Najbližší termín | **Rollup**/kalk. | min z termínov prehliadky/školenia/fasovania – pre indikátor v zozname |

**2) Strediská `cr_Stredisko`** — Názov (primary), Kód, Vedúci (Lookup → Zamestnanec).
**3) Pozície `cr_Pozicia`** — Názov (primary), Kategória (Choice: výroba/kontrola/THP).

**4) Operácie/Pracoviská `cr_Operacia`** — Názov operácie (primary), Kód, Stredisko (Lookup), Popis, Aktívna (Yes/No).

**5) Lekárske prehliadky `cr_LekarskaPrehliadka`** (1:N k Zamestnanec)

| Pole | Typ | Pozn. |
|------|-----|-------|
| Zamestnanec | Lookup → `cr_Zamestnanec` | povinné |
| Typ | Choice: `Vstupná` / `Preventívna` | |
| Dátum vykonania | Date Only | |
| Dátum ďalšieho termínu | Date Only (kalkulovateľný) | preventívna = vykonanie + 1 rok |
| Stav | Choice: `Platná` / `Blíži sa` / `Po termíne` | počítaný pri zápise / flow |
| Sken / príloha | **File** | |
| Poznámka | Multiline Text | |

**6) Dokumenty / skeny `cr_Dokument`** (1:N k Zamestnanec, voliteľne k Školeniu)

| Pole | Typ | Pozn. |
|------|-----|-------|
| Zamestnanec | Lookup → `cr_Zamestnanec` | povinné |
| Školenie | Lookup → `cr_Skolenie` | voliteľné (papiere zo školenia) |
| Druh dokumentu | Choice: `Adaptačný list` / `Vstupný test` / `Školenie – papiere` / `Iné` | |
| Sken | **File** | |
| % úspešnosti | Decimal (0–100) | len pri vstupnom teste |
| Dátum | Date Only | |

**7) Typy školení `cr_TypSkolenia`** (číselník)

| Pole | Typ | Pozn. |
|------|-----|-------|
| Názov | Text (primary) | napr. „Ročné preškolenie", „Prestup na kontrolóra" |
| Perióda (mesiace) | Whole Number | 12 = ročné; 0 = jednorazové |
| Povinné pre všetkých | Yes/No | ročné preškolenie = áno |

**8) Školenia – záznamy `cr_Skolenie`** (1:N k Zamestnanec)

| Pole | Typ | Pozn. |
|------|-----|-------|
| Zamestnanec | Lookup → `cr_Zamestnanec` | |
| Typ školenia | Lookup → `cr_TypSkolenia` | |
| Plánovaný dátum | Date Only | |
| Vykonaný dátum | Date Only | prázdne = naplánované |
| Ďalší plánovaný termín | Date Only (kalk.) | vykonané + perióda |
| % úspešnosti testu | Decimal (0–100) | |
| Stav | Choice: `Naplánované` / `Platné` / `Blíži sa` / `Po termíne` | |
| Sken papierov | **File** | |

**9) Matica zaškolenia `cr_MaticaZaskolenia`** (väzba Zamestnanec × Operácia)

| Pole | Typ | Pozn. |
|------|-----|-------|
| Zamestnanec | Lookup → `cr_Zamestnanec` | povinné |
| Operácia | Lookup → `cr_Operacia` | povinné |
| Úroveň | Choice **ILUO / 0–4**: `0 nezaškolený` / `1 pod dohľadom` / `2 samostatne` / `3 expert (môže zaškoľovať)` | |
| Dátum poslednej aktualizácie | Date Only | |
| Poznámka | Multiline Text | |

> Kombinácia Zamestnanec+Operácia by mala byť **unikátna** (alternate key z dvoch lookupov
> alebo validácia vo flowe), aby pre jednu dvojicu nevznikli dve úrovne.

**10) Fasovanie OOPP `cr_FasovanieOOPP`** (1:N k Zamestnanec)

| Pole | Typ | Pozn. |
|------|-----|-------|
| Zamestnanec | Lookup → `cr_Zamestnanec` | |
| Dátum odovzdania | Date Only | |
| Dátum ďalšieho fasovania | Date Only (kalk.) | odovzdanie + 2 roky |
| Položky / veľkosti | Multiline Text alebo pod-tabuľka | voliteľné |
| Stav | Choice: `Platné` / `Blíži sa` / `Po termíne` | |

### 1.3 ERD (textový popis)

```
                         ┌────────────────┐
        Vedúci ─────────►│   Stredisko    │◄──────── Operácia (N:1)
                         └───────┬────────┘
                                 │ 1:N
                          ┌──────▼─────────┐        ┌──────────────┐
        Pozícia (N:1) ───►│  Zamestnanec   │        │  TypSkolenia │
                          └──────┬─────────┘        └──────┬───────┘
            ┌──────────────┬─────┼───────┬───────────────┐ │ N:1
            │1:N           │1:N  │1:N    │1:N            │ │
   ┌────────▼───┐ ┌────────▼──┐ ┌▼───────────┐ ┌─────────▼─▼┐ ┌─────────────┐
   │ Lekárska   │ │ Dokument  │ │ Fasovanie  │ │  Školenie   │ │MaticaZaskol.│
   │ prehliadka │ │ (sken)    │ │ OOPP       │ │  (záznam)   │ │ (Zam×Oper)  │
   └────────────┘ └─────┬─────┘ └────────────┘ └──────┬──────┘ └──────┬──────┘
                        │ N:1 (voliteľne)             │               │ N:1
                        └─────────────────────────────┘               ▼
                                                                  Operácia
```

- `Zamestnanec` je centrálna; všetky evidencie (prehliadky, dokumenty, školenia,
  fasovanie, matica) sú jeho podriadené 1:N, resp. N:N pri matici.
- `Dokument` má voliteľnú väzbu na `Skolenie` (papiere vypísané pri školení).
- Číselníky (`Stredisko`, `Pozicia`, `Operacia`, `TypSkolenia`) sú referenčné N:1.

---

## 2. Obrazovky (UX)

Canvas app, slovenské UI, ľavé navigačné menu. Stavová farebnosť všade rovnaká:
🟢 **Platné** · 🟡 **Blíži sa termín** · 🔴 **Po termíne** · ⚪ **Naplánované / N/A**.

**A) Zoznam zamestnancov** – vstupná obrazovka
```
┌───────────────────────────────────────────────────────────────┐
│ 🔍 [Hľadať meno/os.číslo]   Stredisko ▾   Stav ▾   [+ Nový]     │
├───────────────────────────────────────────────────────────────┤
│ [foto] Ján Novák   OS123  Lisovňa  Operátor   🟡 prehliadka 12d │
│ [foto] Eva Malá    OS124  Montáž   Kontrolór  🔴 školenie -3d   │
│ [foto] …                                                        │
└───────────────────────────────────────────────────────────────┘
```
Filter podľa strediska/stavu; farebný indikátor = najbližší blížiaci/po termíne záznam.

**B) Detail zamestnanca** – karty (tabs)
```
[ Ján Novák · OS123 · Lisovňa · Operátor ]            🟢 Aktívny
┌ Osobné ─┬ Dokumenty ─┬ Lekárske ─┬ Školenia ─┬ Fasovanie ─┬ Matica ┐
│ [FOTO]  │  Adaptačný list ✅                                        │
│ nástup  │  Vstupný test 88% ✅                                      │
│ …       │  [+ pridať sken]                                          │
└─────────────────────────────────────────────────────────────────┘
```
Každá karta = galéria príslušných záznamov + tlačidlo „pridať", náhľad skenu/fotky inline.

**C) Kvalifikačná matica – zastupiteľnosť** – mriežka Zamestnanci × Operácie
```
              Lis-01  Lis-02  Mont-01  Kontrola
 Ján Novák      3       2        1        0
 Eva Malá       2       3        2        3
 …
 Legenda: 0–3 (ILUO), farebné bunky; klik na bunku → zmena úrovne + dátum.
 Filter: stredisko, operácia. „Kto vie zastúpiť operáciu X" = stĺpec ≥ 2.
```

**D) Plán školení / kalendár termínov**
```
Filtre: typ termínu (prehliadka/školenie/fasovanie), obdobie, stredisko
┌ Dátum ─┬ Zamestnanec ─┬ Typ ──────────┬ Stav ─┐
│ 20.6.  │ Ján Novák    │ Preventívna LP │ 🟡    │
│ 25.6.  │ Eva Malá     │ Ročné presk.   │ 🔴    │
```
Zoznamový aj kalendárový pohľad „čo treba spraviť a dokedy".

**E) Dashboard pre audit**
```
KPI dlaždice: % platných prehliadok · školenia po termíne · pokrytie OOPP
Tabuľka (filtre: stredisko, typ): Zamestnanec | Prehliadka | Školenie | OOPP | Matica
[ ⬇ Export do Excelu ]   [ ⬇ Export do PDF ]
```
Presne pohľad, aký vyžaduje auditorka, s exportom jedným klikom.

---

## 3. Power Automate flowy

| # | Flow | Trigger | Logika |
|---|------|---------|--------|
| 1 | **Kontrola termínov + notifikácie** | Recurrence (denne ráno) | dotaz na prehliadky/školenia/fasovanie s `ďalší termín` v okne X dní; pošli e-mail/Teams adaptívnu kartu personalistovi (súhrn) a voliteľne vedúcemu strediska |
| 2 | **Prepočet stavu** | Recurrence (denne) **alebo** on-create/update riadku | nastav `Stav` = Platné/Blíži sa/Po termíne podľa `ďalší termín` vs dnešok (alternatíva ku kalkulovanému stĺpcu) |
| 3 | **Auto-plán po vykonaní** | Dataverse: pri vyplnení `Vykonaný dátum` | dopočítaj `ďalší plánovaný termín` (+perióda / +1 rok / +2 roky) a založ ďalší naplánovaný záznam |
| 4 | **Export pre audit** | Power Apps (tlačidlo na dashboarde) | vygeneruj Excel (Office Scripts) / PDF a pošli e-mailom alebo ulož do SharePointu |
| 5 | **Onboarding kontrola** *(voliteľné)* | pri vzniku nového zamestnanca | založ úlohu „vstupná prehliadka", „adaptačný list", prvé fasovanie |

> Výpočet termínov je možné riešiť dvoma spôsobmi: **kalkulovaný/rollup stĺpec** v Dataverse
> (deterministický, bez flowu) alebo **flow #3** (umožní založiť aj nasledujúci plánovaný
> záznam). Odporúčam kombináciu: termín ako kalkulovaný stĺpec + flow na založenie ďalšieho
> záznamu a notifikácie.

---

## 4. Bezpečnostné roly (Dataverse security roles)

| Rola | Práva | Rozsah |
|------|-------|--------|
| **Personalista** | Create / Read / Write / (Append) na všetky tabuľky | celá organizácia (resp. business unit závodu) |
| **Vedúci / majster** | **Read** všetko; prípadne Write len na maticu svojho strediska | business unit / team strediska |
| **Audítor** | **Read-only** na všetko, žiadny zápis, žiadny export mimo appky | celá organizácia |
| **Správca riešenia** | System Customizer | správa schémy, flowov |

- Pri **viacerých závodoch** použiť **Business Units** (jeden BU = jeden závod) a roly s rozsahom
  „Business Unit", aby vedúci/personalista videli len svoj závod.
- Zapnúť **Dataverse auditing** na všetkých tabuľkách (kto/kedy/čo zmenil) – kľúčové pre IATF.
- Skeny obsahujú osobné údaje → roly riadia prístup k File stĺpcom rovnako ako k riadkom.

---

## 5. Úložisko a licencie – odporúčanie s odôvodnením

### 5.1 Dataverse vs SharePoint

| Kritérium | **Dataverse** ✅ | SharePoint |
|-----------|------------------|------------|
| Relačný model / integrita | natívne lookupy, kaskády, alternate keys | zoznamy + lookupy, slabšia integrita |
| **Audit log** (IATF) | **vstavaný** per-stĺpec/per-riadok | len M365 audit, menej granulárne |
| Bezpečnosť | roly, BU, team, **row-level** | povolenia na list/položku, ťažšie spravovateľné |
| Delegácia / limity | bez 5000 limitu, silná delegácia | 5000-item view threshold, problémy s delegáciou |
| Kalkulované/rollup polia | áno (termíny) | obmedzene |
| Súbory/obrázky | File & Image stĺpce | knižnica/prílohy, limity |
| Licencia | **vyžaduje premium** | súčasť M365 |

**Odporúčanie: Dataverse.** Audítorské prostredie (IATF 16949), citlivé osobné údaje a potreba
spoľahlivého auditu zmien jednoznačne preváži vyššiu cenu licencie. Pri malom počte používateľov
je licenčný dopad zvládnuteľný.

### 5.2 Skeny a fotky

- **Fotka:** Dataverse **Image** stĺpec (automatické miniatúry, natívne v galériách).
- **Skeny:** Dataverse **File** stĺpec (PDF/JPG). Predvolený limit ~32 MB/súbor, konfigurovateľný
  (až 128 MB+). Súbory sa rátajú do **file storage** kapacity Dataverse.
- Pri **veľkom objeme skenov** (tisíce dokumentov) zvážiť uloženie skenov do **SharePoint
  knižnice** s odkazom z Dataverse (lacnejšia kapacita) – pri rozsahu tohto projektu to však
  nie je nutné a všetko v Dataverse je bezpečnejšie a jednoduchšie.

### 5.3 Notifikácie a reporting

- **Notifikácie:** scheduled cloud flow (konektor **Dataverse = premium**, Outlook/Teams = standard).
- **Reporting:** pre personalistu **natívny export** (tlačidlo → Excel/PDF) je najjednoduchší.
  Pre bohatší audit dashboard pridať **Power BI** report nad Dataverse (priame pripojenie,
  bez kopírovania dát). Odporúčam začať natívnym exportom, Power BI doplniť podľa potreby.

### 5.4 Licencie (orientačne – ceny si overte v aktuálnom cenníku M365)

| Položka | Licencia | Orientačný dopad |
|---------|----------|------------------|
| Editor (personalista) | **Power Apps Premium** (per-user) | ~20 USD/user/mes. |
| Čítajúci (vedúci, audítor) | Power Apps Premium per-user | rovnako, pre pár ľudí OK |
| Scheduled flow (notifikácie) | **Power Automate Premium** na servisné konto | ~15 USD/mes. (1 konto) |
| Dataverse storage | súčasť Power Apps, navýšenie podľa objemu skenov | podľa GB |

- **Per-app vs per-user:** pri malom počte používateľov a jednej appke je rozdiel malý;
  **per-user Premium** je flexibilnejší (pokryje aj prípadnú druhú appku/flow v kontexte).
  Ak by počet čítajúcich výrazne narástol, prehodnotiť per-app plán.
- Scheduled flow beží mimo kontextu appky → potrebuje **vlastnú** Power Automate licenciu
  (per-user na servisnom konte je lacnejšie než per-flow ~100 USD/mes. pri jednom flowe).

---

## 6. Postup implementácie a odhad náročnosti

| Fáza | Obsah | Odhad |
|------|-------|-------|
| 1. Príprava | solution publisher, prostredie (DEV/TEST/PROD), business units | 0,5 dňa |
| 2. Dátový model | 10 tabuliek, stĺpce, vzťahy, alternate keys, kalkulované polia, auditing | 2–3 dni |
| 3. Číselníky + migrácia z Excelu | import stredísk, pozícií, operácií, typov školení; mapovanie a import zamestnancov a histórie | 2–3 dni |
| 4. Canvas app | 5 obrazoviek (zoznam, detail-karty, matica, plán, dashboard), stavová logika a farby | 4–6 dní |
| 5. Power Automate | flowy 1–4 (+5 voliteľne) | 2–3 dni |
| 6. Bezpečnosť | roly, BU, testy prístupov (personalista/vedúci/audítor) | 1 deň |
| 7. Reporting | export Excel/PDF; voliteľne Power BI | 1–2 dni |
| 8. Test + UAT + zaškolenie | s personalistom, audit-ready kontrola | 2–3 dni |
| **Spolu** | | **~3–4 týždne** jedného konzultanta |

**Migrácia z Excelu:** najrizikovejší krok – vyčistiť duplicity (osobné číslo ako kľúč),
zjednotiť formáty dátumov, doplniť chýbajúce termíny prehliadok/fasovania.

---

## 7. Predpoklady a otvorené otázky

**Prijaté predpoklady (označené):**
- **[P1]** Malý počet súbežných používateľov (jednotky), 1 personalista ako hlavný editor.
- **[P2]** Rozsah desiatky až nižšie stovky zamestnancov a desiatky operácií → žiadne škálovacie
  prekážky pre Dataverse aj canvas app.
- **[P3]** Stupnica zaškolenia = **ILUO / 0–3** (0 nezaškolený → 3 expert/zaškoľuje); upraviteľné.
- **[P4]** Preventívna prehliadka = +1 rok, fasovanie = +2 roky, ročné preškolenie = +1 rok
  (presné periódy podľa internej smernice firmy).
- **[P5]** Jeden závod; pri viacerých sa použijú Business Units.
- **[P6]** UI v slovenčine, jednojazyčné.

**Cielené otázky pred implementáciou:**
1. **Koľko zamestnancov a operácií** sa eviduje (rádovo) a očakáva sa rast? (vplyv na licencie/maticu)
2. **Aké existujúce licencie** M365 / Power Platform už máte? (Power Apps Premium, Power Automate, Power BI?)
3. **Jeden závod, alebo viac** – treba oddeliť dáta a prístupy medzi prevádzkami?
4. **GDPR / retencia skenov** – ako dlho uchovávať dokumenty a kedy/anonymizovať pri odchode zamestnanca?
5. **Periódy a stupnica zaškolenia** – sú periódy (1 rok/2 roky) a škála ILUO presne podľa internej
   smernice, alebo ich máme nastaviť inak?
