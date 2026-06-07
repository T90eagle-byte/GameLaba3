# Project Roadmap: GameLR3 / BioAssembly

## Completed Stages

### 1. Backend strict-pass
- `pkg_genetics_game` is the central backend API.
- Package spec/body compile.
- `user_errors` is empty.
- Smoke tests `01..08` were green after stabilization.

### 2. Content compliance
- Seed covers the required species, genes, alleles, mutations, tasks, and markers.
- `mutation_rules` and `task_markers` cover universal traits and `species_type 1..6`.
- Mixed mutation rules were split into coherent species-specific mutations.

### 3. Economy
- `buy_mutation`, `apply_mutation`, and `apply_mutagen` are handled by PL/SQL.
- RADIATION: cost 50, rating_delta -5.
- CHEMICAL: cost 100, rating_delta -2.
- Task auto-complete can add wallet/rating rewards after experiments.

### 4. Multiuser
- Session-bound lab access is complete.
- One lab cannot be opened in two ACTIVE sessions.
- `ORA-20072` and `ORA-20073` have Russian GUI messages.
- Dev-only stale session script exists.

### 5. GUI foundation
- Main screens and tabs are implemented.
- Python remains GUI/display-layer.
- All gameplay operations go through `pkg_genetics_game`.

### 6. User-friendly polish
- Onboarding and empty states.
- Lighter tables.
- Mission screen for tasks.
- Laboratory journal for history.
- Scenario flow for experiments and mutations.
- Creature portraits and Creature Art Pass 2.

### 7. Post-polish stabilization
- Mutations compact portrait balanced: readable, centered, not full-width stretched.
- Tasks checked-creature portrait replaced with compact-thumbnail and empty text state.
- GUI logic for tasks and mutations was not changed; these are display-layer fixes only.

## Current Stage: Final delivery preparation
Goal: prepare the repository and instructions for submission/transfer without adding large new features.

Allowed:
- docs cleanup;
- run instructions cleanup;
- repository hygiene fixes;
- small GUI/UX/stability fixes only if a blocker is found.

Not allowed without a separate decision:
- backend changes;
- DDL changes;
- seed/test changes;
- new dependencies;
- new real genes, alleles, colors, or mechanics;
- moving business logic into Python.

## Final Delivery Tasks
- Verify `.gitignore`.
- Verify `requirements.txt`.
- Verify `database/README_RUN.md`.
- Verify no temporary repair files are present.
- Final `python -m compileall -f python_client`.
- Final mojibake marker-check.
- Final manual GUI check.
- Final Oracle `01..08` if required for submission or if SQL files changed.
- Prepare for GitLab/university PC transfer.

## Future Optional Tracks
- Expand dashboard into a richer progress panel.
- Content expansion: more alleles, colors, traits, and tasks.
- Mutagen diversity pass: more mutagen scenarios.
- Economy balancing: tune penalties and rewards.
- Strict task typing: a separate DDL/backend track for FIND/BREED/MUTATE if creature origin must be checked.
