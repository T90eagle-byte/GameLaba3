# Current Tasks

## Current Status
The project is past GUI/graphics polish and is ready for final delivery preparation.

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
- Mutations compact portrait sizing fix.
- Tasks checked-creature compact-thumbnail fix.

## Current Work
Final delivery preparation:
- verify repository hygiene;
- verify launch/run docs;
- verify dependencies;
- verify no temporary repair files are present;
- run final Python checks;
- run final GUI check;
- run Oracle tests only if SQL/seed/tests/backend changed or if final submission requires a fresh DB proof.

## Acceptance Checklist
- Auth: login, registration, errors, placeholders.
- Lab Selection: create, open, delete lab, logout.
- Main Shell: stats, quick actions, clear hints.
- Creatures: table, selected card, large portraits, phenotype badges, genotype cards, ID for duplicate names.
- Genetic Experiment: choose parents, choose gene, show probabilities, create child, see notifications.
- Mutations: shop, buy, selected creature, compact portrait, compatibility, mutation, RADIATION, CHEMICAL.
- Tasks: filter, mission card, compact-thumbnail for checked creature, check and complete task.
- History: journal entries, type badges, date/time, details card, empty-state.
- Closing: close with X, reopen same lab, no `ORA-20072`.

## Final Repository Checklist
- `git status --short`.
- `python -m compileall -f python_client`.
- Mojibake marker-check on GUI and docs.
- Confirm absence of:
  - `fix_*.py`;
  - `patch_*.py`;
  - `*.bak_mojibake*`;
  - `tmp_rus_test.txt`;
  - tracked `__pycache__`;
  - tracked `.venv`.
- Confirm old Qt enum style is absent:
  - `QHeaderView.Stretch`;
  - `QHeaderView.ResizeToContents`;
  - `QHeaderView.Interactive`;
  - `QHeaderView.Fixed`.
- Verify `.gitignore`.
- Verify `requirements.txt`.
- Verify `database/README_RUN.md`.

## Final Stage Rules
- Do not change backend package spec/body.
- Do not change DDL.
- Do not change seed.
- Do not change tests `01..08`.
- Do not change `pkg_api.py`.
- Do not add dependencies, assets, genes, alleles, colors, or mechanics.
- Do not move business logic into Python.
