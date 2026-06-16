# Oracle backend slice: run guide

This guide is for Oracle SQL Developer, SQLcl, or SQL*Plus.


## Workspace and project transfer

Use this workspace when working locally:

```powershell
cd C:\GameLR3
```

Do not use the old path under `C:\Users\User\DATA`.

When moving the project to another PC or GitLab, do not commit local secrets or virtual environments:
- `.env` files are local only;
- `.venv/` is local only;
- Oracle passwords are local only.

## Python GUI setup

From repository root on Windows:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Create local environment configuration from the example if needed:

```powershell
Copy-Item python_client\.env.example python_client\.env
```

Then edit `python_client/.env` with local Oracle connection settings. Do not commit `.env`.

Run the GUI from repository root:

```powershell
.\.venv\Scripts\python.exe python_client\main.py
```

## Prerequisites

- Password hashing uses Oracle `STANDARD_HASH(..., 'SHA256')`; no extra crypto or input-encoding grants are required for hashing.
- The schema must have access to `DBMS_RANDOM`, because the package body uses it for random allele/mutation-related selection.
- Without `DBMS_RANDOM`, package body compilation or runtime genetic operations can fail.

Practical notes:

- The DDL does not contain `DROP` blocks, so the first full run is best done in a clean schema.
- This version adds domain reference tables and `tasks.difficulty_code`; existing schemas should be recreated for verification unless a separate migration is prepared.
- If the project path contains spaces or Cyrillic characters, run SQL Developer/SQLcl from the project root or use quoted absolute paths to the `.sql` files.

## Особенности вузовского стенда

Target university environment can differ from a local developer machine:

- Windows Server 2012 R2;
- DBeaver 21.2.1;
- Oracle host, port and SID are local settings and should be configured through `python_client/.env`;
- do not commit `.env`, passwords, or machine-specific connection values.

DBeaver 21.2.1 can be sensitive to SQL*Plus-style scripts:

- `SET DEFINE OFF` may not behave exactly like in SQL*Plus/SQLcl depending on execution mode;
- a single `/` delimiter can be skipped or sent incorrectly when running fragments with Ctrl+Enter;
- package body compilation is safer when the whole file is executed as a script, not as a selected fragment;
- long smoke-tests are also safer when run as full scripts.

If DBeaver breaks package or smoke-test execution, use SQLcl/SQL*Plus or run the same files through a small Python runner based on `python-oracledb`. The runner should:

- read connection parameters from `python_client/.env`;
- execute SQL files in order from this guide;
- preserve UTF-8 text;
- handle package files as complete scripts, including the final `/` delimiter;
- print `user_errors` after package compilation.

The runner is an execution helper only. It must not add gameplay SQL to the Python GUI client.

## 1) Run DDL

From repository root:

```sql
@database/ddl/01_create_tables.sql
```

## 2) Run core seed data

```sql
@database/seeds/01_seed_core_game_data.sql
```

The seed fills domain reference tables first, then core game data. GUI display labels for species, gene types, dominance, task statuses, experiment types, mutation types, mutagen types, and task difficulties are now stored in the database and exposed through `pkg_genetics_game` cursors. Python keeps only formatting/fallback helpers and is not the source of truth for these domain enums.

## 3) Run package specification

```sql
@database/packages/spec/pkg_genetics_game.pks
```

Check compile output:

```sql
show errors package pkg_genetics_game
```

## 4) Run package body

```sql
@database/packages/body/pkg_genetics_game.pkb
```

Check compile output:

```sql
show errors package body pkg_genetics_game
```

## 5) Run auth/labs smoke-test

```sql
@database/tests/01_auth_labs_smoke_test.sql
```

The script uses anonymous PL/SQL blocks and `dbms_output` only for test reporting.

## 6) Run seed data smoke-test

```sql
@database/tests/02_seed_data_smoke_test.sql
```

