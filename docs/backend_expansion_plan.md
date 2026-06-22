# Backend Expansion Plan: GameLR3 / BioAssembly

## Purpose

This document describes a practical one-month backend expansion plan for `pkg_genetics_game` and the Oracle schema around it.

The plan follows the current architecture:

- Oracle PL/SQL remains the source of gameplay logic.
- Python remains a client and display layer.
- No gameplay rules should be moved into Python or a future web frontend.
- Web client preparation means backend stability and API clarity, not browser-side genetics.

## Completed Quick Win Checkpoint

The first safe backend/content expansion has been completed and confirmed by a live Oracle smoke-run.

Confirmed checkpoint:

- backend compliance audit is done;
- backend expansion planning is done;
- `database/scripts/run_tests.py` is added and fixed for reproducible seed/package/test execution;
- the first seed-only content expansion is implemented without DDL or package changes;
- seed through runner passed;
- `02_seed_data_smoke_test.sql`: `Passed: 32`, `Failed: 0`;
- `07_strict_compliance_smoke_test.sql`: `Passed: 46`, `Failed: 0`;
- full Oracle smoke suite `01..09` passed with `Failed: 0`;
- `PKG_GENETICS_GAME` package and package body are `VALID`;
- `user_errors` is clean.

The next large backend track is rating foundation / `rating_events`. It should be handled as a separate DDL/backend/test stage, not mixed with another content expansion.

## Current BaselineThe current backend already provides:

- authentication, sessions, and lab ownership;
- species, genes, alleles, genotypes, phenotype cache;
- crossbreeding with linkage support;
- directed mutations and mutagens;
- task markers and task completion rewards;
- experiment history;
- domain reference tables `ref_*`;
- LR2-compatible package wrappers;
- smoke-tests `01..09`.

That baseline is strong enough for content growth. The next month should focus on extending content safely before introducing major schema changes.

## Safe Quick Wins

These are the most useful changes with the best risk/reward ratio.

### 1. Expand existing allele families

Type:

- seed-only;
- new tests for new combinations;
- optional small GUI label updates only if display text is unclear.

Recommended additions:

- `size`: add an explicit intermediate allele such as `medium_size`.
  Reason: the gene already uses `INCOMPLETE`; adding a true midpoint fits the current phenotype logic naturally.
- `nutrition_type`: add one or two extra diet alleles only if task wording stays marker-based.
  Good candidates: `omnivore`, `filter_feeder`.
- species genes:
  - cartilaginous fish `fin_shape`: add a third allele for a more unusual fin profile;
  - bony fish `fin_shape`: add a third allele for a narrow or elongated tail fin;
  - crustacean `claw_form`: add a third allele for asymmetric or hooked claws;
  - mollusk `beak_nose_shape`: add a third allele for a flattened or spiral profile wording;
  - turtle `shell_armor`: add a third shell variant;
  - mammal `fur_density`: add a third coat density.

Why this is safe:

- current schema already supports more than two alleles per gene;
- `crossbreed`, `get_genotype_cursor`, `calculate_punnett_probabilities`, and marker-based tasks already work with allele IDs, not hardcoded pair counts;
- this mostly increases content variety without changing package contracts.

Main caution:

- do not add a third logical state to `has_wings` without package and cache review, because `phenotype_has_wings` is currently a `Y/N` cache field.

### 2. Expand tasks using existing marker logic

Type:

- seed-only;
- tests update for seed counts if needed.

Recommended additions:

- more single-trait discovery tasks for the new color set:
  - red specimen;
  - white specimen;
  - black specimen;
  - purple specimen;
- more two-marker combination tasks:
  - winged herbivore;
  - large bony fish with forked fin;
  - compact mammal with dense fur;
  - turtle with spiked shell and slow speed;
- more three-marker rare-combo tasks per species.

Rules for wording:

- use "find/present/select a creature with traits ...";
- do not claim the backend verifies that the creature was bred or mutated to obtain those traits.

Why this is safe:

- `tasks`, `task_markers`, `check_task`, and `complete_task` already support marker combinations well;
- no DDL is needed if tasks remain marker-based.

### 3. Expand mutation catalog without new mechanics

Type:

- mostly seed-only if mutation behavior is still "replace target allele by rule";
- tests `05` and `07` should be extended only if new mutation rows become mandatory in expectations.

Recommended additions:

- one extra color mutation for a non-green target color;
- one extra size mutation toward intermediate size if `medium_size` is added;
- one extra species-specific morphology mutation per species family;
- one extra diet mutation only if diet allele family is expanded carefully.

