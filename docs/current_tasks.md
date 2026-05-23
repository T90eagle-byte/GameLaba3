# Current Tasks

## 1) Current status

Strict compliance pass (no DDL changes) is implemented in code and test scripts.

Completed:
- `start_new_lab` now does all startup work:
  - creates lab;
  - assigns 3 starter `ACTIVE` tasks;
  - calls `generate_starting_creatures`.
- expected state right after `start_new_lab`:
  - `creature_count = 30`;
  - `active_task_count = 3`.
- `generate_starting_creatures` is idempotent and does not create a second batch of 30.
- gameplay access control is hardened via package session context:
  - `g_current_user_id`;
  - `g_current_session_id`;
  - `g_current_session_token`;
  - private helpers `require_current_session`, `assert_lab_access`, `assert_creature_access`.
- access checks were added to gameplay API without changing public package spec.
- `get_phenotype` dominance semantics are strict:
  - `FULL` -> numeric dominance;
  - `INCOMPLETE` -> intermediate phenotype for different alleles;
  - `CODOMINANT` -> both traits for different alleles.
- `apply_mutagen` now differentiates `RADIATION` and `CHEMICAL`; unknown type raises explicit error.
- auto task check is triggered after:
  - `crossbreed`;
  - `apply_mutation`;
  - `apply_mutagen`.
- startup flow (`start_new_lab`, initial generation) does not auto-complete tasks.
- smoke-tests updated for strict startup behavior:
  - `01`, `03`, `04`, `05`, `06`.
- new strict compliance test added:
  - `database/tests/07_strict_compliance_smoke_test.sql`.

## 2) Immediate next step

Run full Oracle validation after strict-pass changes:

1. `@database/packages/body/pkg_genetics_game.pkb`
2. `@database/tests/01_auth_labs_smoke_test.sql`
3. `@database/tests/02_seed_data_smoke_test.sql`
4. `@database/tests/03_creature_generation_smoke_test.sql`
5. `@database/tests/04_crossbreed_smoke_test.sql`
6. `@database/tests/05_mutations_experiments_smoke_test.sql`
7. `@database/tests/06_tasks_smoke_test.sql`
8. `@database/tests/07_strict_compliance_smoke_test.sql`

Compile checks:
- `show errors package pkg_genetics_game`
- `show errors package body pkg_genetics_game`
- `select * from user_errors where upper(name) = 'PKG_GENETICS_GAME'`

## 3) Next stage after successful strict run

Start Python GUI client (without moving business logic from PL/SQL):
- Oracle connection;
- auth window;
- lab selection/creation;
- creatures view + genotype/phenotype view;
- crossbreed, mutations, tasks, experiment history screens.

## 4) Open item requiring separate approval

If strict LR requirements require creature generation tracking (`generation` column), it will need DDL changes and a separate approved change set.