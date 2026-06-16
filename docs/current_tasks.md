# Current Tasks

## Current Status
The project is past GUI polish, ref-table migration, LR2-compatible package API, and backend compliance audit. Current focus is backend stabilization, smoke-test confidence, and a practical expansion plan before future web-client work.

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
Backend stabilization and expansion planning:
- verify that `STANDARD_HASH`, `ref_*`, and LR2-compatible wrappers remain aligned;
- confirm that smoke-tests `05` and `07` still match reward-aware mutagen semantics;
- avoid new gameplay implementation unless it is clearly safe and does not require large DDL;
- prepare a month-long backend expansion plan for genes, mutations, tasks, and rating;
- keep Python as client/display-layer only.

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

## Current Stage Rules
- Do not move business logic into Python.
- Do not start a web client in this task.
- Do not change DDL or package contracts without a clear backend reason.
- Do not weaken smoke-tests without evidence that the old expectation is wrong.
- Do not touch `.env` or add local runner artifacts to git.

## Final Transfer Preparation Status
- Verify `.gitignore`, root `requirements.txt`, and `database/README_RUN.md` before the final commit.
- Root `requirements.txt` should install the Python GUI dependencies through `python_client/requirements.txt`.
- Final checks before transfer: `git status --short`, `python -m compileall -f python_client`, mojibake marker-check, temp-file check, manual GUI check.
- Oracle `01..08` smoke-tests are recommended for final proof.
- If only GUI/display docs changed, Oracle tests are not required for that step.
