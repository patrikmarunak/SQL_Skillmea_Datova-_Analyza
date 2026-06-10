#!/usr/bin/env python3
"""
Generátor simulovaných dát pre SharePoint listy aplikácie HR Hub.

Vytvorí CSV súbory v ../data/ pre listy:
  Departments, Positions, Employees, TrainingsCatalog, TrainingRecords, AuditLog

Dáta sú deterministické (pevný seed) a referenčne konzistentné:
  - Employees.Department  -> Departments.DepartmentCode
  - Employees.Position    -> Positions.PositionName
  - Employees.ManagerEmail-> Departments.Manager (e-mail manažéra oddelenia)
  - TrainingRecords.Employee -> Employees.EmployeeID
  - TrainingRecords.Training -> TrainingsCatalog.TrainingName
  - ExpirationDate = CompletionDate + ValidityMonths (DateAdd ... Months)
  - Status: Valid / Expiring (do 30 dní) / Expired / Planned voči dátumu TODAY

Spustenie:  python3 generate_data.py
"""

import csv
import random
import unicodedata
from datetime import date, datetime, timedelta
from pathlib import Path

random.seed(42)

# Pevný "dnešok", aby boli stavy (Valid/Expiring/Expired) reprodukovateľné.
TODAY = date(2026, 6, 10)
EXPIRING_WINDOW_DAYS = 30
DOMAIN = "contoso.sk"

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)


def strip_accents(text: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", text)
        if unicodedata.category(c) != "Mn"
    )


def email_for(full_name: str) -> str:
    first, last = full_name.split(" ", 1)
    local = f"{strip_accents(first)}.{strip_accents(last)}".lower().replace(" ", "")
    return f"{local}@{DOMAIN}"


def add_months(d: date, months: int) -> date:
    """Ekvivalent Power Fx DateAdd(d, months, Months)."""
    month_index = d.month - 1 + months
    year = d.year + month_index // 12
    month = month_index % 12 + 1
    # posledný deň cieľového mesiaca, ak pôvodný deň neexistuje (31.1. + 1M -> 28.2.)
    last_day = [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28,
                31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
    return date(year, month, min(d.day, last_day))


def iso(d: date) -> str:
    return d.isoformat()


def write_csv(filename: str, fieldnames: list[str], rows: list[dict]) -> None:
    path = DATA_DIR / filename
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"  {filename}: {len(rows)} riadkov")


# ---------------------------------------------------------------- Departments
DEPARTMENTS = [
    {"DepartmentName": "Ľudské zdroje",          "DepartmentCode": "HR",  "Manager": "Katarína Bieliková"},
    {"DepartmentName": "Informačné technológie", "DepartmentCode": "IT",  "Manager": "Peter Šimko"},
    {"DepartmentName": "Financie",               "DepartmentCode": "FIN", "Manager": "Martina Kováčová"},
    {"DepartmentName": "Obchod",                 "DepartmentCode": "SAL", "Manager": "Ján Hruška"},
    {"DepartmentName": "Marketing",              "DepartmentCode": "MKT", "Manager": "Lucia Vargová"},
    {"DepartmentName": "Výroba a prevádzka",     "DepartmentCode": "OPS", "Manager": "Milan Urban"},
    {"DepartmentName": "Kvalita",                "DepartmentCode": "QA",  "Manager": "Eva Tóthová"},
    {"DepartmentName": "Právne oddelenie",       "DepartmentCode": "LEG", "Manager": "Tomáš Sokol"},
]

# ------------------------------------------------------------------ Positions
POSITIONS = [
    {"PositionName": "HR generalista",          "Level": "Specialist"},
    {"PositionName": "HR manažér",              "Level": "Manager"},
    {"PositionName": "Softvérový vývojár",      "Level": "Specialist"},
    {"PositionName": "Senior softvérový vývojár", "Level": "Senior"},
    {"PositionName": "IT manažér",              "Level": "Manager"},
    {"PositionName": "Systémový administrátor", "Level": "Specialist"},
    {"PositionName": "Účtovník",                "Level": "Specialist"},
    {"PositionName": "Finančný kontrolór",      "Level": "Senior"},
    {"PositionName": "Finančný manažér",        "Level": "Manager"},
    {"PositionName": "Obchodný zástupca",       "Level": "Specialist"},
    {"PositionName": "Key Account Manager",     "Level": "Senior"},
    {"PositionName": "Obchodný riaditeľ",       "Level": "Manager"},
    {"PositionName": "Marketingový špecialista", "Level": "Specialist"},
    {"PositionName": "Marketingový manažér",    "Level": "Manager"},
    {"PositionName": "Operátor výroby",         "Level": "Junior"},
    {"PositionName": "Majster výroby",          "Level": "Senior"},
    {"PositionName": "Vedúci prevádzky",        "Level": "Manager"},
    {"PositionName": "Špecialista kvality",     "Level": "Specialist"},
    {"PositionName": "Manažér kvality",         "Level": "Manager"},
    {"PositionName": "Právnik",                 "Level": "Senior"},
]

