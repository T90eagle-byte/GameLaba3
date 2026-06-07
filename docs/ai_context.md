# AI Context: GameLR3 / BioAssembly

## Workspace
- Current workspace: `C:\GameLR3`.
- Do not use the old path under `C:\Users\User\DATA`.
- Git commit messages should be written in Russian.

## Architecture
- Backend is implemented in Oracle PL/SQL.
- Central backend API: `pkg_genetics_game`.
- Python is GUI client and display-layer only.
- Python must not calculate genetics, mutations, tasks, economy, rating, or statistics.
- All gameplay operations go through `pkg_genetics_game`.
- GUI must not read `dbms_output`.
- GUI user-facing text must stay Russian and UTF-8.
- English is allowed only for technical API, enum, DB fields, and developer docs.

## Stable State
- Backend strict-pass is closed: package spec/body compile and `user_errors` is empty.
- Oracle smoke tests `01..08` were green after stabilization.
- Content compliance is closed: seed covers universal traits and `species_type 1..6`.
- Economy pass is closed: buy/apply mutation, mutagens, rating, and task auto-complete are handled by PL/SQL.
- Multiuser strict-pass is closed: session-bound lab access, `ORA-20072`, and `ORA-20073` are handled.
- `get_experiment_history` returns real `experiments.created_at`.
- Mixed `mutation_rules` were split into coherent species-specific mutations.
- Test `05` is reward-aware for mutagen auto-complete rewards.

## GUI State
- Implemented screens: Auth, Lab Selection, Main Shell, Creatures, Genetic Experiment, Mutations, Tasks, Experiment History.
- `Back to labs` returns to lab selection without logout.
- `Logout` calls `logout_user`.
- Closing the window with X performs safe logout, clears `SessionState`, and closes connection.
- MainWindow initialization failures are handled with safe session cleanup.
- Dev-only stale session script exists: `database/scripts/dev_unlock_stale_sessions.sql`.

## Display and Polish
- Display localization is handled through `python_client/app/services/display_names.py`.
- Task difficulty is GUI/display classification, not DB schema.
- Task wording is honest: current backend checks creature traits by `task_markers`, not creature origin.
- GUI completed Dashboard/Stabilization, Missions + Journal, Experiment + Mutations, and Creature Art passes.
- `CreaturePortraitWidget` supports paper-style portraits with `large`, `compact`, and `mini` modes.
- Visual style is paper-lab notebook inspired by the mood of Alchemy on Paper, without copying assets or interface.

## Current Stage
Final Acceptance polish before submission.

Allowed now:
- small GUI/UX/stability fixes;
- styles cleanup;
- docs cleanup.

Do not change without explicit reason:
- backend package spec/body;
- DDL;
- seed;
- tests;
- `pkg_api.py`;
- dependencies;
- real genes, alleles, or mechanics.

## Required Checks
- `python -m compileall -f python_client`.
- Mojibake marker-check for GUI and docs.
- Check that no temporary repair files are tracked or present.
- Check that old Qt header enum style is not used in Python code.