This smoke-test validates that core game seed data is loaded and linked correctly:
- minimum counts for genes, alleles, mutations, tasks;
- populated domain reference tables;
- non-null `tasks.difficulty_code` values;
- at least 2 alleles per gene;
- valid `mutation_rules` links and gene-to-allele consistency;
- valid `task_markers`;
- presence of universal genes and all `species_type` values from 1 to 6.

## 7) Run creature generation smoke-test

```sql
@database/tests/03_creature_generation_smoke_test.sql
```

This smoke-test validates the first creature-generation vertical slice:
- user/session/lab flow for isolated test data;
- generation of exactly 30 starting creatures (6 species x 5);
- presence of all `species_type` values 1..6 in the created lab;
- genotype and phenotype summary population for created creatures;
- cursor APIs `get_creatures_cursor` and `get_genotype_cursor`;
- `get_lab_stats` aggregate consistency for `creature_count`.

## 8) Run crossbreed smoke-test

```sql
@database/tests/04_crossbreed_smoke_test.sql
```

This smoke-test validates the crossbreeding block:
- `calculate_punnett_probabilities` returns rows and probability sum is close to 1;
- `crossbreed` creates offspring with genotype, phenotype summary, and `CROSS` experiment row;
- lab stats reflect new creature and experiment counters;
- `rename_creature` updates offspring name;
- negative case for same parent ids raises expected error.

## 9) Run mutations/experiments smoke-test

```sql
@database/tests/05_mutations_experiments_smoke_test.sql
```

This smoke-test validates the mutations and experiments block end-to-end:
- mutation shop cursor (`show_mutation_shop`);
- buy/apply mutation flow with stock and wallet checks (`buy_mutation`, `apply_mutation`);
- mutagen flow with new creature creation (`apply_mutagen`);
- orchestrated experiment flow (`make_experiment`) for `CROSS` and `MUTATION` branches;
- experiment history cursor (`get_experiment_history`);
- negative cases with expected SQL error codes.

## 10) Run tasks smoke-test

```sql
@database/tests/06_tasks_smoke_test.sql
```

This smoke-test validates the tasks block end-to-end:
- `start_new_lab` assigns starter `ACTIVE` tasks;
- task cursor API (`get_tasks_cursor`);
- marker-based validation (`check_task`);
- completion and rewards (`complete_task`) with lab stats update;
- repeat completion protection (`-20064`) and negative checks for invalid IDs/lab ownership.

After successful `01..06` smoke-tests, the full PL/SQL backend MVP is covered by baseline smoke checks.

## 11) Run strict compliance smoke-test

```sql
@database/tests/07_strict_compliance_smoke_test.sql
```

This smoke-test validates strict-compliance behavior on top of MVP:
- `start_new_lab` immediately creates a full starter lab (`30` creatures + `3` ACTIVE tasks);
- gameplay access control blocks foreign lab/creature access via package session context;
- `INCOMPLETE` and `CODOMINANT` phenotype semantics are not treated like `FULL`;
- `RADIATION` and `CHEMICAL` mutagen flows are different and invalid mutagen type is rejected;
- auto task-check after experiment flow can complete matching ACTIVE tasks;
- domain values are backed by reference tables and `get_reference_cursor` returns display labels.

## 12) Run multiuser/sessions smoke-test

```sql
@database/tests/08_multiuser_sessions_smoke_test.sql
```

This smoke-test validates strict multiuser/session behavior:
- cross-user access is blocked for labs, creatures, tasks, history, and gameplay APIs;
- the same lab cannot be opened in two ACTIVE sessions at once (`-20072`);
- after closing session1, session2 can load the lab;
- an old closed session token cannot reopen the lab (`-20020`).

## 13) Run LR2 package API compatibility smoke-test

```sql
@database/tests/09_lr2_package_api_compat_smoke_test.sql
```