# Manažérska pozícia pre každé oddelenie
DEPT_MANAGER_POSITION = {
    "HR": "HR manažér", "IT": "IT manažér", "FIN": "Finančný manažér",
    "SAL": "Obchodný riaditeľ", "MKT": "Marketingový manažér",
    "OPS": "Vedúci prevádzky", "QA": "Manažér kvality", "LEG": "Právnik",
}

# Radové pozície podľa oddelenia
DEPT_STAFF_POSITIONS = {
    "HR":  ["HR generalista"],
    "IT":  ["Softvérový vývojár", "Senior softvérový vývojár", "Systémový administrátor"],
    "FIN": ["Účtovník", "Finančný kontrolór"],
    "SAL": ["Obchodný zástupca", "Key Account Manager"],
    "MKT": ["Marketingový špecialista"],
    "OPS": ["Operátor výroby", "Majster výroby"],
    "QA":  ["Špecialista kvality"],
    "LEG": ["Právnik"],
}

FIRST_NAMES = [
    "Marek", "Zuzana", "Andrej", "Mária", "Michal", "Jana", "Pavol", "Veronika",
    "Štefan", "Alena", "Roman", "Ivana", "Juraj", "Monika", "Daniel", "Petra",
    "Ladislav", "Simona", "Vladimír", "Natália", "Richard", "Dominika", "Igor",
    "Barbora", "Matúš", "Kristína", "Ondrej", "Tatiana", "Filip", "Adriana",
    "Branislav", "Lenka", "Dušan", "Silvia",
]
LAST_NAMES_M = [
    "Novák", "Horváth", "Kováč", "Baláž", "Lukáč", "Molnár", "Polák", "Gajdoš",
    "Krajčí", "Fabian", "Šuster", "Bednár", "Marek", "Sedlák", "Holub", "Čierny",
    "Rybár",
]
LAST_NAMES_F = [
    "Nováková", "Horváthová", "Kováčiková", "Balážová", "Lukáčová", "Molnárová",
    "Poláková", "Gajdošová", "Krajčíová", "Fabianová", "Šusterová", "Bednárová",
    "Mareková", "Sedláková", "Holubová", "Čierna", "Rybárová",
]
FEMALE_FIRST = {
    "Zuzana", "Mária", "Jana", "Veronika", "Alena", "Ivana", "Monika", "Petra",
    "Simona", "Natália", "Dominika", "Barbora", "Kristína", "Tatiana", "Adriana",
    "Lenka", "Silvia",
}

# ------------------------------------------------------------------ Employees
# Počet radových zamestnancov na oddelenie (okrem manažéra)
DEPT_HEADCOUNT = {"HR": 3, "IT": 8, "FIN": 4, "SAL": 6, "MKT": 4, "OPS": 9, "QA": 3, "LEG": 2}

employees: list[dict] = []
used_names: set[str] = set()
emp_seq = 0


def next_employee_id() -> str:
    global emp_seq
    emp_seq += 1
    return f"EMP{emp_seq:04d}"


def random_name() -> str:
    while True:
        first = random.choice(FIRST_NAMES)
        last = random.choice(LAST_NAMES_F if first in FEMALE_FIRST else LAST_NAMES_M)
        name = f"{first} {last}"
        if name not in used_names:
            used_names.add(name)
            return name


def make_employee(full_name: str, dept: str, position: str, manager_email: str,
                  hire_date: date, status: str = "Active") -> dict:
    emp_id = next_employee_id()
    return {
        "EmployeeID": emp_id,
        "FullName": full_name,
        "Email": email_for(full_name),
        "Department": dept,            # DepartmentCode -> lookup pri importe
        "Position": position,          # PositionName  -> lookup pri importe
        "ManagerEmail": manager_email,
        "HireDate": iso(hire_date),
        "Status": status,
        "PhotoUrl": f"https://i.pravatar.cc/150?u={emp_id}",
    }


hr_manager_email = email_for("Katarína Bieliková")

