# Project Roadmap

## 1) Backend baseline

- Oracle DDL, seed data, package spec/body, and smoke-tests `01..06` were completed as baseline.
- Backend architecture remains package-oriented with `pkg_genetics_game` as the central logic entry point.

## 2) Strict compliance pass (no DDL)

The following strict-alignment updates were implemented:

- `start_new_lab` now initializes a full starter lab (`30` creatures + `3` ACTIVE tasks).
- `generate_starting_creatures` is protected from duplicate re-run creation.
- gameplay API now uses session-aware access checks without public spec changes.
- phenotype semantics were aligned for `FULL`, `INCOMPLETE`, and `CODOMINANT`.
- `apply_mutagen` now has explicit behavior split for `RADIATION` vs `CHEMICAL` and validates unknown type.
- automatic task check/completion was added after experiment flow (`crossbreed`, `apply_mutation`, `apply_mutagen`).
- smoke-tests `01`, `03`, `04`, `05`, `06` were updated.
- new `database/tests/07_strict_compliance_smoke_test.sql` was added.

## 3) Oracle validation stage

Required run sequence:

1. `@database/packages/body/pkg_genetics_game.pkb`
2. smoke-tests `01..07`
3. `USER_ERRORS` verification

Goal: confirm strict-pass behavior in real Oracle runtime with no regressions.

## 4) Python GUI stage (after Oracle strict pass)

- Oracle connection and package API calls;
- screens: auth, labs, creatures, genotype/phenotype, crossbreed, mutations, tasks, experiment history;
- no backend/business logic in Python.

## 5) Optional DDL track (separate approval)

If strict LR requirements require creature generation tracking (`generation`), this should be implemented as a separate DDL change set with:
- schema update;
- targeted package adjustments;
- smoke-test updates.