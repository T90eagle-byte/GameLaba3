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
- Python files that contain Cyrillic must be saved as UTF-8.
- Before backend/content/GUI changes, re-check LR1/LR2 requirements and current docs.
- Do not add external libraries or assets without separate approval.

## Stable State
- Backend strict-pass is closed: package spec/body compile and `user_errors` is empty.
- Oracle smoke tests `01..08` were green after stabilization.
- Content compliance is closed: seed covers universal traits and `species_type 1..6`.
- Color expansion pass adds 8 real backend/content alleles for the universal `color` gene: green, blue, red, yellow, purple, orange, white, black.
- Economy pass is closed: buy/apply mutation, mutagens, rating, and task auto-complete are handled by PL/SQL.
- Multiuser strict-pass is closed: session-bound lab access, `ORA-20072`, and `ORA-20073` are handled.
- `get_experiment_history` returns real `experiments.created_at`.
- Mixed `mutation_rules` were split into coherent species-specific mutations.
- Test `05` is reward-aware for mutagen auto-complete rewards.
- GUI opens, creates, and deletes normal labs; stale sessions are handled through the dev-only unlock script.
- Closing with X works and `ORA-20072` is not reproduced for normal labs.

## GUI State
- Implemented screens: Auth, Lab Selection, Main Shell, Creatures, Genetic Experiment, Mutations, Tasks, Experiment History.
- `Back to labs` returns to lab selection without logout.
- `Logout` calls `logout_user`.
- Closing the window with X performs safe logout, clears `SessionState`, and closes connection.
- MainWindow initialization failures are handled with safe session cleanup.
- Dev-only stale session script exists: `database/scripts/dev_unlock_stale_sessions.sql`.
- Technical user-facing phrases about Oracle/PLSQL/backend were removed from ordinary GUI screens; connection errors may still mention Oracle.

## Display and Polish
- Display localization is handled through `python_client/app/services/display_names.py`.
- Task difficulty is GUI/display classification, not DB schema.
- Task wording is honest: current backend checks creature traits by `task_markers`, not creature origin.
- GUI completed Dashboard/Stabilization, Missions + Journal, Experiment + Mutations, and Creature Display / Art polish.
- `CreaturePortraitWidget` is display-layer only and supports paper-style portraits with `large`, `compact`, and `mini` modes.
- Visual style is paper-lab notebook inspired by the mood of Alchemy on Paper, without copying assets or interface.
- Creature Art Pass 2 is complete: fish, crustaceans, mollusks, turtles, and mammals use more recognizable QPainterPath/Bezier silhouettes.
- Display-only variation is based on existing creature data such as `creature_key`; it does not add gameplay traits.

## Latest GUI/Art Fixes
- Mutations tab compact portrait was balanced after Art Pass 2:
  - `CreaturePortraitWidget` compact `sizeHint` is about `440x220`.
  - default compact canvas limit is about `460x230`.
  - Mutations tab uses canvas limit `560x260` and minimum size `500x230`.
  - portrait is centered and no longer stretches to the full card width.
- Tasks tab checked-creature portrait was improved:
  - old mini icon was replaced with compact-thumbnail.
  - canvas limit is `340x190`, minimum size is `300x170`.
  - portrait is hidden until a creature is selected.
  - empty state text says to select a creature for task checking.
- These fixes did not change `check_task`, `complete_task`, backend calls, genotype, phenotype, or DB data.
- GUI onboarding/help hints were added as display-layer only: help cards and tooltips explain mechanics already implemented in PL/SQL.

## Current Stage
Final GUI onboarding/help hints and delivery preparation.

Current GUI-help notes:
- concise paper-style help cards explain the game loop without mentioning backend internals;
- Dashboard route: Creatures -> Genetic Experiment / Mutations -> Tasks -> History;
- Creatures tab explains phenotype, genotype, inheritance, and color variants;
- Experiment, Mutations, Tasks, and History tabs explain their workflows as display-layer hints;
- these hints do not add mechanics and do not move business logic into Python.

Next steps:
- run final `python -m compileall -f python_client`;
- run mojibake marker-check for GUI, services, seed, tests, and docs;
- perform final manual GUI check;
- prepare repository for GitLab/university PC transfer.

Do not change without explicit reason after this color-pass:
- backend package spec/body;
- DDL;
- additional seed/test content;
- `pkg_api.py`;
- dependencies;
- additional real genes, alleles, colors, or mechanics.

## Required Checks
- `git status --short`.
- `python -m compileall -f python_client`.
- Mojibake marker-check for GUI and docs.
- Check that no temporary repair files are tracked or present.
- Check that old Qt header enum style is not used in Python code.
- Check that `__pycache__` and `.venv` are not tracked by git.

## Final Transfer Preparation Checkpoint
- Root `requirements.txt` delegates to `python_client/requirements.txt`.
- `.gitignore` includes local venv, env files, Python cache, logs, backup files, mojibake repair leftovers, patch scripts, and temporary text files.
- `database/README_RUN.md` documents workspace, Python GUI setup, local `.env`, Oracle run order, smoke-test order `01..08`, and dev stale-session unlock script.
- Final preparation changed docs/config only, but the following color-pass intentionally changes seed/tests and GUI display files.
- The color-pass does not change backend package spec/body, DDL, `pkg_api.py`, or gameplay mechanics outside the real color allele content.