# 1) Manažéri oddelení (reportujú HR manažérke ako zástupcovi vedenia,
#    HR manažérka reportuje konateľovi mimo zoznamu)
manager_emails: dict[str, str] = {}
for dept in DEPARTMENTS:
    code = dept["DepartmentCode"]
    name = dept["Manager"]
    used_names.add(name)
    mgr_boss = "" if code == "HR" else hr_manager_email
    hire = date(2015 + random.randint(0, 5), random.randint(1, 12), random.randint(1, 28))
    emp = make_employee(name, code, DEPT_MANAGER_POSITION[code], mgr_boss, hire)
    manager_emails[code] = emp["Email"]
    employees.append(emp)

# 2) Radoví zamestnanci
for code, count in DEPT_HEADCOUNT.items():
    for _ in range(count):
        name = random_name()
        position = random.choice(DEPT_STAFF_POSITIONS[code])
        hire = date(2016 + random.randint(0, 9), random.randint(1, 12), random.randint(1, 28))
        if hire > TODAY:
            hire = TODAY - timedelta(days=random.randint(30, 300))
        employees.append(make_employee(name, code, position, manager_emails[code], hire))

# 3) Pár neaktívnych zamestnancov (soft-delete scenár)
for emp in random.sample([e for e in employees if e["Position"] not in DEPT_MANAGER_POSITION.values()], 4):
    emp["Status"] = "Inactive"

# ----------------------------------------------------------- TrainingsCatalog
# ValidityMonths = 0 => školenie neexspiruje
TRAININGS = [
    {"TrainingName": "BOZP – vstupné školenie", "TrainingType": "Safety", "ValidityMonths": 24,
     "Description": "Povinné školenie bezpečnosti a ochrany zdravia pri práci pre všetkých zamestnancov.",
     "Provider": "BE-SOFT a.s."},
    {"TrainingName": "Ochrana pred požiarmi", "TrainingType": "Safety", "ValidityMonths": 24,
     "Description": "Periodické školenie o ochrane pred požiarmi podľa zákona č. 314/2001 Z. z.",
     "Provider": "BE-SOFT a.s."},
    {"TrainingName": "Prvá pomoc na pracovisku", "TrainingType": "Safety", "ValidityMonths": 24,
     "Description": "Praktický kurz poskytovania prvej pomoci s nácvikom resuscitácie.",
     "Provider": "Slovenský Červený kríž"},
    {"TrainingName": "GDPR a ochrana osobných údajov", "TrainingType": "Mandatory", "ValidityMonths": 12,
     "Description": "Ročné školenie o spracúvaní osobných údajov a povinnostiach podľa GDPR.",
     "Provider": "Interné – Právne oddelenie"},
    {"TrainingName": "Kybernetická bezpečnosť", "TrainingType": "Mandatory", "ValidityMonths": 12,
     "Description": "Phishing, heslá, bezpečná práca s firemnými dátami a zariadeniami.",
     "Provider": "ESET Academy"},
    {"TrainingName": "Etický kódex a compliance", "TrainingType": "Mandatory", "ValidityMonths": 24,
     "Description": "Školenie o etickom kódexe spoločnosti a protikorupčných pravidlách.",
     "Provider": "Interné – HR"},
    {"TrainingName": "Vodič referentského vozidla", "TrainingType": "Mandatory", "ValidityMonths": 24,
     "Description": "Povinné školenie vodičov služobných vozidiel do 3,5 t.",
     "Provider": "Autoškola Centrum"},
    {"TrainingName": "Práca vo výškach", "TrainingType": "Safety", "ValidityMonths": 12,
     "Description": "Odborná spôsobilosť pre prácu vo výške nad 1,5 m – výrobné pozície.",
     "Provider": "TÜV SÜD Slovakia"},
    {"TrainingName": "Obsluha VZV (vysokozdvižný vozík)", "TrainingType": "Certification", "ValidityMonths": 60,
     "Description": "Preukaz obsluhy motorových vozíkov triedy I a II.",
     "Provider": "TÜV SÜD Slovakia"},
    {"TrainingName": "ISO 9001 interný audítor", "TrainingType": "Certification", "ValidityMonths": 36,
     "Description": "Certifikačný kurz interného audítora systému manažérstva kvality.",
     "Provider": "SGS Slovakia"},
    {"TrainingName": "Scrum Master I (PSM I)", "TrainingType": "Certification", "ValidityMonths": 0,
     "Description": "Certifikácia Professional Scrum Master – bez exspirácie.",
     "Provider": "Scrum.org"},
    {"TrainingName": "Microsoft Azure Fundamentals (AZ-900)", "TrainingType": "Certification", "ValidityMonths": 0,
     "Description": "Základná certifikácia Microsoft Azure – bez exspirácie.",
     "Provider": "Microsoft Learn"},
    {"TrainingName": "Excel pre pokročilých", "TrainingType": "Optional", "ValidityMonths": 0,
     "Description": "Kontingenčné tabuľky, Power Query, pokročilé vzorce.",
     "Provider": "Learn2Code"},
    {"TrainingName": "Power BI základy", "TrainingType": "Optional", "ValidityMonths": 0,
     "Description": "Tvorba reportov a dashboardov v Power BI Desktop.",
     "Provider": "Learn2Code"},
    {"TrainingName": "Prezentačné zručnosti", "TrainingType": "Optional", "ValidityMonths": 0,
     "Description": "Soft-skills tréning prezentovania a vystupovania.",
     "Provider": "FBE Bratislava"},
    {"TrainingName": "Anglický jazyk B2 – konverzácie", "TrainingType": "Optional", "ValidityMonths": 0,
     "Description": "Polročný konverzačný kurz angličtiny pre stredne pokročilých.",
     "Provider": "Empire English School"},
]
TRAINING_BY_NAME = {t["TrainingName"]: t for t in TRAININGS}

