import type {
  AuditEntry, Department, Employee, Position, RecordView, Training, TrainingRecord,
} from '../types';
import type { DataService, EmployeeQuery, NewTrainingRecord, RecordQuery } from './dataService';
import { addMonths, liveStatus, todayIso } from '../lib/dates';
import {
  mockAudit, mockDepartments, mockEmployees, mockPositions, mockRecords, mockTrainings,
} from './mockData';

/** Simulovaná latencia siete, nech vidno loading skeletony. */
const LATENCY_MS = 250;
const delay = <T,>(value: T): Promise<T> =>
  new Promise((resolve) => setTimeout(() => resolve(value), LATENCY_MS));

function startsWith(value: string, prefix: string): boolean {
  return value.toLocaleLowerCase('sk').startsWith(prefix.toLocaleLowerCase('sk'));
}

/**
 * In-memory implementácia nad simulovanými dátami z SharePoint listov.
 * Mutácie zapisujú do AuditLogu rovnako, ako to bude robiť produkčná
 * implementácia cez SharePoint konektor.
 */
export class MockDataService implements DataService {
  private departments = [...mockDepartments];
  private positions = [...mockPositions];
  private employees = mockEmployees.map((e) => ({ ...e }));
  private trainings = mockTrainings.map((t) => ({ ...t }));
  private records = mockRecords.map((r) => ({ ...r }));
  private audit = mockAudit.map((a) => ({ ...a }));

  getDepartments(): Promise<Department[]> {
    return delay(this.departments);
  }

  getPositions(): Promise<Position[]> {
    return delay(this.positions);
  }

  getEmployees(query: EmployeeQuery = {}): Promise<Employee[]> {
    let result = this.employees;
    if (query.managerEmail) result = result.filter((e) => e.managerEmail === query.managerEmail);
    if (query.departmentId) result = result.filter((e) => e.departmentId === query.departmentId);
    if (query.status) result = result.filter((e) => e.status === query.status);
    if (query.search) {
      const q = query.search;
      result = result.filter((e) => startsWith(e.fullName, q) || startsWith(e.employeeId, q));
    }
    return delay([...result].sort((a, b) => a.fullName.localeCompare(b.fullName, 'sk')));
  }

  getEmployee(id: number): Promise<Employee | undefined> {
    return delay(this.employees.find((e) => e.id === id));
  }

  deactivateEmployee(id: number, changedBy: string): Promise<Employee> {
    const emp = this.employees.find((e) => e.id === id);
    if (!emp) return Promise.reject(new Error('Zamestnanec neexistuje.'));
    emp.status = 'Inactive';
    this.log('Update', 'Employee', emp.employeeId, changedBy,
      `Zmena stavu zamestnanca ${emp.fullName} na Inactive (soft-delete).`);
    return delay({ ...emp });
  }

  getTrainings(): Promise<Training[]> {
    return delay([...this.trainings].sort((a, b) => a.name.localeCompare(b.name, 'sk')));
  }

  saveTraining(training: Omit<Training, 'id'> & { id?: number }, changedBy: string): Promise<Training> {
    if (training.id) {
      const existing = this.trainings.find((t) => t.id === training.id);
      if (!existing) return Promise.reject(new Error('Školenie neexistuje.'));
      Object.assign(existing, training);
      this.log('Update', 'TrainingCatalog', String(existing.id), changedBy,
        `Upravené školenie '${existing.name}'.`);
      return delay({ ...existing });
    }
    const created: Training = { ...training, id: this.nextId(this.trainings) };
    this.trainings.push(created);
    this.log('Create', 'TrainingCatalog', String(created.id), changedBy,
      `Pridané školenie '${created.name}' do katalógu.`);
    return delay({ ...created });
  }

