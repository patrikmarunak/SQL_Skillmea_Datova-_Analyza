// Dátový model zodpovedá SharePoint listom na site "HR Hub".
// Interné názvy stĺpcov ostávajú v angličtine, UI je v slovenčine.

export type EmployeeStatus = 'Active' | 'Inactive';
export type TrainingType = 'Mandatory' | 'Optional' | 'Certification' | 'Safety';
export type RecordStatus = 'Valid' | 'Expiring' | 'Expired' | 'Planned';
export type Role = 'admin' | 'manager' | 'employee';

export interface Department {
  id: number;
  name: string;
  code: string;
  manager: string;
}

export interface Position {
  id: number;
  name: string;
  level: string;
}

export interface Employee {
  id: number;
  employeeId: string;
  fullName: string;
  email: string;
  departmentId: number;
  positionId: number;
  managerEmail: string;
  hireDate: string; // ISO date
  status: EmployeeStatus;
  photoUrl: string;
}

export interface Training {
  id: number;
  name: string;
  type: TrainingType;
  validityMonths: number; // 0 = neexspiruje
  description: string;
  provider: string;
}

export interface TrainingRecord {
  id: number;
  employeeId: number;
  trainingId: number;
  completionDate: string; // pri Planned ide o plánovaný termín
  expirationDate: string | null;
  status: RecordStatus;
  certificateLink: string;
  notes: string;
}

export interface AuditEntry {
  id: number;
  action: string;
  entityType: string;
  entityId: string;
  changedBy: string;
  changedOn: string; // ISO datetime
  details: string;
}

/** Záznam školenia obohatený o súvisiace entity (join cez lookup stĺpce). */
export interface RecordView extends TrainingRecord {
  employee: Employee;
  training: Training;
  /** Stav prepočítaný k dnešnému dátumu (uložený Status môže zastarať). */
  liveStatus: RecordStatus;
}
