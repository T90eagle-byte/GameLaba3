# Windows deployment for the university stand

Target: Windows Server 2012 R2 x64, Python 3.12.10 x64, Oracle 12.2.0.1 with
`COMPATIBLE=12.2.0`, and the assigned schema `KE2302_01` on
`10.22.10.40:1521/ORCL`.

## 1. Prepare Python and configuration

Install Python 3.12.10 x64, then open PowerShell in the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r deployment\windows\requirements-windows.txt
Copy-Item deployment\windows\.env.example deployment\windows\.env
```

Set `ORACLE_PASSWORD` and `FLASK_SECRET_KEY` in `deployment\windows\.env`.
Keep `ORACLE_SID=ORCL`; leave `ORACLE_SERVICE` empty. Do not commit this file.

The app uses `python-oracledb` Thin mode. Oracle Instant Client is not needed.

## 2. Install or update the assigned schema

Open one of the scripts below in SQL Developer while connected **as
`KE2302_01`**, then run it with `F5`:

- `database/installers/university_existing_schema_install.sql` for an assigned
  empty schema. It stops before changing anything if BioSborka tables already
  exist.
- `database/installers/university_existing_schema_update.sql` for an existing
  BioSborka schema. Stop Waitress first. It applies migrations `01..14` in
  order, all production reference seeds `01..05`, and recompiles the current
  package without deleting players, labs or progress.

Neither script creates or drops an Oracle user, truncates tables, or removes
user data. Each validates the full v3 contract (18 archetypes, 324 templates,
model membership 12/19, 12 v3 tasks and hybridization references) before
recording schema version `14`. Do not run the clean installer against a schema
that already has BioSborka data.

After a successful database update, replace the Python project files, verify
dependencies with the requirements command above, run the readiness CLI below,
and then restart `deployment\windows\start-web.cmd`. Oracle itself does not need
to be reinstalled.

## 3. Run the web application

Run `deployment\windows\start-web.cmd`, then open
`http://127.0.0.1:8000/health`. A `200` response means both Oracle connectivity
and game schema readiness passed; `/health/live` only confirms the web process.

For a pre-defense command-line check:

```powershell
$env:BIOSBORKA_ENV_FILE = "$PWD\deployment\windows\.env"
.\.venv\Scripts\python.exe database\scripts\check_runtime_readiness.py
```

Waitress is used for Windows; Gunicorn is not part of this deployment path.
