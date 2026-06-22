# AI Context: GameLR3 / «БиоСборка»

## Workspace
- Актуальный workspace: `C:\GameLR3`.
- Коммиты писать на русском языке.
- `.env`, `.venv`, `__pycache__`, временные файлы и backup-файлы не коммитить.

## Архитектура
- Backend реализован на Oracle PL/SQL.
- Центральный backend API: `pkg_genetics_game`.
- Python остаётся client/display-layer: не считает генетику, мутации, задания, экономику или рейтинг.
- PySide6 GUI сохраняется как desktop-версия.
- Будущий основной переносимый клиент — web-клиент через браузер, но web-клиент ещё не начинался.
- Бизнес-логика должна оставаться в Oracle PL/SQL package.

## Причина будущего web-клиента
- На учебном стенде Windows Server 2012 R2 PySide6/Qt6 ненадёжен из-за ошибок загрузки `QtGui/QtWidgets`.
- Для пересдачи и переносимости основной будущий клиент должен работать через браузер.
- Desktop GUI не удалять: он остаётся локальной версией.

## Стабильный backend baseline
- `STANDARD_HASH` используется вместо `DBMS_CRYPTO`.
- `DBMS_CRYPTO` отсутствует в package body.
- Доменные справочники `ref_*` вынесены в БД и связаны FK.
- LR2-compatible wrappers добавлены в package API.
- Прямые SQL-запросы к игровым таблицам убраны из `pkg_api.py`.
- `database/scripts/run_tests.py` запускает package/seed/tests через `python-oracledb` и читает подключение из `python_client/.env`.
- Runner поддерживает `ORACLE_SERVICE` и `ORACLE_SID`.

## Backend Test Runner
- Runner корректно обрабатывает UTF-8 BOM.
- Standalone SQL*Plus-директивы игнорируются через whitelist: `set define off`, `set verify on/off`, `set serveroutput on ...`, `show errors`, `prompt`, `whenever ...`.
- Одиночный `/` используется как разделитель PL/SQL-блока и не отправляется в Oracle.
- При ошибке runner пытается вывести `DBMS_OUTPUT`, чтобы падения smoke-tests были диагностируемыми.

## Завершённый content expansion checkpoint
Первый безопасный backend/content expansion завершён без DDL и без package changes.

Добавлены аллели существующих генов:
- `medium_size`;
- `crescent_fin`;
- `ribbon_fin`;
- `ridged_armor`;
- `hooked_claws`;
- `spiral_profile`;
- `plated_shell`;
- `soft_fur`.

Добавлены directed mutations:
- `red_color_mutation`;
- `medium_size_mutation`;
- `cartilaginous_crescent_fin_mutation`;
- `bony_ribbon_fin_mutation`;
- `hooked_claws_mutation`;
- `spiral_profile_mutation`;
- `plated_shell_mutation`;
- `soft_fur_mutation`.

Добавлены marker-based задания:
- `task_red_specimen`;
- `task_medium_specimen`;
- `task_winged_red_specimen`;
- `task_crescent_fin_cartilaginous`;
- `task_ribbon_fin_bony`;
- `task_hooked_crustacean`;
- `task_spiral_mollusk`;
- `task_plated_turtle`;
- `task_soft_fur_mammal`.

## Подтверждённые проверки
- Seed через runner прошёл.
- `02_seed_data_smoke_test.sql`: `Passed: 32`, `Failed: 0`.
- `07_strict_compliance_smoke_test.sql`: `Passed: 46`, `Failed: 0`.
- Полный Oracle smoke suite `01..09` прошёл: все тесты с `Failed: 0`.
- `PKG_GENETICS_GAME` package и package body находятся в `VALID`.
- `user_errors` чистый.
- `python -m compileall -f python_client` прошёл.
- `python -m py_compile database\scripts\run_tests.py` прошёл.
- `git diff --check` прошёл.
- Mojibake marker-check прошёл: `HITS=0`.

## Текущий следующий этап
Следующий крупный backend этап: rating foundation.

Цель будущего этапа:
- добавить объяснимую историю рейтинга;
- спроектировать/реализовать `rating_events` отдельным DDL/backend треком;
- подготовить backend данные для будущего web dashboard.

Пока не делать:
- не начинать web-клиент;
- не добавлять новые гены/аллели/мутации/задания;
- не менять package, DDL, seed, tests или PySide6 GUI без отдельной задачи;
- не переносить бизнес-логику в Python.