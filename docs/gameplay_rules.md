# Gameplay Rules: GameLR3 / BioAssembly

## Core Principle
Gameplay logic is executed in Oracle PL/SQL through `pkg_genetics_game`.
Python GUI only calls backend API and displays returned data.

## Labs and Sessions
- User logs in and opens a lab.
- Lab stores creatures, mutations, tasks, and experiment history.
- One lab cannot be opened in another ACTIVE session.
- Closing GUI with X should perform safe logout.
- If an old GUI version left a stale session, dev environment can use `database/scripts/dev_unlock_stale_sessions.sql`.

## Creatures and Traits
- Creatures have species, phenotype, and genotype.
- Phenotype and genotype come from backend.
- GUI may translate technical values into Russian display labels, but it must not calculate genetics.
- `CreaturePortraitWidget` is display-layer only: it visualizes existing species and phenotype data without adding gameplay traits.
- Portrait details and display-only variation are not new genes, alleles, colors, or mechanics.

## Crossbreeding
- Player selects two parent creatures.
- Probability preview for the selected gene is calculated by backend.
- Selected gene is only for probability preview.
- Child inherits traits through backend operation over the full genotype.

## Mutations
- Mutation is a purchased directed trait change.
- `buy_mutation` spends coins and increases lab mutation stock.
- `apply_mutation` applies rules, decreases stock, creates experiment, and updates rating through backend.
- If target allele is already present, phenotype may not visibly change; backend still owns the operation result.
- GUI compatibility hints are display-level explanations based on backend data already loaded by the GUI.

## Mutagens
- Mutagens are experimental impacts.
- RADIATION: cost 50, rating_delta -5.
- CHEMICAL: cost 100, rating_delta -2.
- Backend may auto-complete matching tasks after mutagen impact and add rewards.

## Tasks
- Tasks are checked by `task_markers` against selected creature traits.
- Creature origin is not checked in the current model.
- Simple tasks are find/tutorial goals: find, select, or present a matching creature.
- Strict FIND/BREED/MUTATE task typing would be a separate DDL/backend track.
- Task difficulty is stored in DB via `tasks.difficulty_code`; GUI only displays the backend value.
- Checked-creature portrait in the Tasks tab is display-only and does not affect `check_task` or `complete_task`.

## History
- Experiment history displays backend records.
- `created_at` comes from `experiments.created_at`.
- Final wallet/rating changes may include task auto-complete rewards.

## Rating and Economy Events
- `labs.wallet` and `labs.rating` remain the current aggregate state.
- `rating_events` explains why those aggregates changed.
- Backend package records events for task rewards, mutation purchases, and mutagen penalties.
- Future web/GUI clients may display `get_rating_events_cursor`; they must not calculate deltas themselves.
- `RARE_TRAIT_BONUS` is reserved for a later backend rule and is not awarded automatically yet.

## First Safe Content Expansion
- This pass extends only existing genes through seed data.
- No new genes, DDL, package API, or client-side gameplay logic are introduced.
- New content adds `medium_size`, additional species-specific allele variants, directed mutations, and marker-based tasks.
- New task wording remains trait-based: find, select, or present matching creatures. Creature origin is still not checked by backend.
