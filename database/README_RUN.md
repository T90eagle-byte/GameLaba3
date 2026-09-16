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
- Existing BioSborka schemas must be updated through the non-destructive versioned installer; do not recreate them to apply v3.
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

## 1) Install or update the schema

Use one entry point while the web application is stopped:

- fresh assigned schema: run `database/installers/university_existing_schema_install.sql` with `F5`;
- existing BioSborka schema: run `database/installers/university_existing_schema_update.sql` with `F5`.

The fresh path applies the canonical DDL first. Both paths then use the shared
`apply_current_schema_update.sql` order: migrations `01..13`, production seeds
`01..05`, current package spec/body, full v3 validation, and finally schema
version marker `13`. Validation must pass before the marker advances. The update
path does not drop or truncate objects and preserves users, sessions,
laboratories, creatures, genotypes, task assignments, experiments, mutation
stocks, and rating history. Existing laboratories remain genetics v1; only new
laboratories use v3.

The individual component commands below are useful for diagnosis and focused
development. They are not a substitute for the two deployment entry points.

### Canonical DDL

From repository root:

```sql
@database/ddl/01_create_tables.sql
```

For an existing local schema created before nullable lab session locks, stop the
application and run the one-time migration before recompiling the package:

```sql
@database/migrations/01_release_lab_session_bindings.sql
```

The migration makes `labs.session_id` nullable and releases bindings left by
older application sessions. A clean schema created from the current DDL does
not need this migration.

For an existing schema created before laboratory names were introduced, keep
the application stopped and run the next migration separately:

```sql
@database/migrations/02_add_lab_names.sql
```

It fills existing rows with `Био-мастерская #<lab_id>` and then makes
`labs.lab_name` mandatory. Do not rerun an already applied migration.

For an existing schema with legacy phenotype-oriented task descriptions, run
the idempotent data migration after stopping the application:

```sql
@database/migrations/03_align_task_requirement_descriptions.sql
```

It only clarifies task text. Task markers and the genotype-based `check_task`
rule are unchanged.

Migration 04 introduces the required lr3-v3 morphology foundation:

```sql
@database/migrations/04_add_creature_archetypes.sql
```

It creates reference-only archetype tables and 18 empty morphology archetypes.
It does not alter creatures, genotypes, package behavior, or starter generation.
The versioned installers invoke it automatically; verify it independently with:

```sql
@database/tests/12_creature_archetypes_smoke_test.sql
```

The next migration adds a universal morphology dictionary with an
explicit gameplay gate:

```sql
@database/migrations/05_add_universal_morphology.sql
```

It marks all legacy genes as `Y` and adds 18 reference-only morphology genes
as `N`. Existing genotype rows remain valid. Verify it independently with:

```sql
@database/tests/13_universal_morphology_smoke_test.sql
```

The following migration fills the reference genotype of every
archetype after migrations 04 and 05 are installed:

```sql
@database/migrations/06_add_archetype_templates.sql
```

It stores 18 homozygous morphology values for each of 18 archetypes
(324 rows) in `REF_ARCHETYPE_ALLELES`. At this stage they remain reference
templates only; starter materialization is enabled by the following package
update. Verify the template data separately with:

```sql
@database/tests/14_archetype_templates_smoke_test.sql
```

The next migration adds nullable metadata linking future starter
creatures to their base archetype:

```sql
@database/migrations/07_add_creature_archetype.sql
```

Existing creatures remain `NULL`; crossbred or hybrid creatures may also have
no single archetype. Starter generation assigns active archetypes cyclically
by `archetype_code`, preserves the enabled legacy genotype, and materializes
the corresponding 18 disabled reference morphology rows. Phenotype logic
continues to ignore disabled morphology genes. Verify this separately with:

```sql
@database/tests/15_creature_archetype_link_smoke_test.sql
```

Verify complete starter materialization, transition compatibility, and atomic
failure handling with:

```sql
@database/tests/17_starter_morphology_materialization_smoke_test.sql
```

The legacy and universal morphology read APIs intentionally coexist during the
transition. A legacy creature has a normal `get_phenotype` result and an empty
`get_morphology_cursor` result. A v3 starter or dual-schema offspring has the
same legacy-compatible `get_phenotype` plus 18 universal morphology traits
from `get_morphology_cursor`. The morphology cursor reads `GENOTYPES`, so an
`archetype_id` is not required after starter materialization. Verify this with:

