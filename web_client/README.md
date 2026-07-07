# BioSborKA web client

Lightweight Flask/Jinja browser interface for the GameLR3 / BioSborKA project.
The UI is intentionally simple to run on a weak defense stand, but the pages are styled as a finished product rather than an admin prototype.

## Purpose

The web client is a portable defense interface over the stable Oracle PL/SQL backend. It avoids PySide6/Qt runtime risk on old Windows machines and does not require React, Vue, Node.js or a frontend build step.

## UI concept

The current web pass uses a soft biological/evolutionary visual language:

- organic cards and rounded panels;
- a natural green/clay/water palette;
- responsive creature cards with CSS portraits;
- phenotype chips instead of raw trait codes;
- readable genotype cards instead of plain rows;
- timeline-style experiment history;
- visually separated positive/negative rating and wallet deltas.

The visuals are display-only. They do not change gameplay rules.

## Architecture rule

Business logic stays in Oracle PL/SQL:

- genetics is calculated by `pkg_genetics_game`;
- client orders are checked by `pkg_genetics_game`;
- crossbreed and offspring preview are handled by `pkg_genetics_game`;
- mutations, mutagens, wallet, rating and rating events are handled by `pkg_genetics_game`;
- Flask only calls package API and renders returned data.

The only direct SQL in web code is the technical health-check `select 1 from dual`.

## Install dependencies

```powershell
.\.venv\Scripts\python.exe -m pip install -r web_client\requirements.txt
```

## Run

```powershell
.\.venv\Scripts\python.exe web_client\app.py
```

Open:

```text
http://127.0.0.1:8000
```

## Routes

- `/health` - app and Oracle connection health.
- `/register`, `/login`, `/logout` - authentication.
- `/labs` - create/open lab.
- `/dashboard` - defense dashboard and lab stats.
- `/creatures`, `/creatures/<id>` - creature cards, phenotype and genotype.
- `/tasks` - client orders, check and complete.
- `/crossbreed` - parent selection, 3-option preview and real offspring creation.
- `/mutations` - mutation shop, mutation application, RADIATION/CHEMICAL mutagens.
- `/experiments` - evolution line through experiment history.
- `/rating-events` - wallet/rating consequences from backend event log.
- `/about-requirements` - compact requirements coverage page for defense.

## Manual smoke checklist

1. Open `/health`.
2. Register and login.
3. Create/open a lab.
4. Open dashboard.
5. Open creatures and a creature detail page.
6. Open client orders, check an order, complete a matching order if available.
7. Open crossbreed, preview 3 options, create real offspring.
8. Open mutations, buy/apply mutation if backend allows it, apply RADIATION or CHEMICAL.
9. Open experiments and rating events.
10. Open `/about-requirements`.
11. Logout.

## Automated smoke

```powershell
.\.venv\Scripts\python.exe web_client\smoke_test.py
```

The script uses Flask test client and package-backed service wrappers. It does not use gameplay SQL. It creates a test user/lab in the configured Oracle database. Data-dependent steps may print `[SKIP]` when the backend does not provide a suitable immediate scenario.

## Troubleshooting

- Oracle unavailable: check Docker/service, host/port, service name or SID.
- `.env` missing values: check `python_client/.env`.
- No current lab: open `/labs` and create/open a lab.
- Backend package invalid: run `database\scripts\run_tests.py` and inspect `user_errors`.
- Not enough wallet, incompatible parents or unavailable mutation: this is a backend rule response; web should show a flash message without traceback.

## Not in scope

- React/Vue/Node build.
- Moving PL/SQL logic into Python.
- Grade 5 mechanics: ecosystem enclosure, creature death, ethics board or lab shutdown.
