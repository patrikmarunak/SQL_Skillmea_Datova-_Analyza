import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { dataService } from '../data/mockDataService';
import { useCurrentUser } from '../auth/CurrentUserContext';
import { KpiTile, Skeleton } from '../components/common';
import type { Department, Employee, RecordView } from '../types';

export function Dashboard() {
  const navigate = useNavigate();
  const { user, role } = useCurrentUser();
  const [employees, setEmployees] = useState<Employee[] | null>(null);
  const [records, setRecords] = useState<RecordView[] | null>(null);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [search, setSearch] = useState('');

  useEffect(() => {
    dataService.getEmployees({ status: 'Active' }).then(setEmployees);
    dataService.getRecords().then(setRecords);
    dataService.getDepartments().then(setDepartments);
  }, []);

  const loading = !employees || !records;
  const expiring = records?.filter((r) => r.liveStatus === 'Expiring').length ?? 0;
  const expired = records?.filter((r) => r.liveStatus === 'Expired').length ?? 0;
  const done = records?.filter((r) => r.liveStatus === 'Valid').length ?? 0;
  const total = records?.filter((r) => r.liveStatus !== 'Planned').length ?? 0;
  const completionRate = total ? Math.round((done / total) * 100) : 0;

  const canBrowse = role !== 'employee';

  return (
    <div className="page">
      <header className="page__header">
        <h1>Vitajte{user ? `, ${user.fullName.split(' ')[0]}` : ''} 👋</h1>
        <p className="page__subtitle">Prehľad zamestnancov a stavu školení k dnešnému dňu.</p>
      </header>

      {loading ? (
        <Skeleton rows={2} height={96} />
      ) : (
        <div className="kpi-grid">
          <KpiTile
            label="Aktívni zamestnanci"
            value={employees.length}
            onClick={canBrowse ? () => navigate('/zamestnanci') : undefined}
          />
          <KpiTile
            label="Exspiruje do 30 dní"
            value={expiring}
            tone="warn"
            onClick={canBrowse ? () => navigate('/zaznamy?status=Expiring') : undefined}
          />
          <KpiTile
            label="Exspirované školenia"
            value={expired}
            tone="danger"
            onClick={canBrowse ? () => navigate('/zaznamy?status=Expired') : undefined}
          />
          <KpiTile label="Miera splnenia" value={`${completionRate} %`} />
        </div>
      )}

      {canBrowse && (
        <>
          <form
            className="searchbar"
            role="search"
            onSubmit={(e) => {
              e.preventDefault();
              navigate(`/zamestnanci?q=${encodeURIComponent(search)}`);
            }}
          >
            <input
              type="search"
              aria-label="Hľadať zamestnanca podľa mena alebo osobného čísla"
              placeholder="Hľadať zamestnanca (meno alebo osobné číslo)…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <button type="submit" className="btn btn--primary">Hľadať</button>
          </form>

          <section aria-label="Rýchle filtre podľa oddelenia">
            <h2 className="section-title">Oddelenia</h2>
            <div className="chip-row">
              {departments.map((d) => (
                <button
                  key={d.id}
                  type="button"
                  className="chip"
                  onClick={() => navigate(`/zamestnanci?dept=${d.id}`)}
                >
                  {d.name}
                </button>
              ))}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
