# Current Tasks

## Current Status
The project is past GUI/graphics polish and color expansion stabilization. Final GUI onboarding/help hints are being added before delivery preparation.

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
- Color expansion display stabilization.

## Current Work
Final GUI onboarding/help hints:
- Dashboard shows the first-run route through creatures, experiments/mutations, tasks, and history;
- Creatures explain phenotype, genotype, inheritance, and color variants;
- Genetic Experiment, Mutations, Tasks, and History tabs explain their workflow in compact help cards;
- statistics, quick actions, task checks, mutagens, and journal filters have useful tooltips;
- all changes are GUI/display-layer only.

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
- Do not change seed unless a new content task explicitly requires it.
- Do not change tests `01..08` unless a tested contract truly changes.
- Do not change `pkg_api.py`.
- Do not add dependencies, assets, genes, alleles, colors, or mechanics.
- Do not move business logic into Python.

## Final Transfer Preparation Status
- Verify `.gitignore`, root `requirements.txt`, and `database/README_RUN.md` before the final commit.
- Root `requirements.txt` should install the Python GUI dependencies through `python_client/requirements.txt`.
- Final checks before transfer: `git status --short`, `python -m compileall -f python_client`, mojibake marker-check, temp-file check, manual GUI check.
- Oracle `01..08` smoke-tests are recommended for final proof.
- If only GUI/display docs changed, Oracle tests are not required for that step.