Why this is safe:

- current mutation behavior is rule-based through `mutation_rules`;
- new rows can reuse the same package logic if they still mean directed allele replacement.

### 4. Increase starting variation

Type:

- package body change;
- tests `03`, `04`, `05`, `07` may need review;
- no DDL required if output counts stay the same.

Recommended changes:

- keep `30` starting creatures and current species coverage;
- widen allele randomness in `generate_starting_creatures` and/or `create_creature_of_type`;
- bias a few rare combinations to appear occasionally but not reliably.

Why this is useful:

- the project becomes more replayable without changing external package contracts;
- future tasks can rely on a richer starting pool.

Main caution:

- do not make starter generation so random that smoke-tests become flaky.

## First Quick Win Batch: Completed

The first implemented batch stayed inside the existing data model.

Added alleles:

- `medium_size`;
- `crescent_fin`;
- `ribbon_fin`;
- `ridged_armor`;
- `hooked_claws`;
- `spiral_profile`;
- `plated_shell`;
- `soft_fur`.

Added directed mutations:

- `red_color_mutation`;
- `medium_size_mutation`;
- `cartilaginous_crescent_fin_mutation`;
- `bony_ribbon_fin_mutation`;
- `hooked_claws_mutation`;
- `spiral_profile_mutation`;
- `plated_shell_mutation`;
- `soft_fur_mutation`.

Added marker-based tasks:

- `task_red_specimen`;
- `task_medium_specimen`;
- `task_winged_red_specimen`;
- `task_crescent_fin_cartilaginous`;
- `task_ribbon_fin_bony`;
- `task_hooked_crustacean`;
- `task_spiral_mollusk`;
- `task_plated_turtle`;
- `task_soft_fur_mammal`.
## Medium-Scope Backend Improvements

These are still realistic within a month, but they touch package logic and need focused test work.

### 1. Better phenotype expressiveness

Type:

- package body;
- possibly seed-only additions;
- tests `03`, `04`, `07`.

Recommended changes:

- improve `get_phenotype` summaries so incomplete and codominant results read more naturally;
- use explicit midpoint alleles where possible instead of fallback `intermediate(...)` text;
- standardize summary ordering so text is stable across runs.

Main caution:

- keep existing cache fields `phenotype_color`, `phenotype_size`, `phenotype_has_wings`, `phenotype_nutrition_type` intact for GUI compatibility.

### 2. Rare phenotype recognition

Type:

- package body;
- maybe seed-only if rarity is inferred from allele combinations;
- tests `03`, `04`, `05`, `07`.

Recommended approach:

- compute rarity from existing genotype patterns rather than adding a new table immediately;
- expose rarity first as package-internal logic used for rewards or history text;
- only add schema if rarity must be stored permanently.

Use cases:

- bonus rating for first rare phenotype in a lab;
- tasks that ask for unusual combinations;
- future collection progression.

### 3. Mutation balance pass

Type:

- seed plus package body if pricing/reward rules need stronger coupling;
- tests `05` and `07`.

Recommended changes:

- rebalance mutation prices against reward density;
- review whether some mutations should reduce rating and others increase it;
- keep `RADIATION` and `CHEMICAL` distinct in both economy and predictability.

Main caution:

- do not change mutagen semantics casually; `05` and `07` already exercise them tightly.

## Large DDL / Backend Changes

These should be planned explicitly and not implemented silently.

### 1. Strict task provenance

Goal:

- distinguish tasks of type FIND, BREED, and MUTATE;
- let backend verify not only traits, but also origin.

Why current model is insufficient:

- `check_task` currently validates allele markers only;
- task wording cannot honestly promise that a creature was produced by breeding or mutation.

Recommended DDL track:

- add `task_mode` or `task_origin_rule` to `tasks`;
- add creature provenance fields, for example:
  - `origin_experiment_id`;
  - `origin_action_type`;
  - maybe `origin_parent1_id`, `origin_parent2_id` only if needed.

Required backend work:

- update `crossbreed`, `apply_mutation`, `apply_mutagen`, `make_experiment`, and `check_task`;
- add tests for FIND/BREED/MUTATE behavior.

Risk:

- touches core gameplay flow and several smoke-tests at once.

### 2. Rating history and explainability

Goal:

- make rating changes auditable and understandable.

Recommended DDL:

- add `rating_events`:
  - `rating_event_id`;
  - `lab_id`;
  - `event_type`;
  - `delta`;
  - `related_task_id` nullable;
  - `related_experiment_id` nullable;
  - `details`;
  - `created_at`.

