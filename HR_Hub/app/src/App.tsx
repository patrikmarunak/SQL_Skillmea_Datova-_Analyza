import { useEffect, useState } from 'react';
import { HashRouter, Navigate, Route, Routes } from 'react-router-dom';
import { CurrentUserProvider, useCurrentUser } from './auth/CurrentUserContext';
import { ToastProvider } from './components/Toast';
import { NavRail } from './components/NavRail';
import { Dashboard } from './screens/Dashboard';
import { Employees } from './screens/Employees';
import { EmployeeDetail } from './screens/EmployeeDetail';
import { TrainingsCatalog } from './screens/TrainingsCatalog';
import { TrainingRecords } from './screens/TrainingRecords';
import { AddTrainingRecord } from './screens/AddTrainingRecord';
import { MyTrainings } from './screens/MyTrainings';
import { Reports } from './screens/Reports';
import type { Role } from './types';

const ROLE_LABELS: Record<Role, string> = {
  admin: 'HR Admin',
  manager: 'Manažér',
  employee: 'Zamestnanec',
};

function TopBar({ theme, onToggleTheme }: { theme: 'light' | 'dark'; onToggleTheme: () => void }) {
  const { user, role, allUsers, switchUser } = useCurrentUser();
  return (
    <header className="topbar">
      <span className="topbar__spacer" />
      <button
        type="button"
        className="btn btn--ghost"
        onClick={onToggleTheme}
        aria-label={theme === 'light' ? 'Prepnúť na tmavú tému' : 'Prepnúť na svetlú tému'}
        title="Prepnúť tému (Teams light/dark)"
      >
        {theme === 'light' ? '🌙' : '☀️'}
      </button>
      <span className={`role-badge role-badge--${role}`}>{ROLE_LABELS[role]}</span>
      {/* Demo prepínač – v produkcii rolu určuje Entra ID skupina voči User().Email */}
      <label className="user-switcher">
        <span className="visually-hidden">Prihlásený používateľ (demo)</span>
        <select value={user?.id ?? ''} onChange={(e) => switchUser(Number(e.target.value))}>
          {allUsers.map((u) => (
            <option key={u.id} value={u.id}>{u.fullName}</option>
          ))}
        </select>
      </label>
    </header>
  );
}

function Guard({ children, forbidden }: { children: JSX.Element; forbidden?: Role[] }) {
  const { role } = useCurrentUser();
  if (forbidden?.includes(role)) return <Navigate to="/moje-skolenia" replace />;
  return children;
}

function Shell() {
  const [theme, setTheme] = useState<'light' | 'dark'>(() => {
    const saved = localStorage.getItem('hrhub-theme');
    if (saved === 'light' || saved === 'dark') return saved;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  });

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem('hrhub-theme', theme);
  }, [theme]);

  return (
    <div className="shell">
      <NavRail />
      <div className="shell__main">
        <TopBar theme={theme} onToggleTheme={() => setTheme(theme === 'light' ? 'dark' : 'light')} />
        <main className="shell__content">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/zamestnanci" element={<Guard forbidden={['employee']}><Employees /></Guard>} />
            <Route path="/zamestnanci/:id" element={<Guard forbidden={['employee']}><EmployeeDetail /></Guard>} />
            <Route path="/katalog" element={<Guard forbidden={['employee']}><TrainingsCatalog /></Guard>} />
            <Route path="/zaznamy" element={<Guard forbidden={['employee']}><TrainingRecords /></Guard>} />
            <Route path="/zaznamy/novy" element={<Guard forbidden={['employee']}><AddTrainingRecord /></Guard>} />
            <Route path="/moje-skolenia" element={<MyTrainings />} />
            <Route path="/reporty" element={<Guard forbidden={['employee']}><Reports /></Guard>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <HashRouter>
      <CurrentUserProvider>
        <ToastProvider>
          <Shell />
        </ToastProvider>
      </CurrentUserProvider>
    </HashRouter>
  );
}
