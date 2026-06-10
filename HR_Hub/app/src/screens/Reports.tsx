import { useEffect, useMemo, useState } from 'react';
import { dataService } from '../data/mockDataService';
import { Skeleton } from '../components/common';
import type { Department, Employee, RecordView } from '../types';

interface BarRow { label: string; value: number; max: number; suffix?: string; tone?: string; }

function BarChart({ title, rows }: { title: string; rows: BarRow[] }) {
  return (
    <section className="chart-card" aria-label={title}>
      <h2 className="section-title">{title}</h2>
      {rows.length === 0 ? (
        <p className="muted">Žiadne dáta.</p>
      ) : (
        <ul className="bar-chart">
          {rows.map((row) => (
            <li key={row.label}>
              <span className="bar-chart__label">{row.label}</span>
              <span className="bar-chart__track">
                <span
                  className={'bar-chart__fill' + (row.tone ? ` bar-chart__fill--${row.tone}` : '')}
                  style={{ width: `${row.max ? Math.max(2, (row.value / row.max) * 100) : 0}%` }}
                />
              </span>
              <span className="bar-chart__value">{row.value}{row.suffix ?? ''}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export function Reports() {
  const [records, setRecords] = useState<RecordView[] | null>(null);
  const [employees, setEmployees] = useState<Employee[] | null>(null);
  const [departments, setDepartments] = useState<Department[]>([]);

  useEffect(() => {
    dataService.getRecords().then(setRecords);
    dataService.getEmployees({ status: 'Active' }).then(setEmployees);
    dataService.getDepartments().then(setDepartments);
  }, []);

  const loading = !records || !employees;

  const { byDept, expiringByDept, complianceByDept } = useMemo(() => {
    if (loading) return { byDept: [], expiringByDept: [], complianceByDept: [] };
    const deptOf = new Map(employees.map((e) => [e.id, e.departmentId]));

    const counts = new Map<number, number>();
    const expiring = new Map<number, number>();
    const compliant = new Map<number, number>();
    const totals = new Map<number, number>();

    for (const r of records) {
      const dept = deptOf.get(r.employeeId);
      if (!dept) continue; // záznamy neaktívnych zamestnancov
      counts.set(dept, (counts.get(dept) ?? 0) + 1);
      if (r.liveStatus === 'Expiring') expiring.set(dept, (expiring.get(dept) ?? 0) + 1);
      if (r.liveStatus !== 'Planned') {
        totals.set(dept, (totals.get(dept) ?? 0) + 1);
        if (r.liveStatus !== 'Expired') compliant.set(dept, (compliant.get(dept) ?? 0) + 1);
      }
    }

    const named = (m: Map<number, number>) =>
      departments
        .map((d) => ({ label: d.name, value: m.get(d.id) ?? 0 }))
        .sort((a, b) => b.value - a.value);

    const countRows = named(counts);
    const maxCount = Math.max(...countRows.map((r) => r.value), 1);
    const expRows = named(expiring);
    const maxExp = Math.max(...expRows.map((r) => r.value), 1);

    const compRows = departments
      .map((d) => {
        const total = totals.get(d.id) ?? 0;
        const ok = compliant.get(d.id) ?? 0;
        return { label: d.name, value: total ? Math.round((ok / total) * 100) : 100 };
      })
      .sort((a, b) => a.value - b.value);

    return {
      byDept: countRows.map((r) => ({ ...r, max: maxCount })),
      expiringByDept: expRows.map((r) => ({ ...r, max: maxExp, tone: 'warn' })),
      complianceByDept: compRows.map((r) => ({
        ...r,
        max: 100,
        suffix: ' %',
        tone: r.value >= 90 ? 'ok' : r.value >= 75 ? 'warn' : 'danger',
      })),
    };
  }, [loading, records, employees, departments]);

  return (
    <div className="page">
      <header className="page__header">
        <h1>Reporty</h1>
        <p className="page__subtitle">Prehľad školení podľa oddelení a miera súladu jednotlivých tímov.</p>
      </header>

      {loading ? (
        <Skeleton rows={3} height={140} />
      ) : (
        <div className="chart-grid">
          <BarChart title="Počet školení podľa oddelenia" rows={byDept} />
          <BarChart title="Exspiruje do 30 dní" rows={expiringByDept} />
          <BarChart title="Miera súladu podľa oddelenia (% neexspirovaných)" rows={complianceByDept} />
        </div>
      )}
    </div>
  );
}
