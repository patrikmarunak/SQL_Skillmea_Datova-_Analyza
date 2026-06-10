import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { Employee, Role } from '../types';
import { dataService } from '../data/mockDataService';

/**
 * V produkcii sa rola zisťuje cez Entra ID security skupiny voči User().Email
 * (Office 365 Users / Graph). V mock režime: HR oddelenie = HR Admin,
 * zamestnanec s podriadenými = Manager, ostatní = Employee.
 * Prepínač používateľa v hornej lište slúži len na demo rolí.
 */

interface CurrentUserState {
  user: Employee | null;
  role: Role;
  /** Zamestnanci dostupní v demo prepínači. */
  allUsers: Employee[];
  switchUser: (id: number) => void;
  canEditEmployee: (target: Employee) => boolean;
  canEditRecordOf: (target: Employee) => boolean;
}

const CurrentUserContext = createContext<CurrentUserState | null>(null);

const HR_DEPT_CODE = 'HR';

export function CurrentUserProvider({ children }: { children: ReactNode }) {
  const [allUsers, setAllUsers] = useState<Employee[]>([]);
  const [hrDeptId, setHrDeptId] = useState<number>(0);
  const [userId, setUserId] = useState<number>(1); // default: HR manažérka (HR Admin)

  useEffect(() => {
    Promise.all([dataService.getEmployees({ status: 'Active' }), dataService.getDepartments()])
      .then(([employees, departments]) => {
        setAllUsers(employees);
        setHrDeptId(departments.find((d) => d.code === HR_DEPT_CODE)?.id ?? 0);
      });
  }, []);

  const value = useMemo<CurrentUserState>(() => {
    const user = allUsers.find((e) => e.id === userId) ?? null;
    let role: Role = 'employee';
    if (user) {
      if (user.departmentId === hrDeptId) role = 'admin';
      else if (allUsers.some((e) => e.managerEmail === user.email)) role = 'manager';
    }
    return {
      user,
      role,
      allUsers,
      switchUser: setUserId,
      canEditEmployee: () => role === 'admin',
      canEditRecordOf: (target) =>
        role === 'admin' || (role === 'manager' && !!user && target.managerEmail === user.email),
    };
  }, [allUsers, userId, hrDeptId]);

  return <CurrentUserContext.Provider value={value}>{children}</CurrentUserContext.Provider>;
}

export function useCurrentUser(): CurrentUserState {
  const ctx = useContext(CurrentUserContext);
  if (!ctx) throw new Error('useCurrentUser musí byť vnútri CurrentUserProvider');
  return ctx;
}
