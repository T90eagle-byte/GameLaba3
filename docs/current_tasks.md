# Current Tasks

## Current Status
The project is in final Acceptance polish before submission.

Closed stages:
- Backend strict-pass.
- Content compliance pass.
- Economy pass.
- Multiuser strict-pass.
- History `created_at` fix.
- Display localization.
- Session/logout GUI fixes.
- Mixed `mutation_rules` split.
- Reward-aware stabilization of test `05`.
- Dashboard/Stabilization GUI polish.
- Missions + Journal polish.
- Experiment + Mutations polish.
- Creature Display / Art Pass 2.

## Current Work
- Verify the full GUI without adding large new features.
- Fix only small UX, stability, or documentation issues.
- Keep the paper-lab visual style.
- Verify that technical backend architecture wording is not shown to regular GUI users except connection errors.
- Verify that closing the GUI with X does not leave the lab locked.

## Acceptance Checklist
- Auth: login, registration, errors, placeholders.
- Lab Selection: create, open, delete lab, logout.
- Main Shell: stats, quick actions, clear hints.
- Creatures: table, selected card, large portraits, phenotype badges, genotype cards, ID for duplicate names.
- Genetic Experiment: choose parents, choose gene, show probabilities, create child, see notifications.
- Mutations: shop, buy, selected creature, compact portrait, compatibility, mutation, RADIATION, CHEMICAL.
- Tasks: filter, mission card, mini portrait, check and complete task.
- History: journal entries, type badges, date/time, details card, empty-state.
- Closing: close with X, reopen same lab, no `ORA-20072`.

## Final Stage Rules
- Do not change backend package spec/body.
- Do not change DDL.
- Do not change seed.
- Do not change tests `01..08`.
- Do not change `pkg_api.py`.
- Do not add dependencies, assets, genes, alleles, or mechanics.
- Do not move business logic into Python.

## Checks
- `python -m compileall -f python_client`.
- Mojibake marker-check.
- Temporary repair file check.
- Old Qt header enum style check.
- Oracle run is needed only if SQL, seed, tests, or backend changed.