# Povinné/bezpečnostné školenia podľa oddelenia
COMMON_MANDATORY = [
    "BOZP – vstupné školenie", "Ochrana pred požiarmi",
    "GDPR a ochrana osobných údajov", "Kybernetická bezpečnosť",
    "Etický kódex a compliance",
]
DEPT_EXTRA = {
    "OPS": ["Práca vo výškach", "Obsluha VZV (vysokozdvižný vozík)", "Prvá pomoc na pracovisku"],
    "QA":  ["ISO 9001 interný audítor", "Prvá pomoc na pracovisku"],
    "IT":  ["Scrum Master I (PSM I)", "Microsoft Azure Fundamentals (AZ-900)"],
    "SAL": ["Vodič referentského vozidla", "Prezentačné zručnosti"],
    "MKT": ["Prezentačné zručnosti"],
    "FIN": ["Excel pre pokročilých", "Power BI základy"],
    "HR":  ["Prvá pomoc na pracovisku", "Excel pre pokročilých"],
    "LEG": [],
}
OPTIONAL_POOL = ["Excel pre pokročilých", "Power BI základy",
                 "Prezentačné zručnosti", "Anglický jazyk B2 – konverzácie"]

# ------------------------------------------------------------ TrainingRecords
records: list[dict] = []
hr_admins = [hr_manager_email, email_for("Marek Novák") if "Marek Novák" in used_names else hr_manager_email]


def record_status(expiration: date | None) -> str:
    if expiration is None:
        return "Valid"
    if expiration < TODAY:
        return "Expired"
    if expiration <= TODAY + timedelta(days=EXPIRING_WINDOW_DAYS):
        return "Expiring"
    return "Valid"


def add_record(emp: dict, training_name: str, completion: date | None,
               planned: date | None = None, notes: str = "") -> None:
    training = TRAINING_BY_NAME[training_name]
    validity = training["ValidityMonths"]
    if planned is not None:
        completion_str, expiration_str, status = iso(planned), "", "Planned"
        cert = ""
    else:
        expiration = add_months(completion, validity) if validity else None
        status = record_status(expiration)
        completion_str = iso(completion)
        expiration_str = iso(expiration) if expiration else ""
        cert = (f"/sites/HRHub/Certificates/{emp['EmployeeID']}_"
                f"{strip_accents(training_name).replace(' ', '_').replace('–', '-')[:40]}.pdf")
    records.append({
        "Employee": emp["EmployeeID"],
        "Training": training_name,
        "CompletionDate": completion_str,
        "ExpirationDate": expiration_str,
        "Status": status,
        "CertificateLink": cert,
        "Notes": notes,
    })


