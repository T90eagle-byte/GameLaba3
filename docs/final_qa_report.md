# Final QA report

## 1. Goal

Final pre-defense QA/stabilization pass for GameLR3 / GameLaba3 / Biosborka.

This pass was not a feature-development stage. The goal was to verify the product from a clean point, run backend and web checks, exercise the main gameplay mechanics, identify defects, and document the result.

## 2. Environment

- Branch: `final-qa-stabilization`
- Base commit: `fa5fa82` (`Merge branch 'web-client-polish-defense'`)
- Polish commit in history: `6d1c217` (`Otpolirovat web-client dlya zashchity`)
- Oracle: `localhost:1521/FREEPDB1`, user `biosborka`
- Python: `3.12.9`
- Check date: 2026-07-07

## 3. Backend checks

| Check | Result | Comment |
|---|---|---|
| `run_tests.py --dry-run` | OK | Runner sees package spec/body and tests `01..11`. |
| Full backend runner | OK | All tests completed with `Failed: 0`. |
| Package status | OK | `PACKAGE VALID`, `PACKAGE BODY VALID`. |
| `user_errors` | OK | Clean. |

Backend runner covered:

- auth/labs;
- seed data;
- creature generation;
- crossbreed;
- mutations/experiments;
- tasks;
- strict compliance;
- multiuser/session isolation;
- LR2 package API compatibility;
- rating events;
- offspring preview.

## 4. Web checks

| Check | Result | Comment |
|---|---|---|
| `python -m compileall -f web_client` | OK | Web client compiles. |
| `python -m compileall -f python_client` | OK | Existing desktop client compiles. |
| `python -m py_compile database\\scripts\\run_tests.py` | OK | Backend runner compiles. |
| `git diff --check` | OK | No whitespace problems before QA report creation. |
| Mojibake marker-check | OK | `HITS=0`. |
| Gameplay SQL check | OK | Only `select 1 from dual` health-check is present. |
| `web_client/smoke_test.py` | OK | Full smoke completed. |
| Live Flask startup | OK | `/health`, `/login`, `/register`, `/about-requirements` returned 200. |
| Extended QA web flow | OK | Positive and negative route/form scenarios passed. |

## 5. Checked mechanics

| Mechanic | Status | Comment |
|---|---|---|
| Auth | OK | Register/login/logout work; wrong password does not create a session. |
| Protected routes | OK | Gameplay routes redirect to login without a session. |
| Labs | OK | Lab creation and selected lab flow work. |
| Dashboard | OK | Opens with selected lab and shows backend-provided stats. |
| Creatures | OK | List/detail work; invalid creature id does not traceback. |
| Tasks / client orders | OK | Check, complete and repeat-complete scenarios do not traceback; backend remains source of truth. |
| Crossbreed preview | OK | Preview returns exactly 3 options and does not create a creature. |
| Real crossbreed | OK | Real crossbreed creates offspring and history is available. |
| Crossbreed negatives | OK | Same parent, missing ids and incompatible parents do not traceback. |
| Mutations | OK | Shop, buy, apply and invalid mutation forms do not traceback. |
| Mutagens | OK | `RADIATION` and `CHEMICAL` routes work through backend. |
| Experiments | OK | History contains `CROSS`, `MUTATION`, `MUTAGEN` after actions. |
| Rating events | OK | Events include `TASK_REWARD`, `MUTATION_PURCHASE`, `MUTAGEN_PENALTY`. |
| Requirements page | OK | Public route opens and states that grade 5 is not claimed. |

## 6. Found issues

| ID | Severity | Area | Description | Status | Fix |
|---|---|---|---|---|---|
| QA-001 | Note | Tooling | In-app browser automation tool was not available in this Codex session, so visual inspection was approximated by live Flask HTTP checks and Flask test-client route checks. | Accepted | No product change required. |

Critical and major defects were not found.

## 7. Fixes in this QA pass

No application bug fixes were required.

Created this QA report only.

## 8. Current version limitations

- Grade 5 is not claimed as implemented.
- Web client is a thin client/display layer.
- Business logic remains in Oracle PL/SQL package `pkg_genetics_game`.
- Web does not calculate genetics, rating, wallet, prices, penalties or mutation effects.
- Direct SQL in web remains limited to technical health-check `select 1 from dual`.

## 9. Final conclusion

The project is ready for defense from the QA perspective checked in this pass.

Backend is green on tests `01..11`; package is valid; `user_errors` is clean. Web smoke and extended gameplay flow passed. No critical or major defects were found.

Recommended final defense route:

1. Run backend runner.
2. Run `web_client/smoke_test.py`.
3. Start `web_client/app.py`.
4. Show `/dashboard`, `/creatures`, `/tasks`, `/crossbreed`, `/mutations`, `/experiments`, `/rating-events`, `/about-requirements`.
