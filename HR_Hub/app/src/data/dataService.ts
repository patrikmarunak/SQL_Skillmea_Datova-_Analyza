import type {
  AuditEntry, Department, Employee, EmployeeStatus, Position,
  RecordStatus, RecordView, Training, TrainingRecord,
} from '../types';

/**
 * Filtre zodpovedajú delegovateľným SharePoint dotazom: rovnosť na indexovaných
 * stĺpcoch + StartsWith na FullName/EmployeeID. Žiadne plné in-memory filtrovanie
 * nad neindexovanými stĺpcami, aby reálna implementácia ostala pod limitom 5000.
 */
export interface EmployeeQuery {
  search?: string;          // StartsWith(FullName) alebo StartsWith(EmployeeID)
  departmentId?: number;    // rovnosť na lookup (indexovaný)
  status?: EmployeeStatus;  // rovnosť na indexovanom Choice
  managerEmail?: string;    // rovnosť na indexovanom ManagerEmail (rola Manager)
}

export interface RecordQuery {
  employeeId?: number;
  trainingId?: number;
  status?: RecordStatus;    // porovnáva sa live stav k dnešku
  dateFrom?: string;        // CompletionDate >=
  dateTo?: string;          // CompletionDate <=
  managerEmail?: string;    // len záznamy priamych podriadených
}

export interface NewTrainingRecord {
  employeeId: number;
  trainingId: number;
  completionDate: string;
  planned: boolean;
  certificateFileName?: string;
  notes?: string;
}

export interface DataService {
  getDepartments(): Promise<Department[]>;
  getPositions(): Promise<Position[]>;

  getEmployees(query?: EmployeeQuery): Promise<Employee[]>;
  getEmployee(id: number): Promise<Employee | undefined>;
  /** Soft-delete: nastaví Status = Inactive, nikdy nemaže. */
  deactivateEmployee(id: number, changedBy: string): Promise<Employee>;

  getTrainings(): Promise<Training[]>;
  saveTraining(training: Omit<Training, 'id'> & { id?: number }, changedBy: string): Promise<Training>;

  getRecords(query?: RecordQuery): Promise<RecordView[]>;
  addRecord(input: NewTrainingRecord, changedBy: string): Promise<RecordView>;
  updateRecord(
    id: number,
    changes: Partial<Pick<TrainingRecord, 'completionDate' | 'status' | 'notes' | 'certificateLink'>>,
    changedBy: string,
  ): Promise<RecordView>;

  getAuditLog(filter?: { entityType?: string; entityId?: string }): Promise<AuditEntry[]>;
}
