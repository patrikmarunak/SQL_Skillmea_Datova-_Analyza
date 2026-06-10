import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { dataService } from '../data/mockDataService';
import { useCurrentUser } from '../auth/CurrentUserContext';
import { useToast } from '../components/Toast';
import { Avatar, EmptyState, Skeleton } from '../components/common';
import { EmployeeStatusBadge } from '../components/StatusBadge';
import { RecordsTable } from '../components/RecordsTable';
import { EditRecordModal } from '../components/EditRecordModal';
import { fmtDate, fmtDateTime } from '../lib/dates';
import type { AuditEntry, Department, Employee, Position, RecordView } from '../types';

type Tab = 'overview' | 'trainings' | 'certificates' | 'audit';

const TABS: { id: Tab; label: string }[] = [
  { id: 'overview', label: 'Prehľad' },
  { id: 'trainings', label: 'Školenia' },
  { id: 'certificates', label: 'Certifikáty' },
  { id: 'audit', label: 'História zmien' },
];

export function EmployeeDetail() {
  const { id } = useParams();
  const employeeId = Number(id);
  const { user, role, canEditEmployee, canEditRecordOf } = useCurrentUser();
  const toast = useToast();

  const [employee, setEmployee] = useState<Employee | null>(null);
  const [notFound, setNotFound] = useState(false);
  const [records, setRecords] = useState<RecordView[] | null>(null);
  const [audit, setAudit] = useState<AuditEntry[] | null>(null);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [positions, setPositions] = useState<Position[]>([]);
  const [tab, setTab] = useState<Tab>('overview');
  const [editing, setEditing] = useState<RecordView | null>(null);

  const load = () => {
    dataService.getEmployee(employeeId).then((e) => (e ? setEmployee(e) : setNotFound(true)));
    dataService.getRecords({ employeeId }).then(setRecords);
  };

  useEffect(() => {
    load();
    dataService.getDepartments().then(setDepartments);
    dataService.getPositions().then(setPositions);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [employeeId]);

  useEffect(() => {
    if (tab === 'audit' && employee) {
      dataService.getAuditLog().then((entries) =>
        setAudit(entries.filter(
          (a) => a.entityId === employee.employeeId || a.details.includes(employee.employeeId),
        )),
      );
    }
  }, [tab, employee]);

  if (notFound) return <div className="page"><EmptyState title="Zamestnanec sa nenašiel" /></div>;
  if (!employee) return <div className="page"><Skeleton rows={4} height={72} /></div>;

  const dept = departments.find((d) => d.id === employee.departmentId);
  const pos = positions.find((p) => p.id === employee.positionId);
  const certificates = (records ?? []).filter((r) => r.certificateLink);

  const deactivate = async () => {
    if (!user) return;
    if (!window.confirm(`Deaktivovať zamestnanca ${employee.fullName}? Záznamy ostanú zachované (soft-delete).`)) return;
    try {
      const updated = await dataService.deactivateEmployee(employee.id, user.email);
      setEmployee(updated);
      toast.show('success', 'Zamestnanec bol deaktivovaný.');
    } catch {
      toast.show('error', 'Deaktivácia sa nepodarila. Skúste to znova.');
    }
  };

  return (
    <div className="page">
      <Link to="/zamestnanci" className="back-link">← Späť na zoznam</Link>

      <header className="profile-header">
        <Avatar employee={employee} size={72} />
        <div className="profile-header__info">
          <h1>{employee.fullName}</h1>
          <p className="muted">
            {pos?.name} · {dept?.name} · {employee.employeeId}
          </p>
          <EmployeeStatusBadge status={employee.status} />
        </div>
        {canEditEmployee(employee) && employee.status === 'Active' && (
          <button type="button" className="btn btn--danger" onClick={deactivate}>
            Deaktivovať
          </button>
        )}
      </header>

      <div className="tabs" role="tablist" aria-label="Sekcie profilu">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            role="tab"
            aria-selected={tab === t.id}
            className={'tab' + (tab === t.id ? ' is-active' : '')}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <dl className="detail-grid">
          <div><dt>E-mail</dt><dd>{employee.email}</dd></div>
          <div><dt>Oddelenie</dt><dd>{dept?.name ?? '—'}</dd></div>
          <div><dt>Pozícia</dt><dd>{pos?.name ?? '—'} ({pos?.level})</dd></div>
          <div><dt>Manažér</dt><dd>{employee.managerEmail || '—'}</dd></div>
          <div><dt>Dátum nástupu</dt><dd>{fmtDate(employee.hireDate)}</dd></div>
          <div><dt>Osobné číslo</dt><dd>{employee.employeeId}</dd></div>
        </dl>
      )}

      {tab === 'trainings' && (
        !records ? <Skeleton rows={4} /> : records.length === 0 ? (
          <EmptyState
            title="Žiadne záznamy školení"
            hint="Nový záznam pridáte na obrazovke Záznamy školení."
            action={role !== 'employee' ? <Link className="btn btn--primary" to="/zaznamy/novy">Pridať záznam</Link> : undefined}
          />
        ) : (
          <RecordsTable
            records={records}
            onEdit={canEditRecordOf(employee) ? setEditing : undefined}
          />
        )
      )}

      {tab === 'certificates' && (
        certificates.length === 0 ? (
          <EmptyState
            title="Žiadne certifikáty"
            hint="Certifikáty sa nahrávajú do knižnice Certificates pri pridávaní záznamu o školení."
          />
        ) : (
          <ul className="cert-grid" aria-label="Certifikáty">
            {certificates.map((r) => (
              <li key={r.id} className="cert-card">
                <span className="cert-card__thumb" aria-hidden="true">PDF</span>
                <strong>{r.training.name}</strong>
                <span className="muted">platné do {fmtDate(r.expirationDate)}</span>
                <a href={r.certificateLink} target="_blank" rel="noreferrer">Otvoriť certifikát</a>
              </li>
            ))}
          </ul>
        )
      )}

      {tab === 'audit' && (
        !audit ? <Skeleton rows={4} height={40} /> : audit.length === 0 ? (
          <EmptyState title="Žiadna história" hint="Zmeny profilu a školení sa zapisujú do listu AuditLog." />
        ) : (
          <ul className="audit-list">
            {audit.map((a) => (
              <li key={a.id}>
                <span className="audit-list__time">{fmtDateTime(a.changedOn)}</span>
                <span className="audit-list__action">{a.action}</span>
                <span>{a.details}</span>
                <span className="muted">{a.changedBy}</span>
              </li>
            ))}
          </ul>
        )
      )}

      {editing && (
        <EditRecordModal
          record={editing}
          onClose={() => setEditing(null)}
          onSaved={() => { setEditing(null); load(); }}
        />
      )}
    </div>
  );
}
