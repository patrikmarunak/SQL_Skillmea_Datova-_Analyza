import { NavLink } from 'react-router-dom';
import { useCurrentUser } from '../auth/CurrentUserContext';
import type { Role } from '../types';

interface NavItem { to: string; label: string; icon: string; roles: Role[]; }

const ITEMS: NavItem[] = [
  { to: '/', label: 'Domov', icon: '⌂', roles: ['admin', 'manager', 'employee'] },
  { to: '/zamestnanci', label: 'Zamestnanci', icon: '👥', roles: ['admin', 'manager'] },
  { to: '/katalog', label: 'Katalóg školení', icon: '📚', roles: ['admin', 'manager'] },
  { to: '/zaznamy', label: 'Záznamy školení', icon: '📋', roles: ['admin', 'manager'] },
  { to: '/moje-skolenia', label: 'Moje školenia', icon: '🎓', roles: ['admin', 'manager', 'employee'] },
  { to: '/reporty', label: 'Reporty', icon: '📊', roles: ['admin', 'manager'] },
];

export function NavRail() {
  const { role } = useCurrentUser();
  return (
    <nav className="nav-rail" aria-label="Hlavná navigácia">
      <div className="nav-rail__brand" aria-hidden="true">
        <span className="nav-rail__logo">HR</span>
        <span className="nav-rail__title">HR Hub</span>
      </div>
      <ul>
        {ITEMS.filter((item) => item.roles.includes(role)).map((item) => (
          <li key={item.to}>
            <NavLink
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) => 'nav-rail__link' + (isActive ? ' is-active' : '')}
            >
              <span className="nav-rail__icon" aria-hidden="true">{item.icon}</span>
              <span className="nav-rail__label">{item.label}</span>
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
