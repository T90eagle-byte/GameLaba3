# Project Roadmap

## 1) Backend strict-pass

Статус: **завершен и подтвержден на реальном Oracle**.

- `pkg_genetics_game` package spec/body компилируются успешно.
- `USER_ERRORS` для `PKG_GENETICS_GAME` пустой.
- Smoke-tests `01..07` проходят с `Failed: 0`.
- Backend полностью остается в Oracle PL/SQL.
- Добавлен механизм refill ACTIVE-заданий:
  - после `complete_task` backend пытается восстановить до `3` ACTIVE задач;
  - новые задачи назначаются только из еще неназначенных `tasks`;
  - дубликаты `task_id` для одной лаборатории не создаются;
  - при исчерпании пула задач backend корректно оставляет меньше 3 ACTIVE.

## 2) GUI этапы (выполнено)

Уже реализовано в desktop GUI (PySide6 + python-oracledb thin):
- Auth window;
- Lab Selection window;
- Main Window Shell;
- вкладка «Существа»;
- вкладка «Генетический эксперимент»;
- вкладка «Мутации»;
- вкладка «Задания».

## 3) Архитектурный принцип (фиксированный)

- Python является только GUI-клиентом.
- Игровая логика остается в Oracle PL/SQL.
- Все игровые действия проходят через API `pkg_genetics_game`.
- Используется один стабильный Oracle connection на сессию GUI.

## 4) Следующий этап GUI

Следующая реализация:
- вкладка **«История экспериментов»**.

## 5) Правило языка интерфейса

- Пользовательские тексты и элементы GUI — на русском.
- Английский только для технических идентификаторов, API, DB-полей и enum-значений.

## 6) Отдельный DDL-трек (по решению)

Поле `generation` в `creatures` остается отдельным DDL-этапом и не входит в текущий GUI-срез.

## 7) Content Compliance Pass (LR2)

Status: completed at seed/test level (no DDL migrations and no package spec/body changes).

Result:
- expanded mutation/task content coverage;
- closed trait/species coverage gaps from LR2 KB matrix;
- added coverage checks to `02_seed_data_smoke_test` and `07_strict_compliance_smoke_test`.

Next:
- confirm run on real Oracle;
- proceed with next GUI feature slice (for example, Experiment History tab).

## GUI Localization Pass (2026-05-26)

Статус: выполнен (без изменений DDL и package API).

Что сделано:
- Seed-описания переведены на русский (genes/mutations/tasks).
- Добавлен единый модуль отображения кодов: python_client/app/services/display_names.py.
- Во вкладках GUI переведены отображаемые технические значения:
  - gene/trait/phenotype summary;
  - task/mutation display names;
  - experiment/task/mutagen статусы.

Архитектурный принцип сохранён:
- backend-правила и расчёты — только Oracle PL/SQL;
- Python — только отображение и вызов API.
