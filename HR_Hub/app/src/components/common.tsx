import type { ReactNode } from 'react';
import type { Employee } from '../types';

export function KpiTile(props: { label: string; value: ReactNode; tone?: 'default' | 'warn' | 'danger'; onClick?: () => void }) {
  const cls = 'kpi' + (props.tone && props.tone !== 'default' ? ` kpi--${props.tone}` : '');
  if (props.onClick) {
    return (
      <button type="button" className={cls} onClick={props.onClick}>
        <span className="kpi__value">{props.value}</span>
        <span className="kpi__label">{props.label}</span>
      </button>
    );
  }
  return (
    <div className={cls}>
      <span className="kpi__value">{props.value}</span>
      <span className="kpi__label">{props.label}</span>
    </div>
  );
}

export function Skeleton({ rows = 3, height = 56 }: { rows?: number; height?: number }) {
  return (
    <div aria-hidden="true">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="skeleton" style={{ height, marginBottom: 10 }} />
      ))}
    </div>
  );
}

export function EmptyState({ title, hint, action }: { title: string; hint?: string; action?: ReactNode }) {
  return (
    <div className="empty-state">
      <div className="empty-state__icon" aria-hidden="true">🗂️</div>
      <h3>{title}</h3>
      {hint && <p>{hint}</p>}
      {action}
    </div>
  );
}

export function Avatar({ employee, size = 40 }: { employee: Employee; size?: number }) {
  const initials = employee.fullName.split(' ').map((p) => p[0]).slice(0, 2).join('');
  return (
    <span
      className="avatar"
      style={{ width: size, height: size, fontSize: size * 0.38 }}
      role="img"
      aria-label={employee.fullName}
      title={employee.fullName}
    >
      {initials}
    </span>
  );
}

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(e) => e.stopPropagation()}
      >
        <header className="modal__header">
          <h2>{title}</h2>
          <button type="button" className="btn btn--ghost" onClick={onClose} aria-label="Zavrieť">✕</button>
        </header>
        {children}
      </div>
    </div>
  );
}

export function Field(props: { label: string; htmlFor: string; error?: string; children: ReactNode }) {
  return (
    <div className={'field' + (props.error ? ' field--invalid' : '')}>
      <label htmlFor={props.htmlFor}>{props.label}</label>
      {props.children}
      {props.error && <span className="field__error" role="alert">{props.error}</span>}
    </div>
  );
}
