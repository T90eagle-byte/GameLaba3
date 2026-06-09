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
- Universal color content is expanded to 8 real alleles: green, blue, red, yellow, purple, orange, white, black.

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

### 8. GUI onboarding/help hints
- Dashboard route explains the first-run loop: Creatures -> Experiment / Mutations -> Tasks -> History.
- Creatures tab explains phenotype, genotype, inheritance, and color variants.
- Experiment, Mutations, Tasks, and History tabs have compact paper-style workflow hints.
- Tooltips were added to key stats and controls.
- No backend, DDL, seed, tests, or `pkg_api.py` changes are part of this step.

## Current Stage: final delivery preparation
Goal: keep the project stable, run final checks, and prepare repository/instructions for submission/transfer.

Not allowed without a separate decision:
- backend package spec/body changes;
- DDL changes;
- `pkg_api.py` changes;
- seed/test changes;
- new dependencies;
- additional real genes, alleles, colors, or mechanics;
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
- Content expansion beyond the completed 8-color pass: more traits, tasks, and carefully designed allele families.
- Mutagen diversity pass: more mutagen scenarios.
- Economy balancing: tune penalties and rewards.
- Strict task typing: a separate DDL/backend track for FIND/BREED/MUTATE if creature origin must be checked.

## Delivery Preparation
Current delivery-prep scope is repository hygiene and transfer instructions only:
- `.gitignore` cleanup;
- root `requirements.txt`;
- `database/README_RUN.md` transfer/run notes;
- final verification checklist.

No new gameplay or large GUI feature work should be started before submission unless a blocker is found.