  getRecords(query: RecordQuery = {}): Promise<RecordView[]> {
    let result = this.records;
    if (query.employeeId) result = result.filter((r) => r.employeeId === query.employeeId);
    if (query.trainingId) result = result.filter((r) => r.trainingId === query.trainingId);
    if (query.dateFrom) result = result.filter((r) => r.completionDate >= query.dateFrom!);
    if (query.dateTo) result = result.filter((r) => r.completionDate <= query.dateTo!);
    if (query.managerEmail) {
      const reportIds = new Set(
        this.employees.filter((e) => e.managerEmail === query.managerEmail).map((e) => e.id),
      );
      result = result.filter((r) => reportIds.has(r.employeeId));
    }
    let views = result.map((r) => this.toView(r));
    if (query.status) views = views.filter((v) => v.liveStatus === query.status);
    views.sort((a, b) => b.completionDate.localeCompare(a.completionDate));
    return delay(views);
  }

  addRecord(input: NewTrainingRecord, changedBy: string): Promise<RecordView> {
    const training = this.trainings.find((t) => t.id === input.trainingId);
    const employee = this.employees.find((e) => e.id === input.employeeId);
    if (!training || !employee) return Promise.reject(new Error('Neplatný zamestnanec alebo školenie.'));

    // ExpirationDate = DateAdd(CompletionDate, ValidityMonths, Months)
    const expiration = !input.planned && training.validityMonths > 0
      ? addMonths(input.completionDate, training.validityMonths)
      : null;
    const record: TrainingRecord = {
      id: this.nextId(this.records),
      employeeId: input.employeeId,
      trainingId: input.trainingId,
      completionDate: input.completionDate,
      expirationDate: expiration,
      status: input.planned ? 'Planned' : 'Valid',
      certificateLink: input.certificateFileName
        ? `/sites/HRHub/Certificates/${employee.employeeId}_${input.certificateFileName}`
        : '',
      notes: input.notes ?? '',
    };
    record.status = liveStatus(record);
    this.records.push(record);
    this.log('Create', 'TrainingRecord', `TR-${String(record.id).padStart(4, '0')}`, changedBy,
      `Pridaný záznam školenia '${training.name}' pre zamestnanca ${employee.fullName} (${employee.employeeId}).`);
    return delay(this.toView(record));
  }

  updateRecord(
    id: number,
    changes: Partial<Pick<TrainingRecord, 'completionDate' | 'status' | 'notes' | 'certificateLink'>>,
    changedBy: string,
  ): Promise<RecordView> {
    const record = this.records.find((r) => r.id === id);
    if (!record) return Promise.reject(new Error('Záznam neexistuje.'));
    const training = this.trainings.find((t) => t.id === record.trainingId)!;
    Object.assign(record, changes);
    if (changes.completionDate) {
      record.expirationDate = training.validityMonths > 0
        ? addMonths(changes.completionDate, training.validityMonths)
        : null;
      if (record.status === 'Planned' && changes.completionDate <= todayIso()) record.status = 'Valid';
      record.status = liveStatus(record);
    }
    const employee = this.employees.find((e) => e.id === record.employeeId)!;
    this.log('Update', 'TrainingRecord', `TR-${String(record.id).padStart(4, '0')}`, changedBy,
      `Upravený záznam školenia '${training.name}' zamestnanca ${employee.fullName}.`);
    return delay(this.toView(record));
  }

  getAuditLog(filter: { entityType?: string; entityId?: string } = {}): Promise<AuditEntry[]> {
    let result = this.audit;
    if (filter.entityType) result = result.filter((a) => a.entityType === filter.entityType);
    if (filter.entityId) result = result.filter((a) => a.entityId === filter.entityId);
    return delay([...result].sort((a, b) => b.changedOn.localeCompare(a.changedOn)));
  }

  private toView(record: TrainingRecord): RecordView {
    return {
      ...record,
      employee: this.employees.find((e) => e.id === record.employeeId)!,
      training: this.trainings.find((t) => t.id === record.trainingId)!,
      liveStatus: liveStatus(record),
    };
  }

  private nextId(rows: { id: number }[]): number {
    return rows.reduce((max, r) => Math.max(max, r.id), 0) + 1;
  }

  private log(action: string, entityType: string, entityId: string, changedBy: string, details: string) {
    this.audit.push({
      id: this.nextId(this.audit),
      action,
      entityType,
      entityId,
      changedBy,
      changedOn: new Date().toISOString(),
      details,
    });
  }
}

/** Jedna zdieľaná inštancia pre celú appku (stav prežíva navigáciu medzi obrazovkami). */
export const dataService = new MockDataService();