```sql
@database/tests/18_morphology_phenotype_api_smoke_test.sql
```

For v3 web card rendering, `get_lab_morphology_cursor(p_lab_id)` returns the
same canonical 18 morphology rows for every accessible creature in one cursor.
It is read-only and deliberately does not derive a creature's appearance from
`archetype_id`; an actual crossbred offspring with a null archetype is covered
by the dedicated read-model smoke test:

```sql
@database/tests/25_morphology_render_read_model_smoke_test.sql
```

Migration 08 adds nullable `ALLELES.DISPLAY_NAME` for player-facing universal
morphology values while preserving `ALLELES.DESCRIPTION` as the stable
technical code. It fills only the universal morphology dictionary; legacy
alleles may keep a null display name. `get_morphology_cursor` returns both the
technical and display values, with a technical-code fallback for null names:

```sql
@database/migrations/08_add_allele_display_names.sql
@database/tests/19_morphology_display_names_smoke_test.sql
```

Migration 09 introduces an explicit laboratory model boundary. Existing
laboratories are marked `genetics_version = 1` (historical legacy model), while
laboratories created after the migration and fresh installs use
`genetics_version = 3` (universal-morphology model). The migration does not
backfill creatures or genotypes. An empty legacy laboratory is deliberately
prevented from generating v3 starter morphology:

```sql
@database/migrations/09_add_lab_genetics_version.sql
@database/tests/20_lab_genetics_version_smoke_test.sql
```

Migration 10 adds `REF_GENETICS_MODEL_GENES`, the explicit canonical gene map
for each laboratory model. `LABS.GENETICS_VERSION` selects the model, while
this reference table defines its canonical genes. `GENES.GAMEPLAY_ENABLED`
remains the independent transition runtime gate. Version 1 contains the exact
legacy set; version 3 currently contains 18 universal morphology genes plus
`nutrition_type`. The map is reference-only at this stage and is not read by
the package runtime:

```sql
@database/migrations/10_add_genetics_model_membership.sql
@database/tests/21_genetics_model_membership_smoke_test.sql
```

Mutation runtime is version-aware through `CREATURES.LAB_ID ->
LABS.GENETICS_VERSION`. Version 1 keeps its existing rule-driven mutation and
mutagen behavior, including the legacy `GAMEPLAY_ENABLED` candidate set.
Version 3 mutagens select only the 18 universal morphology genes listed in
`REF_GENETICS_MODEL_GENES`; `nutrition_type` is deliberately excluded until a
separate codominant mutation/display policy is approved. Legacy transition
genes can remain physically present in v3 genotypes but are never mutagen
targets. Current catalog mutation rules are legacy-only, so their use on a v3
creature is rejected without changing its genotype or history. A future v3
directed mutation must contain only canonical morphology rules. Verify both
paths and cleanup with:

