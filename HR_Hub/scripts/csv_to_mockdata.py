#!/usr/bin/env python3
"""
Konvertuje CSV súbory z ../data/ na TypeScript modul s mock dátami pre appku
(../app/src/data/mockData.ts). Prirodzené kľúče (DepartmentCode, EmployeeID,
TrainingName) prekladá na numerické ID – rovnako, ako by ich pridelil SharePoint.

Spustenie:  python3 csv_to_mockdata.py
"""

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
OUT = ROOT / "app" / "src" / "data" / "mockData.ts"


def read(name: str) -> list[dict]:
    with (DATA / name).open(encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


departments = [
    {"id": i + 1, "name": r["DepartmentName"], "code": r["DepartmentCode"], "manager": r["Manager"]}
    for i, r in enumerate(read("Departments.csv"))
]
dept_id = {d["code"]: d["id"] for d in departments}

positions = [
    {"id": i + 1, "name": r["PositionName"], "level": r["Level"]}
    for i, r in enumerate(read("Positions.csv"))
]
pos_id = {p["name"]: p["id"] for p in positions}

employees = [
    {
        "id": i + 1,
        "employeeId": r["EmployeeID"],
        "fullName": r["FullName"],
        "email": r["Email"],
        "departmentId": dept_id[r["Department"]],
        "positionId": pos_id[r["Position"]],
        "managerEmail": r["ManagerEmail"],
        "hireDate": r["HireDate"],
        "status": r["Status"],
        "photoUrl": r["PhotoUrl"],
    }
    for i, r in enumerate(read("Employees.csv"))
]
emp_id = {e["employeeId"]: e["id"] for e in employees}

trainings = [
    {
        "id": i + 1,
        "name": r["TrainingName"],
        "type": r["TrainingType"],
        "validityMonths": int(r["ValidityMonths"]),
        "description": r["Description"],
        "provider": r["Provider"],
    }
    for i, r in enumerate(read("TrainingsCatalog.csv"))
]
train_id = {t["name"]: t["id"] for t in trainings}

records = [
    {
        "id": i + 1,
        "employeeId": emp_id[r["Employee"]],
        "trainingId": train_id[r["Training"]],
        "completionDate": r["CompletionDate"],
        "expirationDate": r["ExpirationDate"] or None,
        "status": r["Status"],
        "certificateLink": r["CertificateLink"],
        "notes": r["Notes"],
    }
    for i, r in enumerate(read("TrainingRecords.csv"))
]

audit = [
    {
        "id": i + 1,
        "action": r["Action"],
        "entityType": r["EntityType"],
        "entityId": r["EntityID"],
        "changedBy": r["ChangedBy"],
        "changedOn": r["ChangedOn"],
        "details": r["Details"],
    }
    for i, r in enumerate(read("AuditLog.csv"))
]


def ts_array(rows: list[dict]) -> str:
    return "[\n" + ",\n".join("  " + json.dumps(r, ensure_ascii=False) for r in rows) + ",\n]"


OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(
    "// VYGENEROVANÉ SÚBOROM scripts/csv_to_mockdata.py – needitovať ručne.\n"
    "// Zdroj: HR_Hub/data/*.csv (simulované SharePoint listy).\n"
    "import type { AuditEntry, Department, Employee, Position, Training, TrainingRecord } from '../types';\n\n"
    f"export const mockDepartments: Department[] = {ts_array(departments)};\n\n"
    f"export const mockPositions: Position[] = {ts_array(positions)};\n\n"
    f"export const mockEmployees: Employee[] = {ts_array(employees)};\n\n"
    f"export const mockTrainings: Training[] = {ts_array(trainings)};\n\n"
    f"export const mockRecords: TrainingRecord[] = {ts_array(records)};\n\n"
    f"export const mockAudit: AuditEntry[] = {ts_array(audit)};\n",
    encoding="utf-8",
)
print(f"Zapísané {OUT} ({len(employees)} zamestnancov, {len(records)} záznamov).")
