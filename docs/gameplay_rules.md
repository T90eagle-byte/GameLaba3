# Gameplay Rules

## Core Rule
All gameplay rules live in Oracle PL/SQL package `pkg_genetics_game`.

Python GUI and future web clients only call backend API and display returned data. They must not calculate genetics, tasks, wallet, rating, mutation effects or access rules.

## Creatures and Traits
Creatures have a species and phenotype built from genes/alleles/genotypes.

Universal traits:
- color;
- size;
- wings;
- nutrition type.

Species-specific traits are stored in the same `genes` / `alleles` / `genotypes` model and are scoped by `species_type`.

## Crossbreeding
- The player selects two parents.
- Backend checks session, lab access, parent ownership and compatibility.
- `calculate_punnett_probabilities` returns probability data for selected genes.
- `preview_offspring_options` returns stateless offspring previews and returns 3 options by default.
- Preview does not create creatures, genotypes, experiments and does not change wallet/rating or lab state.
- `crossbreed` creates the real offspring and records the experiment.

## Tasks as Client Orders
Tasks are marker-based backend checks. A task describes the requested organism, task markers define required traits, and `check_task` / `complete_task` validate the creature against those markers.

For defense and future web UI, the task screen should be presented as “Заказы клиента”. Current backend verifies the final traits; it does not yet enforce strict provenance such as “this exact creature must have been created by a specific crossbreed operation”.

## Evolutionary Line
The project adapts “evolutionary line” to the multi-species “БиоСборка” model:
- the lab starts with generated creatures;
- the player selects parents and mutates organisms;
- `experiments` stores CROSS/MUTATION/MUTAGEN history;
- `rating_events` stores economic/rating consequences;
- the final creature is submitted to a client order.

A future web page can show this as a timeline without adding new backend rules.

## Mutations and Mutagens
Directed mutations:
- bought through `buy_mutation`;
- applied through `apply_mutation`;
- follow backend `mutation_rules`.

Mutagens:
- `RADIATION` is riskier and has wallet/rating penalty;
- `CHEMICAL` is more controlled and also has a cost/penalty;
- both are implemented in package logic and recorded in experiments.

## Rating and Economy
`labs.wallet` and `labs.rating` remain aggregate state.

`rating_events` is an explainable event log for changes:
- task rewards;
- mutation purchases;
- mutagen penalties;
- future system adjustments.

Clients may display `get_rating_events_cursor`; they must not calculate deltas themselves.

## Level 5 Scope
The current version does not implement ecosystem mechanics, creature death, ethics council or automatic lab closure. Those are roadmap ideas and should not be claimed as implemented for defense.
