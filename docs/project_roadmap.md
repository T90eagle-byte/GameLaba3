# Project Roadmap: GameLR3 / «БиоСборка»

## Completed Stages

### 1. Backend stabilization
- `pkg_genetics_game` is the central backend API.
- Package spec/body compile.
- `STANDARD_HASH` replaced `DBMS_CRYPTO`.
- Smoke-tests `01..09` were green before the rating-events track.

### 2. Domain reference tables
- Domain enum values are stored in `ref_*` tables.
- Package cursors return display labels from DB.
- Python is not the source of truth for gameplay enums.

### 3. LR2 package compatibility
- LR2-compatible wrappers were added to the package.
- Direct SQL calls to gameplay tables were removed from `pkg_api.py`.
- Python remains client/display-layer.

### 4. Desktop GUI delivery
- PySide6 GUI remains the desktop client.
- Because Windows Server 2012 R2 is unreliable for Qt6, future portable delivery should use a browser web client.
- Web client is not started in the current backend task.

### 5. Backend audit, runner, and content expansion
- Backend compliance audit and expansion plan are documented.
- `database/scripts/run_tests.py` runs package/tests reproducibly.
- First seed-only backend content expansion was merged and verified by `01..09`.

## Current Stage: Rating Foundation / `rating_events`
This stage adds an explainable backend log for economy/rating changes.

Scope:
- add `ref_rating_event_types` and `rating_events`;
- keep `labs.wallet` and `labs.rating` as current aggregates;
- write events from package code after existing aggregate updates;
- expose history through `get_rating_events_cursor`;
- add smoke-test `10_rating_events_smoke_test.sql`;
- extend runner to `01..10`.

## Postponed
- Web client implementation.
- Automatic rare trait bonuses beyond reserved `RARE_TRAIT_BONUS` event type.
- Strict provenance tasks for BREED/MUTATE.
- Another content expansion wave.
