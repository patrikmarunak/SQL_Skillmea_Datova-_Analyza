import type { RecordStatus, TrainingRecord } from '../types';

export const EXPIRING_WINDOW_DAYS = 30;

/** Ekvivalent Power Fx DateAdd(date, months, Months). */
export function addMonths(isoDate: string, months: number): string {
  const d = new Date(isoDate + 'T00:00:00');
  const day = d.getDate();
  d.setDate(1);
  d.setMonth(d.getMonth() + months);
  const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  d.setDate(Math.min(day, lastDay));
  return toIso(d);
}

export function toIso(d: Date): string {
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
}

export function todayIso(): string {
  return toIso(new Date());
}

export function daysUntil(isoDate: string): number {
  const ms = new Date(isoDate + 'T00:00:00').getTime() - new Date(todayIso() + 'T00:00:00').getTime();
  return Math.round(ms / 86_400_000);
}

/**
 * Stav záznamu prepočítaný k dnešku – uložený Status v SharePointe je snapshot,
 * ktorý by inak musel denne prepočítavať Power Automate flow.
 */
export function liveStatus(record: Pick<TrainingRecord, 'status' | 'completionDate' | 'expirationDate'>): RecordStatus {
  if (record.status === 'Planned') return 'Planned';
  if (!record.expirationDate) return 'Valid';
  const days = daysUntil(record.expirationDate);
  if (days < 0) return 'Expired';
  if (days <= EXPIRING_WINDOW_DAYS) return 'Expiring';
  return 'Valid';
}

const skDate = new Intl.DateTimeFormat('sk-SK', { day: 'numeric', month: 'numeric', year: 'numeric' });
const skDateTime = new Intl.DateTimeFormat('sk-SK', {
  day: 'numeric', month: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit',
});

export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  return skDate.format(new Date(iso.length <= 10 ? iso + 'T00:00:00' : iso));
}

export function fmtDateTime(iso: string): string {
  return skDateTime.format(new Date(iso));
}