This smoke-test validates LR2-compatible public package methods that are kept as wrappers over the current implementation:
- `hash_password`;
- `exit_lab`;
- `show_lab_stats`;
- `show_creatures`;
- `get_dominant_allele`;
- `get_inherited_allele`;
- `get_linked_allele_set`;
- `show_tasks`;
- `show_mutation_history`;
- no-argument `show_mutation_shop`.

## 14) Inspect compile errors via USER_ERRORS

```sql
select
    name,
    type,
    line,
    position,
    text
from user_errors
where upper(name) = 'PKG_GENETICS_GAME'
order by sequence;
```

## Useful verification queries

### Verify tables

```sql
select table_name
from user_tables
where table_name in (
    'REF_SPECIES_TYPES',
    'REF_GENE_TYPES',
    'REF_DOMINANCE_TYPES',
    'REF_TASK_STATUSES',
    'REF_EXPERIMENT_TYPES',
    'REF_MUTAGEN_TYPES',
    'REF_MUTATION_TYPES',
    'REF_TASK_DIFFICULTIES',
    'USERS',
    'SESSIONS',
    'LABS',
    'GENES',
    'ALLELES',
    'MUTATIONS',
    'MUTATION_RULES',
    'TASKS',
    'CREATURES',
    'GENOTYPES',
    'EXPERIMENTS',
    'LAB_MUTATIONS',
    'LAB_TASKS',
    'TASK_MARKERS'
)
order by table_name;
```

### Verify sequences

```sql
select sequence_name
from user_sequences
where sequence_name in (
    'USERS_SEQ',
    'SESSIONS_SEQ',
    'LABS_SEQ',
    'GENES_SEQ',
    'ALLELES_SEQ',
    'MUTATIONS_SEQ',
    'MUTATION_RULES_SEQ',
    'TASKS_SEQ',
    'CREATURES_SEQ',
    'GENOTYPES_SEQ',
    'EXPERIMENTS_SEQ',
    'LAB_MUTATIONS_SEQ',
    'LAB_TASKS_SEQ',
    'TASK_MARKERS_SEQ'
)
order by sequence_name;
```

### Quick package status check

```sql
select object_name, object_type, status
from user_objects
where object_name = 'PKG_GENETICS_GAME'
order by object_type;
```


## 15) DEV-only: unlock stale ACTIVE sessions (after old GUI crash)

If you still have a stale lab lock (`ORA-20072`) from an old GUI version that was closed without logout, you can close stale sessions for a specific user in dev environment:

```sql
@database/scripts/dev_unlock_stale_sessions.sql
```

Notes:
- This script is **DEV ONLY** and is not part of mandatory smoke-tests.
- It only closes `sessions.status='ACTIVE'` for the chosen login.
- It does **not** delete labs/creatures/genotypes/experiments/lab_tasks/lab_mutations.
- With current GUI close handling, this should no longer occur in normal flow.

## Full smoke-test order

After DDL, seed, package spec, and package body are applied, run smoke-tests in this order:

```sql
@database/tests/01_auth_labs_smoke_test.sql
@database/tests/02_seed_data_smoke_test.sql
@database/tests/03_creature_generation_smoke_test.sql
@database/tests/04_crossbreed_smoke_test.sql
@database/tests/05_mutations_experiments_smoke_test.sql
@database/tests/06_tasks_smoke_test.sql
@database/tests/07_strict_compliance_smoke_test.sql
@database/tests/08_multiuser_sessions_smoke_test.sql
@database/tests/09_lr2_package_api_compat_smoke_test.sql
```

When deploying into a fresh schema, run the seed before smoke-tests.
DBeaver 21.2.1 на учебном стенде может некорректно выполнять PL/SQL package body и тестовые скрипты с SQL*Plus-директивами. При ошибках на SET DEFINE OFF или одиночном / эти строки нужно комментировать либо запускать package/tests через Python runner. Для просмотра таблиц, выполнения простых SELECT и проверки user_objects DBeaver подходит нормально.