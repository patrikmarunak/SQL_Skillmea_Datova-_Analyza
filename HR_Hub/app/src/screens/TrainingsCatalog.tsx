import { useEffect, useState } from 'react';
import { dataService } from '../data/mockDataService';
import { useCurrentUser } from '../auth/CurrentUserContext';
import { useToast } from '../components/Toast';
import { EmptyState, Field, Modal, Skeleton } from '../components/common';
import type { Training, TrainingType } from '../types';

const TYPE_LABELS: Record<TrainingType, string> = {
  Mandatory: 'Povinné',
  Optional: 'Voliteľné',
  Certification: 'Certifikácia',
  Safety: 'Bezpečnosť',
};

const EMPTY_FORM = { name: '', type: 'Mandatory' as TrainingType, validityMonths: 12, description: '', provider: '' };

export function TrainingsCatalog() {
  const { user, role } = useCurrentUser();
  const toast = useToast();
  const [trainings, setTrainings] = useState<Training[] | null>(null);
  const [editing, setEditing] = useState<(typeof EMPTY_FORM & { id?: number }) | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);

  const load = () => dataService.getTrainings().then(setTrainings);
  useEffect(() => { load(); }, []);

  const isAdmin = role === 'admin';

  const save = async () => {
    if (!editing) return;
    const errs: Record<string, string> = {};
    if (!editing.name.trim()) errs.name = 'Zadajte názov školenia.';
    if (editing.validityMonths < 0) errs.validity = 'Platnosť nemôže byť záporná.';
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setSaving(true);
    try {
      await dataService.saveTraining(
        {
          id: editing.id,
          name: editing.name.trim(),
          type: editing.type,
          validityMonths: editing.validityMonths,
          description: editing.description,
          provider: editing.provider,
        },
        user?.email ?? '',
      );
      toast.show('success', editing.id ? 'Školenie bolo upravené.' : 'Školenie bolo pridané do katalógu.');
      setEditing(null);
      load();
    } catch {
      toast.show('error', 'Uloženie sa nepodarilo. Skúste to znova.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="page">
      <header className="page__header page__header--actions">
        <div>
          <h1>Katalóg školení</h1>
          <p className="page__subtitle">Dostupné typy školení, platnosť a poskytovatelia.</p>
        </div>
        {isAdmin && (
          <button type="button" className="btn btn--primary" onClick={() => { setEditing({ ...EMPTY_FORM }); setErrors({}); }}>
            + Pridať školenie
          </button>
        )}
      </header>

      {!trainings ? (
        <Skeleton rows={5} height={64} />
      ) : trainings.length === 0 ? (
        <EmptyState title="Katalóg je prázdny" hint="Pridajte prvé školenie tlačidlom vyššie." />
      ) : (
        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th scope="col">Názov</th>
                <th scope="col">Typ</th>
                <th scope="col">Platnosť</th>
                <th scope="col">Poskytovateľ</th>
                {isAdmin && <th scope="col"><span className="visually-hidden">Akcie</span></th>}
              </tr>
            </thead>
            <tbody>
              {trainings.map((t) => (
                <tr key={t.id}>
                  <td>
                    <strong>{t.name}</strong>
                    {t.description && <div className="muted">{t.description}</div>}
                  </td>
                  <td><span className={`type-tag type-tag--${t.type.toLowerCase()}`}>{TYPE_LABELS[t.type]}</span></td>
                  <td>{t.validityMonths > 0 ? `${t.validityMonths} mes.` : 'neobmedzená'}</td>
                  <td>{t.provider}</td>
                  {isAdmin && (
                    <td>
                      <button
                        type="button"
                        className="btn btn--ghost"
                        onClick={() => {
                          setEditing({
                            id: t.id, name: t.name, type: t.type,
                            validityMonths: t.validityMonths, description: t.description, provider: t.provider,
                          });
                          setErrors({});
                        }}
                      >
                        Upraviť
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {editing && (
        <Modal title={editing.id ? 'Upraviť školenie' : 'Nové školenie'} onClose={() => setEditing(null)}>
          <Field label="Názov školenia" htmlFor="tr-name" error={errors.name}>
            <input
              id="tr-name"
              type="text"
              value={editing.name}
              onChange={(e) => setEditing({ ...editing, name: e.target.value })}
            />
          </Field>
          <Field label="Typ" htmlFor="tr-type">
            <select
              id="tr-type"
              value={editing.type}
              onChange={(e) => setEditing({ ...editing, type: e.target.value as TrainingType })}
            >
              {Object.entries(TYPE_LABELS).map(([value, label]) => (
                <option key={value} value={value}>{label}</option>
              ))}
            </select>
          </Field>
          <Field label="Platnosť v mesiacoch (0 = neobmedzená)" htmlFor="tr-validity" error={errors.validity}>
            <input
              id="tr-validity"
              type="number"
              min={0}
              value={editing.validityMonths}
              onChange={(e) => setEditing({ ...editing, validityMonths: Number(e.target.value) })}
            />
          </Field>
          <Field label="Poskytovateľ" htmlFor="tr-provider">
            <input
              id="tr-provider"
              type="text"
              value={editing.provider}
              onChange={(e) => setEditing({ ...editing, provider: e.target.value })}
            />
          </Field>
          <Field label="Popis" htmlFor="tr-desc">
            <textarea
              id="tr-desc"
              rows={3}
              value={editing.description}
              onChange={(e) => setEditing({ ...editing, description: e.target.value })}
            />
          </Field>
          <footer className="modal__footer">
            <button type="button" className="btn" onClick={() => setEditing(null)}>Zrušiť</button>
            <button type="button" className="btn btn--primary" onClick={save} disabled={saving}>
              {saving ? 'Ukladám…' : 'Uložiť'}
            </button>
          </footer>
        </Modal>
      )}
    </div>
  );
}
