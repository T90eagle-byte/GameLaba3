# Current Tasks

## Current Stage
Rating foundation / `rating_events` is in progress on branch `backend-rating-events`.

Goal:
- keep `labs.wallet` and `labs.rating` as aggregate state;
- add `rating_events` as an explainable backend log for wallet/rating changes;
- record events inside `pkg_genetics_game`, not in Python;
- cover the feature with `10_rating_events_smoke_test.sql`;
- extend the default runner from `01..09` to `01..10`.

## Already Stable
- Backend compliance audit is done.
- `STANDARD_HASH` replaced `DBMS_CRYPTO`.
- Domain refs `ref_*` are in DB.
- LR2-compatible package API exists.
- Direct SQL calls were removed from `pkg_api.py`.
- First seed-only content expansion is merged into `main`.
- Previous full Oracle smoke suite `01..09` was green before this new DDL track.

## Current Scope
Changing now:
- DDL: `ref_rating_event_types`, `rating_events`, `rating_events_seq`;
- seed: rating event type refs;
- package spec/body: rating event cursor/history and event writes;
- tests: new `10` plus reference/cleanup checks;
- docs/README.

Not changing now:
- PySide6 GUI/layout;
- web client;
- new genes/alleles/mutations/tasks;
- Python-side business logic.

## Next Gate
Before merging this branch:
- fresh deploy or compatible migration for the new DDL;
- package `VALID`;
- `user_errors` clean;
- full runner `01..10` with `Failed: 0`.
