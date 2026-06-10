import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { dataService } from '../data/mockDataService';
import { useCurrentUser } from '../auth/CurrentUserContext';
import { EmptyState, Skeleton } from '../components/common';
import { RecordsTable } from '../components/RecordsTable';
import { EditRecordModal } from '../components/EditRecordModal';
import type { Employee, RecordStatus, RecordView, Training } from '../types';

const STATUS_LABELS: Record<RecordStatus, string> = {
  Valid: 'Platné', Expiring: 'Čoskoro exspiruje', Expired: 'Exspirované', Planned: 'Naplánované',
};

export function TrainingRecords() {
  const [params, setParams] = useSearchParams();
  const { user, role, canEditRecordOf } = useCurrentUser();

  const status = (params.get('status') as RecordStatus | null) ?? undefined;
  const employeeId = Number(params.get('emp')) || undefined;
  const trainingId = Number(params.get('tr')) || undefined;
  const dateFrom = params.get('from') ?? '';
  const dateTo = params.get('to') ?? '';

  const [records, setRecords] = useState<RecordView[] | null>(null);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [trainings, setTrainings] = useState<Training[]>([]);
  const [editing, setEditing] = useState<RecordView | null>(null);

  useEffect(() => {
    // manažér vidí v editovateľnom zozname len svojich priamych podriadených
    const managerEmail = role === 'manager' ? user?.email : undefined;
    dataService.getEmployees(managerEmail ? { managerEmail } : {}).then(setEmployees);
    dataService.getTrainings().then(setTrainings);
  }, [role, user]);

  const load = () => {
    setRecords(null);
    dataService
      .getRecords({
        status,
        employeeId,
        trainingId,
        dateFrom: dateFrom || undefined,
        dateTo: dateTo || undefined,
        managerEmail: role === 'manager' ? user?.email : undefined,
      })
      .then(setRecords);
  };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(load, [status, employeeId, trainingId, dateFrom, dateTo, role, user]);

  const setParam = (key: string, value: string | undefined) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    setParams(next, { replace: true });
  };

  return (
    <div className="page">
      <header className="page__header page__header--actions">
        <div>
          <h1>Záznamy školení</h1>
          <p className="page__subtitle">
            {role === 'manager'
              ? 'Záznamy vašich priamych podriadených.'
              : 'Všetky záznamy školení vo firme.'}
          </p>
        </div>
        <Link to="/zaznamy/novy" className="btn btn--primary">+ Pridať záznam</Link>
      </header>

      <div className="toolbar toolbar--filters">
        <label>
          Zamestnanec
          <select value={employeeId ?? ''} onChange={(e) => setParam('emp', e.target.value || undefined)}>
            <option value="">Všetci</option>
            {employees.map((e) => <option key={e.id} value={e.id}>{e.fullName}</option>)}
          </select>
        </label>
        <label>
          Školenie
          <select value={trainingId ?? ''} onChange={(e) => setParam('tr', e.target.value || undefined)}>
            <option value="">Všetky</option>
            {trainings.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
        </label>
        <label>
          Stav
          <select value={status ?? ''} onChange={(e) => setParam('status', e.target.value || undefined)}>
            <option value="">Všetky</option>
            {Object.entries(STATUS_LABELS).map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </label>
        <label>
          Od
          <input type="date" value={dateFrom} onChange={(e) => setParam('from', e.target.value || undefined)} />
        </label>
        <label>
          Do
          <input type="date" value={dateTo} onChange={(e) => setParam('to', e.target.value || undefined)} />
        </label>
      </div>

      {!records ? (
        <Skeleton rows={6} height={44} />
      ) : records.length === 0 ? (
        <EmptyState
          title="Žiadne záznamy"
          hint="Upravte filtre alebo pridajte nový záznam školenia."
          action={<Link to="/zaznamy/novy" className="btn btn--primary">Pridať záznam</Link>}
        />
      ) : (
        <>
          <p className="muted">{records.length} záznamov</p>
          <RecordsTable
            records={records}
            showEmployee
            onEdit={setEditing}
            canEdit={(r) => canEditRecordOf(r.employee)}
          />
        </>
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
