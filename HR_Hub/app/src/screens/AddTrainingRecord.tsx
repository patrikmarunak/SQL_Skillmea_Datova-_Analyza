import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { dataService } from '../data/mockDataService';
import { useCurrentUser } from '../auth/CurrentUserContext';
import { useToast } from '../components/Toast';
import { Field } from '../components/common';
import { addMonths, fmtDate, todayIso } from '../lib/dates';
import type { Employee, Training } from '../types';

export function AddTrainingRecord() {
  const navigate = useNavigate();
  const { user, role } = useCurrentUser();
  const toast = useToast();

  const [trainings, setTrainings] = useState<Training[]>([]);
  const [selected, setSelected] = useState<Employee[]>([]);
  const [query, setQuery] = useState('');
  const [suggestions, setSuggestions] = useState<Employee[]>([]);
  const [open, setOpen] = useState(false);
  const [trainingId, setTrainingId] = useState<number>(0);
  const [completionDate, setCompletionDate] = useState(todayIso());
  const [planned, setPlanned] = useState(false);
  const [certFile, setCertFile] = useState('');
  const [notes, setNotes] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const debounce = useRef<number>();

  useEffect(() => { dataService.getTrainings().then(setTrainings); }, []);

  // Delegovateľné vyhľadávanie: StartsWith na FullName/EmployeeID,
  // manažér vyberá len spomedzi svojich priamych podriadených.
  useEffect(() => {
    window.clearTimeout(debounce.current);
    if (!query.trim()) { setSuggestions([]); return; }
    debounce.current = window.setTimeout(() => {
      dataService
        .getEmployees({
          search: query.trim(),
          status: 'Active',
          managerEmail: role === 'manager' ? user?.email : undefined,
        })
        .then((result) => setSuggestions(result.filter((e) => !selected.some((s) => s.id === e.id))));
    }, 200);
  }, [query, role, user, selected]);

  const training = trainings.find((t) => t.id === trainingId);
  const expiration = useMemo(() => {
    if (!training || training.validityMonths === 0 || planned) return null;
    return addMonths(completionDate, training.validityMonths);
  }, [training, completionDate, planned]);

  const save = async () => {
    const errs: Record<string, string> = {};
    if (selected.length === 0) errs.employees = 'Vyberte aspoň jedného zamestnanca.';
    if (!trainingId) errs.training = 'Vyberte školenie.';
    if (!completionDate) errs.date = 'Zadajte dátum.';
    else if (!planned && completionDate > todayIso()) errs.date = 'Dátum absolvovania nemôže byť v budúcnosti. Pre budúci termín označte „Naplánované školenie“.';
    else if (planned && completionDate <= todayIso()) errs.date = 'Plánovaný termín musí byť v budúcnosti.';
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setSaving(true);
    try {
      for (const emp of selected) {
        await dataService.addRecord(
          {
            employeeId: emp.id,
            trainingId,
            completionDate,
            planned,
            certificateFileName: certFile || undefined,
            notes: notes || undefined,
          },
          user?.email ?? '',
        );
      }
      toast.show('success', selected.length === 1
        ? 'Záznam školenia bol uložený.'
        : `Uložených ${selected.length} záznamov školenia.`);
      navigate('/zaznamy');
    } catch {
      toast.show('error', 'Uloženie sa nepodarilo. Skúste to znova.');
      setSaving(false);
    }
  };

  return (
    <div className="page page--narrow">
      <Link to="/zaznamy" className="back-link">← Späť na záznamy</Link>
      <header className="page__header">
        <h1>Nový záznam školenia</h1>
        <p className="page__subtitle">
          Výberom viacerých zamestnancov pridáte záznam hromadne. Certifikát sa uloží do knižnice Certificates.
        </p>
      </header>

      <Field label="Zamestnanci" htmlFor="rec-emp" error={errors.employees}>
        <div className="combobox">
          {selected.length > 0 && (
            <div className="chip-row">
              {selected.map((e) => (
                <span key={e.id} className="chip is-active">
                  {e.fullName}
                  <button
                    type="button"
                    aria-label={`Odobrať ${e.fullName}`}
                    onClick={() => setSelected(selected.filter((s) => s.id !== e.id))}
                  >
                    ✕
                  </button>
                </span>
              ))}
            </div>
          )}
          <input
            id="rec-emp"
            type="text"
            role="combobox"
            aria-expanded={open && suggestions.length > 0}
            aria-autocomplete="list"
            aria-controls="rec-emp-list"
            placeholder="Začnite písať meno alebo osobné číslo…"
            value={query}
            onChange={(e) => { setQuery(e.target.value); setOpen(true); }}
            onFocus={() => setOpen(true)}
            onBlur={() => setTimeout(() => setOpen(false), 150)}
          />
          {open && suggestions.length > 0 && (
            <ul className="combobox__list" id="rec-emp-list" role="listbox">
              {suggestions.slice(0, 8).map((e) => (
                <li key={e.id} role="option" aria-selected="false">
                  <button
                    type="button"
                    onMouseDown={(ev) => ev.preventDefault()}
                    onClick={() => { setSelected([...selected, e]); setQuery(''); setSuggestions([]); }}
                  >
                    {e.fullName} <span className="muted">({e.employeeId})</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Field>

      <Field label="Školenie" htmlFor="rec-training" error={errors.training}>
        <select id="rec-training" value={trainingId} onChange={(e) => setTrainingId(Number(e.target.value))}>
          <option value={0}>— vyberte školenie —</option>
          {trainings.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}{t.validityMonths > 0 ? ` (platnosť ${t.validityMonths} mes.)` : ''}
            </option>
          ))}
        </select>
      </Field>

      <div className="field">
        <label className="checkbox">
          <input type="checkbox" checked={planned} onChange={(e) => setPlanned(e.target.checked)} />
          Naplánované školenie (budúci termín)
        </label>
      </div>

      <Field label={planned ? 'Plánovaný termín' : 'Dátum absolvovania'} htmlFor="rec-date" error={errors.date}>
        <input
          id="rec-date"
          type="date"
          value={completionDate}
          onChange={(e) => setCompletionDate(e.target.value)}
        />
      </Field>

      <p className="muted">
        Platnosť do:{' '}
        <strong>
          {planned ? '— (doplní sa po absolvovaní)' : expiration ? fmtDate(expiration) : 'neobmedzená'}
        </strong>
        {training && training.validityMonths > 0 && !planned && ` (ExpirationDate = dátum + ${training.validityMonths} mes.)`}
      </p>

      {!planned && (
        <Field label="Certifikát (PDF)" htmlFor="rec-cert">
          <input
            id="rec-cert"
            type="file"
            accept="application/pdf"
            onChange={(e) => setCertFile(e.target.files?.[0]?.name ?? '')}
          />
        </Field>
      )}

      <Field label="Poznámky" htmlFor="rec-notes">
        <textarea id="rec-notes" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />
      </Field>

      <div className="form-actions">
        <Link to="/zaznamy" className="btn">Zrušiť</Link>
        <button type="button" className="btn btn--primary" onClick={save} disabled={saving}>
          {saving ? 'Ukladám…' : selected.length > 1 ? `Uložiť ${selected.length} záznamov` : 'Uložiť záznam'}
        </button>
      </div>
    </div>
  );
}