for emp in employees:
    if emp["Status"] == "Inactive":
        # neaktívni majú len historické (exspirované) záznamy
        for tname in random.sample(COMMON_MANDATORY, 2):
            validity = TRAINING_BY_NAME[tname]["ValidityMonths"] or 12
            completion = TODAY - timedelta(days=validity * 30 + random.randint(60, 400))
            add_record(emp, tname, completion)
        continue

    hire = date.fromisoformat(emp["HireDate"])
    dept = emp["Department"]

    for tname in COMMON_MANDATORY + DEPT_EXTRA.get(dept, []):
        validity = TRAINING_BY_NAME[tname]["ValidityMonths"]
        roll = random.random()
        if roll < 0.08:
            # naplánované školenie v budúcnosti
            add_record(emp, tname, None, planned=TODAY + timedelta(days=random.randint(7, 90)),
                       notes="Naplánovaný termín cez HR.")
        elif roll < 0.20 and validity:
            # exspirované – completion tak, aby expiration < TODAY
            completion = add_months(TODAY, -validity) - timedelta(days=random.randint(10, 200))
            completion = max(completion, hire)
            add_record(emp, tname, completion, notes="Potrebné obnoviť školenie.")
        elif roll < 0.35 and validity:
            # exspiruje do 30 dní
            target_exp = TODAY + timedelta(days=random.randint(1, EXPIRING_WINDOW_DAYS))
            completion = add_months(target_exp, -validity)
            if completion >= hire:
                add_record(emp, tname, completion)
            else:
                add_record(emp, tname, max(hire, TODAY - timedelta(days=90)))
        else:
            # platné
            if validity:
                max_age_days = max(30, validity * 30 - EXPIRING_WINDOW_DAYS - 10)
                completion = TODAY - timedelta(days=random.randint(15, max_age_days))
            else:
                completion = TODAY - timedelta(days=random.randint(30, 700))
            completion = max(completion, hire)
            add_record(emp, tname, completion)

    # voliteľné školenia ~ 40 % zamestnancov
    if random.random() < 0.4:
        tname = random.choice([t for t in OPTIONAL_POOL if t not in DEPT_EXTRA.get(dept, [])] or OPTIONAL_POOL)
        completion = max(hire, TODAY - timedelta(days=random.randint(30, 500)))
        add_record(emp, tname, completion)

# -------------------------------------------------------------------- AuditLog
audit: list[dict] = []
emp_by_id = {e["EmployeeID"]: e for e in employees}

NOW = datetime.combine(TODAY, datetime.min.time())

for i, rec in enumerate(random.sample(records, 30)):
    when = NOW - timedelta(days=random.randint(0, 120),
                           hours=random.randint(-17, -8), minutes=random.randint(0, 59))
    audit.append({
        "Action": "Create",
        "EntityType": "TrainingRecord",
        "EntityID": f"TR-{records.index(rec) + 1:04d}",
        "ChangedBy": random.choice(hr_admins),
        "ChangedOn": when.isoformat(timespec="minutes"),
        "Details": (f"Pridaný záznam školenia '{rec['Training']}' pre zamestnanca "
                    f"{emp_by_id[rec['Employee']]['FullName']} ({rec['Employee']})."),
    })

for emp in random.sample(employees, 10):
    when = NOW - timedelta(days=random.randint(0, 200),
                           hours=random.randint(-17, -8), minutes=random.randint(0, 59))
    if emp["Status"] == "Inactive":
        action, details = "Update", f"Zmena stavu zamestnanca {emp['FullName']} na Inactive (soft-delete)."
    else:
        action, details = "Create", f"Založený profil zamestnanca {emp['FullName']} ({emp['EmployeeID']})."
    audit.append({
        "Action": action,
        "EntityType": "Employee",
        "EntityID": emp["EmployeeID"],
        "ChangedBy": hr_manager_email,
        "ChangedOn": when.isoformat(timespec="minutes"),
        "Details": details,
    })

audit.sort(key=lambda a: a["ChangedOn"], reverse=True)

# ---------------------------------------------------------------------- výstup
print(f"Generujem CSV do {DATA_DIR} (TODAY = {TODAY}):")
write_csv("Departments.csv", ["DepartmentName", "DepartmentCode", "Manager"], DEPARTMENTS)
write_csv("Positions.csv", ["PositionName", "Level"], POSITIONS)
write_csv("Employees.csv",
          ["EmployeeID", "FullName", "Email", "Department", "Position",
           "ManagerEmail", "HireDate", "Status", "PhotoUrl"], employees)
write_csv("TrainingsCatalog.csv",
          ["TrainingName", "TrainingType", "ValidityMonths", "Description", "Provider"], TRAININGS)
write_csv("TrainingRecords.csv",
          ["Employee", "Training", "CompletionDate", "ExpirationDate",
           "Status", "CertificateLink", "Notes"], records)
write_csv("AuditLog.csv",
          ["Action", "EntityType", "EntityID", "ChangedBy", "ChangedOn", "Details"], audit)

# štatistika stavov pre kontrolu KPI dlaždíc
from collections import Counter
print("\nStavy TrainingRecords:", dict(Counter(r["Status"] for r in records)))
print("Stavy Employees:", dict(Counter(e["Status"] for e in employees)))
