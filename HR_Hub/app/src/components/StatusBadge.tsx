import type { EmployeeStatus, RecordStatus } from '../types';

const RECORD_LABELS: Record<RecordStatus, string> = {
  Valid: 'Platné',
  Expiring: 'Čoskoro exspiruje',
  Expired: 'Exspirované',
  Planned: 'Naplánované',
};

export function RecordStatusBadge({ status }: { status: RecordStatus }) {
  return <span className={`badge badge--${status.toLowerCase()}`}>{RECORD_LABELS[status]}</span>;
}

const EMPLOYEE_LABELS: Record<EmployeeStatus, string> = {
  Active: 'Aktívny',
  Inactive: 'Neaktívny',
};

export function EmployeeStatusBadge({ status }: { status: EmployeeStatus }) {
  return (
    <span className={`badge ${status === 'Active' ? 'badge--valid' : 'badge--planned'}`}>
      {EMPLOYEE_LABELS[status]}
    </span>
  );
}
