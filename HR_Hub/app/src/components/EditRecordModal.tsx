import { useState } from 'react';
import type { RecordView } from '../types';
import { dataService } from '../data/mockDataService';
import { useCurrentUser } from '../auth/CurrentUserContext';
import { useToast } from './Toast';
import { Field, Modal } from './common';
import { addMonths, fmtDate, todayIso } from '../lib/dates';

interface Props {
  record: RecordView;
  onClose: () => void;
  onSaved: () => void;
}

export function EditRecordModal({ record, onClose, onSaved }: Props) {
  const { user } = useCurrentUser();
  const toast = useToast();
  const [completionDate, setCompletionDate] = useState(record.completionDate);
  const [notes, setNotes] = useState(record.notes);
  const [certName, setCertName] = useState('');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  const expirationPreview = record.training.validityMonths > 0
    ? addMonths(completionDate, record.training.validityMonths)
    : null;

  const save = async () => {
    if (!completionDate) {
      setError('Zadajte dátum absolvovania.');
      return;
    }
    if (completionDate > todayIso() && record.status !== 'Planned') {
      setError('Dátum absolvovania nemôže byť v budúcnosti.');
      return;
    }
    setSaving(true);
    try {
      await dataService.updateRecord(
        record.id,
        {
          completionDate,
          notes,
          ...(certName
            ? { certificateLink: `/sites/HRHub/Certificates/${record.employee.employeeId}_${certName}` }
            : {}),
        },
        user?.email ?? '',
      );
      toast.show('success', 'Záznam školenia bol uložený.');
      onSaved();
    } catch {
      toast.show('error', 'Uloženie sa nepodarilo. Skúste to znova.');
      setSaving(false);
    }
  };

  return (
    <Modal title={`Upraviť záznam – ${record.training.name}`} onClose={onClose}>
      <p className="muted">{record.employee.fullName} ({record.employee.employeeId})</p>

      <Field label="Dátum absolvovania" htmlFor="edit-completion" error={error}>
        <input
          id="edit-completion"
          type="date"
          value={completionDate}
          onChange={(e) => { setCompletionDate(e.target.value); setError(''); }}
        />
      </Field>

      <p className="muted">
        Platnosť do: <strong>{expirationPreview ? fmtDate(expirationPreview) : 'neobmedzená'}</strong>
        {record.training.validityMonths > 0 && ` (automaticky +${record.training.validityMonths} mes.)`}
      </p>

      <Field label="Certifikát (PDF do knižnice Certificates)" htmlFor="edit-cert">
        <input
          id="edit-cert"
          type="file"
          accept="application/pdf"
          onChange={(e) => setCertName(e.target.files?.[0]?.name ?? '')}
        />
      </Field>

      <Field label="Poznámky" htmlFor="edit-notes">
        <textarea id="edit-notes" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />
      </Field>

      <footer className="modal__footer">
        <button type="button" className="btn" onClick={onClose}>Zrušiť</button>
        <button type="button" className="btn btn--primary" onClick={save} disabled={saving}>
          {saving ? 'Ukladám…' : 'Uložiť'}
        </button>
      </footer>
    </Modal>
  );
}