Events that should change rating:

- task completion;
- rare phenotype discovery;
- first discovery of a new trait family in a lab;
- risky mutagen usage;
- successful hard combination;
- collection diversity milestones.

Why this should not be done blindly:

- current rating is stored as aggregate only;
- once history exists, package writes must stay transactionally consistent with lab aggregate updates.

### 3. Collection discoveries

Goal:

- support "first time found" rewards and collection progression.

Recommended DDL:

- `lab_discoveries` or similar table keyed by lab and discovery code.

Possible discovery codes:

- new color discovered;
- first winged specimen;
- first rare phenotype;
- first species-specific elite combination.

Why this is useful:

- enables progression without moving logic to GUI;
- also useful for a future web client.

### 4. Richer mutagen system

Goal:

- move beyond two fixed mutagen modes only when the core package is already stable.

Possible future directions:

- targeted instability profiles by gene family;
- multi-step mutation chains;
- temporary lab-wide mutagen effects.

Why not now:

- likely requires DDL and a broader rebalance of tests `05` and `07`;
- higher risk than content expansion on top of the current rule model.

## What Not to Add Yet

These ideas are attractive, but they are poor next steps for the current codebase.

- A third persistent wings state without changing `phenotype_has_wings`.
- Frontend-only rarity, breeding provenance, or mutation compatibility rules.
- Deep epistasis or multi-gene suppression rules that require rewriting `get_phenotype`.
- Direct browser access to Oracle for the future web client.
- New mechanics that bypass `pkg_genetics_game`.

## Backend Impact Matrix

### Seed-only candidates

- new allele rows for existing genes;
- new tasks and task markers;
- new mutation rows and mutation rules that still map to existing allele replacement semantics;
- reward and cost balancing if semantics stay the same.

### Package body candidates

- richer starter generation;
- better phenotype summary rules;
- rarity inference based on genotype;
- more nuanced rating formulas if they can still be explained from current aggregates.

### DDL candidates

- strict task provenance;
- rating history;
- discovery tracking;
- any trait that requires new persistent cache fields beyond current phenotype columns.

### Test work required

- seed changes: at least `02`, then whichever gameplay tests cover the affected content;
- package body changes: usually `03`, `04`, `05`, `06`, `07`, and sometimes `09`;
- DDL changes: fresh deploy plus full `01..09`.

## GUI / Future Web Client Compatibility Risks

Safe for current GUI and future web client:

- more alleles in existing genes;
- more tasks using current marker model;
- more mutation catalog entries using current rule semantics;
- better backend display labels from package cursors.

Needs coordination with clients:

- any new phenotype cache field;
- any change to cursor column order;
- any origin-sensitive task behavior exposed to users;
- rating history screens or new discovery/history views.

GUI-neutral but backend-visible:

- rarity logic if it only affects rating or task completion;
- more experiment history detail if added as extra cursor fields without removing old ones.

## Recommended Order for the Next Month

### Week 1: low-risk content growth

- add new allele variants to selected existing genes;
- add new marker-based tasks;
- add a few mutation rows that reuse existing mutation semantics;
- extend seed checks if counts or mandatory content assumptions change.

### Week 2: phenotype and variation pass

- improve phenotype text generation in package body;
- introduce explicit midpoint alleles where incomplete dominance should show a clean label;
- rebalance starter generation for more variation without changing counts.

### Week 3: rating and rarity design

- decide whether rarity is computed-only or persisted;
- if computed-only, prototype package-only rarity bonuses first;
- if persisted history is required, finalize DDL for `rating_events` before implementation.

### Week 4: provenance and strict tasks design

- decide whether strict BREED/MUTATE tasks are worth the schema cost;
- if yes, define provenance DDL and package changes as a separate milestone;
- do not mix provenance DDL with smaller content expansion in the same commit.

## First Implementation Batch: Completed

The first safe backend/content batch has already been implemented and confirmed by tests.

Implemented scope:

1. added `medium_size` to the existing universal `size` gene;
2. added third variants to selected species-specific genes;
3. added directed mutations that target those new alleles;
4. added marker-based tasks using the new variants;
5. updated seed consistency tests without depending on random starter generation.

Confirmed result:

- no DDL changes;
- no package spec/body changes;
- no `pkg_api.py` changes;
- full Oracle smoke suite `01..09` passed with `Failed: 0`.

Still postponed:

- new genes;
- strict task provenance;
- `rating_events`;
- web client implementation.