```sql
@database/tests/26_version_aware_mutation_smoke_test.sql
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


## Запуск smoke-tests через Python runner

If SQL Developer, SQLcl, SQL*Plus, or DBeaver are inconvenient on the university stand, you can run package files and smoke-tests through the local Python runner:

```powershell
./.venv/Scripts/python.exe database/scripts/run_tests.py --dry-run
./.venv/Scripts/python.exe database/scripts/run_tests.py
```

Default runner behavior:

- reads Oracle connection settings from `python_client/.env`;
- supports either `ORACLE_SERVICE` or `ORACLE_SID`;
- recompiles package spec/body before smoke-tests when `--files` is not used;
- discovers and runs all numbered `database/tests/NN_*.sql` files in filename order;
- executes SQL files as whole scripts;
- ignores SQL*Plus directives such as `set define off`, `set serveroutput on`, `show errors`;
- treats a single `/` on its own line as a PL/SQL script delimiter;
- prints `dbms_output` lines and final package status/user_errors.

Useful examples:

```powershell
./.venv/Scripts/python.exe database/scripts/run_tests.py --files database/tests/05_mutations_experiments_smoke_test.sql database/tests/07_strict_compliance_smoke_test.sql
./.venv/Scripts/python.exe database/scripts/run_tests.py --files database/packages/spec/pkg_genetics_game.pks database/packages/body/pkg_genetics_game.pkb
```

University-stand notes:

- DBeaver 21.2.1 may fail on `SET DEFINE OFF` and a single `/` even when the SQL file is correct;
- package body and smoke-tests are safer when executed as a whole script, not fragment-by-fragment with Ctrl+Enter;
- some stands use SID-based Oracle connection strings rather than `service_name`, so the runner accepts both `ORACLE_SERVICE` and `ORACLE_SID`.

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

After successful `01..06` smoke-tests, the baseline PL/SQL backend MVP is covered by smoke checks. Continue with `07..11` for strict compliance, sessions, LR2 API compatibility, rating event history, and offspring preview.

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

## 14) Run rating events smoke-test

```sql
@database/tests/10_rating_events_smoke_test.sql
```

This smoke-test validates the explainable wallet/rating event log:
- required `ref_rating_event_types`;
- `get_rating_events_cursor`;
- `MUTATION_PURCHASE`, `TASK_REWARD`, and `MUTAGEN_PENALTY` events;
- event deltas matching aggregate `labs.wallet` / `labs.rating` changes for the tested scenario;
- repeat task completion does not duplicate rewards;
- foreign lab access is blocked.

## 15) Run offspring preview smoke-test

```sql
@database/tests/11_offspring_preview_smoke_test.sql
```

This smoke-test validates the stateless offspring preview added for level-4 hardening:
- `preview_offspring_options` returns 3 options by default;
- option rows include species, phenotype summary, genotype summary and the `PREVIEW_SAMPLE` marker; they deliberately do not claim a probability for a complete offspring genotype;
- preview does not create creatures, genotypes, experiments, or change wallet/rating;
- custom option counts are bounded safely;
- normal `crossbreed` still works after preview;
- foreign lab access and invalid parent choices are blocked.
## 16) Inspect compile errors via USER_ERRORS

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


## Recovery after a client/browser crash

The web client handles a stale lab lock through explicit `recover_lab_access` confirmation for one selected own laboratory. This operation transfers only that lab, leaves both authentication sessions active, and does not affect another user's sessions or any other laboratory.

Normal `load_lab` never performs recovery automatically: an occupied lab returns `-20072`. Session and lab-row locking keeps the check and transfer atomic for concurrent Oracle connections.

### DEV-only: close all stale ACTIVE sessions for one user

The broad maintenance script remains available for old clients that cannot call the selected-lab recovery API:

```sql
@database/scripts/dev_unlock_stale_sessions.sql
```

Notes:
- This script is **DEV ONLY** and is not part of mandatory smoke-tests.
- It only closes `sessions.status='ACTIVE'` for the chosen login.
- It does **not** delete labs/creatures/genotypes/experiments/lab_tasks/lab_mutations.
- It is not used by the web client's normal conflict flow.

## Full smoke-test order

After the versioned installer succeeds, the default Python runner discovers and
runs the complete numbered suite (`01..29`) in order:

```powershell
.\.venv\Scripts\python.exe database\scripts\run_tests.py
```

Test 29 verifies the installed v3 reference contract and schema marker. The
runner is a validation tool and is not executed during a normal Docker start.

The SQL runner uses one Oracle connection. Run the additional test below to verify simultaneous attempts from independent physical connections, selected-lab takeover, and abandoned-browser recovery:

```powershell
.\.venv\Scripts\python.exe database\tests\test_multiuser_session_concurrency.py
```

## Versioned task catalogue

`TASKS.GENETICS_VERSION` distinguishes the historical catalogue (`1`) from
the universal-morphology catalogue (`3`). Migration 11 marks all existing
tasks as v1 and then seeds 12 v3 catalogue entries. It preserves existing
`LAB_TASKS`, markers, rewards, and task IDs.

Task evaluation is version-aware: v1 tasks keep the historical rule that a
marker allele may appear in either genotype slot, while v3 tasks require the
marker allele to be the expressed phenotype. The evaluator is selected by
`TASKS.GENETICS_VERSION`, not by `LABS.GENETICS_VERSION`, for compatibility
with manually assigned historical tasks. The normal runtime assignment policy
is stricter: a v1 laboratory receives and refills only v1 tasks, while a v3
laboratory receives and refills only v3 tasks. Thus, standard `LAB_TASKS`
always have the same genetics version as their laboratory.

Current v3 task markers use only `FULL` dominance genes. `nutrition_type`
remains a canonical v3 gene, but it is `CODOMINANT` and deliberately has no v3
task markers yet. A future extension must define whether each component of a
codominant phenotype is separately eligible for a marker before such tasks are
added.

```sql
@database/migrations/11_add_task_genetics_version.sql
@database/tests/22_versioned_v3_task_catalog_smoke_test.sql
```
