import { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { dataService } from '../data/mockDataService';
import { EmployeeStatusBadge } from '../components/StatusBadge';
import { Avatar, EmptyState, Skeleton } from '../components/common';
import type { Department, Employee, EmployeeStatus, Position } from '../types';

export function Employees() {
  const [params, setParams] = useSearchParams();
  const search = params.get('q') ?? '';
  const deptFilter = Number(params.get('dept')) || undefined;
  const statusFilter = (params.get('status') as EmployeeStatus | null) ?? undefined;

  const [employees, setEmployees] = useState<Employee[] | null>(null);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [positions, setPositions] = useState<Position[]>([]);

  useEffect(() => {
    dataService.getDepartments().then(setDepartments);
    dataService.getPositions().then(setPositions);
  }, []);

  useEffect(() => {
    setEmployees(null);
    // delegovateľný dotaz: StartsWith + rovnosť na indexovaných stĺpcoch
    dataService
      .getEmployees({ search: search || undefined, departmentId: deptFilter, status: statusFilter })
      .then(setEmployees);
  }, [search, deptFilter, statusFilter]);

  const deptName = useMemo(
    () => new Map(departments.map((d) => [d.id, d.name])),
    [departments],
  );
  const posName = useMemo(
    () => new Map(positions.map((p) => [p.id, p.name])),
    [positions],
  );

  const setParam = (key: string, value: string | undefined) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    setParams(next, { replace: true });
  };

  return (
    <div className="page">
      <header className="page__header">
        <h1>Zamestnanci</h1>
        <p className="page__subtitle">Vyhľadávanie podľa mena alebo osobného čísla, filtre podľa oddelenia a stavu.</p>
      </header>

      <div className="toolbar">
        <input
          type="search"
          aria-label="Hľadať zamestnanca"
          placeholder="Hľadať (začiatok mena alebo EMP…)"
          value={search}
          onChange={(e) => setParam('q', e.target.value || undefined)}
        />
      </div>

      <div className="chip-row" role="group" aria-label="Filter podľa oddelenia">
        <button
          type="button"
          className={'chip' + (!deptFilter ? ' is-active' : '')}
          onClick={() => setParam('dept', undefined)}
        >
          Všetky oddelenia
        </button>
        {departments.map((d) => (
          <button
            key={d.id}
            type="button"
            className={'chip' + (deptFilter === d.id ? ' is-active' : '')}
            onClick={() => setParam('dept', String(d.id))}
          >
            {d.name}
          </button>
        ))}
      </div>
      <div className="chip-row" role="group" aria-label="Filter podľa stavu">
        {([undefined, 'Active', 'Inactive'] as const).map((s) => (
          <button
            key={s ?? 'all'}
            type="button"
            className={'chip' + (statusFilter === s || (!statusFilter && !s) ? ' is-active' : '')}
            onClick={() => setParam('status', s)}
          >
            {s === 'Active' ? 'Aktívni' : s === 'Inactive' ? 'Neaktívni' : 'Všetky stavy'}
          </button>
        ))}
      </div>

      {!employees ? (
        <Skeleton rows={5} height={64} />
      ) : employees.length === 0 ? (
        <EmptyState
          title="Žiadni zamestnanci"
          hint="Skúste zmeniť hľadaný výraz alebo zrušiť filtre – hľadá sa podľa začiatku mena alebo osobného čísla."
        />
      ) : (
        <ul className="card-list" aria-label="Zoznam zamestnancov">
          {employees.map((e) => (
            <li key={e.id}>
              <Link className="employee-card" to={`/zamestnanci/${e.id}`}>
                <Avatar employee={e} size={44} />
                <div className="employee-card__info">
                  <strong>{e.fullName}</strong>
                  <span className="muted">
                    {posName.get(e.positionId)} · {deptName.get(e.departmentId)} · {e.employeeId}
                  </span>
                </div>
                <EmployeeStatusBadge status={e.status} />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
