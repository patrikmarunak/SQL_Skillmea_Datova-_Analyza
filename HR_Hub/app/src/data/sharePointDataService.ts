/**
 * Produkčná implementácia DataService nad SharePoint listami site "HR Hub".
 *
 * Postup napojenia (Power Apps code apps):
 *   1. pac auth create --environment <env-id>
 *   2. pac code init  (v adresári app/)
 *   3. pac connection list / pac code add-data-source -a sharepointonline ...
 *      pre listy Employees, Departments, Positions, TrainingsCatalog,
 *      TrainingRecords, AuditLog a knižnicu Certificates.
 *   4. Vygenerované modely a služby z @microsoft/power-apps použiť tu
 *      a v main.tsx nahradiť MockDataService touto triedou.
 *
 * Zásady (rovnaké, aké simuluje MockDataService):
 *   - len delegovateľné dotazy: rovnosť na indexovaných stĺpcoch
 *     (EmployeeID, Email, ManagerEmail, Status, ExpirationDate, lookupy)
 *     a startswith() na Title/EmployeeID; $top stránkovanie pod limitom 5000,
 *   - soft-delete: nikdy DELETE, len Status = 'Inactive',
 *   - každý create/update zapíše riadok do AuditLogu (User().Email, Now()),
 *   - ExpirationDate = DateAdd(CompletionDate, ValidityMonths, Months).
 */
export {};
