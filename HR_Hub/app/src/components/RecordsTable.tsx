import type { RecordView } from '../types';
import { fmtDate } from '../lib/dates';
import { RecordStatusBadge } from './StatusBadge';

interface Props {
  records: RecordView[];
  showEmployee?: boolean;
  /** Ak je zadané, zobrazí tlačidlo Upraviť pre záznamy, kde to rola dovoľuje. */
  onEdit?: (record: RecordView) => void;
  canEdit?: (record: RecordView) => boolean;
}

export function RecordsTable({ records, showEmployee = false, onEdit, canEdit }: Props) {
  return (
    <div className="table-wrap">
      <table className="table">
        <thead>
          <tr>
            {showEmployee && <th scope="col">Zamestnanec</th>}
            <th scope="col">Školenie</th>
            <th scope="col">Absolvované</th>
            <th scope="col">Platnosť do</th>
            <th scope="col">Stav</th>
            <th scope="col">Certifikát</th>
            {onEdit && <th scope="col"><span className="visually-hidden">Akcie</span></th>}
          </tr>
        </thead>
        <tbody>
          {records.map((r) => (
            <tr key={r.id} className={`row--${r.liveStatus.toLowerCase()}`}>
              {showEmployee && <td>{r.employee.fullName}</td>}
              <td>{r.training.name}</td>
              <td>{r.liveStatus === 'Planned' ? `plán: ${fmtDate(r.completionDate)}` : fmtDate(r.completionDate)}</td>
              <td>{fmtDate(r.expirationDate)}</td>
              <td><RecordStatusBadge status={r.liveStatus} /></td>
              <td>
                {r.certificateLink ? (
                  <a href={r.certificateLink} target="_blank" rel="noreferrer">PDF</a>
                ) : (
                  <span className="muted">—</span>
                )}
              </td>
              {onEdit && (
                <td>
                  {(!canEdit || canEdit(r)) && (
                    <button type="button" className="btn btn--ghost" onClick={() => onEdit(r)}>
                      Upraviť
                    </button>
                  )}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
