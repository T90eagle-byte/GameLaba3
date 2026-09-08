# Windows deployment for the university stand

Target: Windows Server 2012 R2 x64, Python 3.12.10 x64, Oracle 12.2.0.1 with
`COMPATIBLE=12.2.0`, and the assigned schema `KE2302_01` on
`10.22.10.40:1521/ORCL`.

## 1. Prepare Python and configuration

Install Python 3.12.10 x64, then open PowerShell in the repository root:

```powershell
py -3.12 -m venv .venv
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
  BioSborka schema. It applies idempotent migrations, reference seed data and
  recompiles the package without deleting players, labs or progress.

Neither script creates or drops an Oracle user, truncates tables, or removes
user data. Each ends by checking the package, `USER_ERRORS`, and basic schema
readiness. Do not run the clean installer against a schema that already has
BioSborka data.

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
