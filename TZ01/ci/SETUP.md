# CI — Power Apps Checker (Option A)

Goal: every push runs the **Power Platform / App Checker** (same engine as the editor's
"App checker") against the TZ01 canvas app, and publishes the error list. The assistant
can then read the run log (via GitHub) and fix issues precisely — no screenshots needed.

There are three one-time setup parts. **You do parts 1–3; the assistant wires the rest.**

---

## 1) Create a service principal (Entra ID app registration)

1. Entra ID (Azure AD) → **App registrations** → **New registration**
   - Name: `tz01-ci`  · Accounts: *Single tenant* · no redirect URI → **Register**.
2. Copy **Application (client) ID** and **Directory (tenant) ID**.
3. **Certificates & secrets** → **New client secret** → copy the **secret VALUE** (shown once).

## 2) Give the SP access to your DEV environment

In **Power Platform Admin Center** → your dev environment → **Settings → Users + permissions → Application users → New app user**:
- Add the `tz01-ci` app (by its client ID).
- Business unit: root. Security role: **System Customizer** (dev only).

> The checker needs an environment to run the analysis service against; a dev/sandbox
> environment with least privilege is enough.

## 3) Add GitHub repository secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret** — add all four:

| Secret | Value |
|---|---|
| `PP_ENV_URL` | your env URL, e.g. `https://orgXXXX.crm4.dynamics.com` |
| `PP_APP_ID` | the Application (client) ID from step 1 |
| `PP_CLIENT_SECRET` | the client secret VALUE from step 1 |
| `PP_TENANT_ID` | the Directory (tenant) ID from step 1 |

Also tell the assistant your tenant **geo** (e.g. `Europe`, `UnitedStates`) — it's set in
`.github/workflows/powerapps-checker.yml` (`geo:`), default `Europe`.

---

## 4) One-time bootstrap — wrap the app in a solution (needed for the checker)

The checker runs on a **solution**, so the app must live inside one. Do this once:

1. In the maker portal → **Solutions → New solution** `TZ01 CI` (any publisher).
2. **Add existing → App → Canvas app →** select the imported TZ01 app → Add.
3. **Export → Unmanaged** → download `TZ01CI_x_x_x_x.zip`.
4. Give that zip to the assistant (commit it under `TZ01/ci/` or attach it). The assistant
   will `pac solution unpack` it into `TZ01/solution/src/`, set the real `.msapp` filename
   in the workflow (`REPLACE_WITH_APP_FILENAME`), and commit. From then on CI rebuilds the
   `.msapp` from source, repacks the solution, and runs the checker on every push.

---

## What happens on each push

`.github/workflows/powerapps-checker.yml`:
1. installs `pac`,
2. `pac canvas pack` → fresh `.msapp` from `TZ01/src`,
3. drops it into the solution and `pac solution pack`,
4. `pac solution check` (authenticated with the SP) → runs the checker service,
5. uploads the **SARIF** report as an artifact and logs a summary.

The assistant reads the run via GitHub (`actions_get` / `get_job_logs`) and fixes findings.
