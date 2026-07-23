# TZ01 Reviewers Setup — Customer Input Required ✉️

Prosím, vyplňte tabuľku s konkrétnym menom, emailom a rolami ľudí v tíme, ktorí budú používať systém TZ01.

---

## 📋 Čo máte poslať?

Jeden z dvoch formátov:

### **Možnosť A: Excel / Google Sheets (najjednoduchšie)**
Skopírujte tabuľku nižšie a vyplňte:

| Meno | Email | Rola | Typ reportu | Check | Default | Aktívny | Poznámky |
|---|---|---|---|---|---|---|---|
| **[Meno operátora]** | **meno@company.com** | **MO** | **\*** | **0** | **✓** | **✓** | Hlavný operátor |
| **[Meno FX tradra]** | **email@company.com** | **FO** | **FX** | **6** | | **✓** | Approvals |
| **[Meno MM tradra]** | **email@company.com** | **FO** | **MM** | **0** | **✓** | **✓** | Group Lead |
| | | | | | | | |

### **Možnosť B: CSV súbor (ak už máte dáta v Exceli)**
Exportujte ako CSV `REVIEWERS_TEMPLATE.csv` s týmito stĺpcami:
```
Name,Email,Group,ReportType,CheckNumber,IsDefault,Active,Notes
Jozef Varga,jozef.varga@company.com,MO,*,0,TRUE,TRUE,Primary MO
```

---

## 🎯 Čo znamenajú stĺpce?

| Stĺpec | Príklady | Poznámka |
|---|---|---|
| **Meno** | Jozef Varga | Ako sa budú zobrazovať v aplikácii |
| **Email** | jozef.varga@company.com | Na rozoslanie notifikácií |
| **Rola** | MO / FO / ADMIN | MO=operátor, FO=trader, ADMIN=admin |
| **Typ reportu** | FX / MM / \* | FX=valuta, MM=peniaze, \*=všetko |
| **Check** | 0 (všetko) alebo 1–6 | Ktorý check spravuje (0=všetky checks v type) |
| **Default** | ✓ / ✗ | Default reviewer pre typ? (max 1 per type) |
| **Aktívny** | ✓ / ✗ | Je v tíme? |

---

## 📝 Príklad vyplnenia (Treasury Operácie + FX/MM team)

| Meno | Email | Rola | ReportType | CheckNumber | Default | Aktívny | Poznámky |
|---|---|---|---|---|---|---|---|
| Martina Medvedova | martina.m@bank.com | **MO** | **\*** | **0** | ✓ | ✓ | Vedúca operácií |
| Ana Kovac | ana.k@bank.com | **FO** | **FX** | **6** | | ✓ | FX Approvals (DTCC) |
| Ivan Horvat | ivan.h@bank.com | **FO** | **FX** | **4** | | ✓ | FX Reconciliation |
| Peter Cerny | peter.c@bank.com | **FO** | **MM** | **0** | ✓ | ✓ | MM Group Lead |

**Logika:**
- Martina (MO) dostane všetky notifikácie (Default MO)
- Ana dostane len FX Check 6
- Ivan dostane FX Checks 1,2,4,5
- Peter dostane všetky MM checks (Default group lead)

---

## ✅ Pred odoslaním skontrolujte

- [ ] Všetci ľudia majú **Email** v tvare `meno@company.com`
- [ ] Všetci majú zvolenú **Rolu** (MO / FO / ADMIN)
- [ ] Máte **aspoň 1 MO** a **aspoň 1 FO** na ReportType (FX alebo MM)
- [ ] Iba **jeden Default=TRUE** per ReportType
- [ ] **CheckNumber** = 0 (všetko) alebo číslo 1–6
- [ ] Všetci majú **Active=TRUE** (ak nie sú na materskej / nemocenská)

---

## 📤 Ako poslať?

Pošlite odpoveď s tabuľkou:

**Emailom na:** [tvoj email]  
**Predmet:** `TZ01 Reviewers Setup — [Organization Name]`  
**Súbory:**
- Excel tabuľka ALEBO
- CSV export (REVIEWERS_TEMPLATE.csv)

**Príklad:**
```
Prosím nájdete vyplnenie TZ01 Reviewers pre náš tím:

Martina Medvedova — MO, všetky reports, Default
Ana Kovac — FO, FX, Check 6 (Approvals)
Ivan Horvat — FO, FX, Checks 1,2,4,5 (Reconciliation)
Peter Cerny — FO, MM, všetky checks, Default
```

---

## 🔧 Po odoslaní (čo sa bude diať)

1. ✅ Tabuľka sa spracuje
2. ✅ Skript automaticky naplní SharePoint list `TZ01 Reviewers`
3. ✅ Všetci ľudia budú v systéme
4. ✅ Všetci dostávajú notifikácie podľa svojej role + checks

---

## ❓ Časte kladené otázky

**Q: Čo je "Default"?**  
A: Keď máte `CheckNumber=0` (všetky checks), nastaví sa ako default reviewer, ktorý dostane všetky notifikácie daného typu.

**Q: Môžem dať FO trader "FX" aj "MM"?**  
A: Áno, ale vyžaduje to dve riadky — jednu pre FX, jednu pre MM.

**Q: Čo keď sa neskôr zmení tím?**  
A: Pošlite novelú tabuľku s `Active=FALSE` pre ľudí, ktorí odchádzajú, a novými riadkami pre nových.

**Q: Môžem mať viaceré defaults?**  
A: NIE. Len jeden `Default=TRUE` per ReportType. Systém potrebuje vedieť, kto je "prvý port of call".

---

## 📚 Súbory k dispozícii

| Súbor | Účel |
|---|---|
| **REVIEWERS_TEMPLATE.csv** | Vyplnená šablóna s príkladmi |
| **REVIEWERS_TEMPLATE_EMPTY.csv** | Prázdna šablóna (copy-paste a vyplň) |
| **REVIEWERS_TEMPLATE.md** | Detailný návod v slovenčine |
| **FO_GROUPS_MATRIX.md** | Vizuálna matica checks → traders |

---

## 📞 Pomoc?

Ak máte otázky, kontaktujte: [tvoj email]

Ďakujeme! 🎉
