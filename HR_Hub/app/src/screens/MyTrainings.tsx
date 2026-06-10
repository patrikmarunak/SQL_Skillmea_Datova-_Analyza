import { useEffect, useState } from 'react';
import { dataService } from '../data/mockDataService';
import { useCurrentUser } from '../auth/CurrentUserContext';
import { EmptyState, Skeleton } from '../components/common';
import { RecordsTable } from '../components/RecordsTable';
import { daysUntil, fmtDate } from '../lib/dates';
import type { RecordView } from '../types';

export function MyTrainings() {
  const { user } = useCurrentUser();
  const [records, setRecords] = useState<RecordView[] | null>(null);

  useEffect(() => {
    if (!user) return;
    setRecords(null);
    dataService.getRecords({ employeeId: user.id }).then(setRecords);
  }, [user]);

  if (!user) return <div className="page"><Skeleton rows={3} /></div>;

  const expiring = (records ?? []).filter((r) => r.liveStatus === 'Expiring');
  const expired = (records ?? []).filter((r) => r.liveStatus === 'Expired');

  return (
    <div className="page">
      <header className="page__header">
        <h1>Moje školenia</h1>
        <p className="page__subtitle">Vaše záznamy školení, upozornenia na exspiráciu a certifikáty na stiahnutie.</p>
      </header>

      {expired.length > 0 && (
        <div className="banner banner--danger" role="alert">
          <strong>Máte {expired.length} exspirované školenia.</strong>{' '}
          Kontaktujte HR oddelenie a dohodnite si náhradný termín:{' '}
          {expired.map((r) => r.training.name).join(', ')}.
        </div>
      )}
      {expiring.length > 0 && (
        <div className="banner banner--warn" role="alert">
          <strong>Čoskoro vám exspiruje {expiring.length} školení:</strong>{' '}
          {expiring
            .map((r) => `${r.training.name} (${fmtDate(r.expirationDate)}, o ${daysUntil(r.expirationDate!)} dní)`)
            .join(', ')}
        </div>
      )}

      {!records ? (
        <Skeleton rows={5} height={44} />
      ) : records.length === 0 ? (
        <EmptyState
          title="Zatiaľ žiadne školenia"
          hint="Keď absolvujete školenie, HR alebo váš manažér ho sem zaznamená aj s certifikátom."
        />
      ) : (
        <RecordsTable records={records} />
      )}
    </div>
  );
}
