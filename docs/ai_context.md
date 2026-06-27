# AI Context: GameLR3 / «БиоСборка»

## Workspace
- Актуальный workspace: `C:\GameLR3`.
- Основная ветка: `main`.
- Коммиты писать на русском языке.
- Не коммитить `.env`, `.venv`, `__pycache__`, временные файлы и backup-файлы.

## Архитектура
- Backend реализован на Oracle PL/SQL.
- Центральный backend API: `pkg_genetics_game`.
- Python/PySide6 остается client/display-layer: не считает генетику, мутации, задания, экономику или рейтинг.
- Будущий переносимый клиент должен быть web-клиентом через браузер, но web-клиент пока не начат.
- Бизнес-логика должна оставаться в Oracle PL/SQL package.

## Причина будущего web-клиента
- На учебном стенде Windows Server 2012 R2 PySide6/Qt6 ненадежен из-за ошибок загрузки `QtGui/QtWidgets`.
- Desktop GUI не удалять: он остается локальной desktop-версией.
- Для пересдачи и переносимости следующий клиентский трек должен идти через браузер.

## Закрытая backend-фаза
Backend-фаза завершена и зафиксирована в `main`.

Выполнено:
- `STANDARD_HASH` используется вместо `DBMS_CRYPTO`.
- `DBMS_CRYPTO` отсутствует в package body.
- Доменные справочники `ref_*` вынесены в БД и связаны FK.
- LR2-compatible wrappers добавлены в package API.
- Прямые SQL-запросы к игровым таблицам убраны из `pkg_api.py`.
- Первый seed-only backend/content expansion выполнен.
- `rating_events` реализован как explainable log для изменений `labs.wallet` и `labs.rating`.
- `database/scripts/run_tests.py` запускает package/seed/tests через `python-oracledb`, читает подключение из `python_client/.env`, поддерживает `ORACLE_SERVICE` и `ORACLE_SID`.
- Runner корректно обрабатывает UTF-8 BOM, SQL*Plus-директивы и одиночный `/`.

## Финальная сверка backend
- Главный актуальный документ по соответствию backend требованиям: `docs/backend_final_requirements_review.md`.
- Старый `docs/backend_compliance_audit.md` оставлен как предварительный исторический аудит.
- Финальная сверка зафиксировала: backend соответствует ЛР1/ЛР2 с честными адаптациями под текущую session-token модель.

Подтвержденные проверки после rating-events:
- Полный Oracle runner `01..10` прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Важные ограничения для следующего этапа
- Не переносить бизнес-логику в Python/web/frontend.
- Web-клиент должен вызывать server-side слой, который обращается к `pkg_genetics_game`.
- Браузер не должен напрямую подключаться к Oracle.
- `rating_events` — журнал объяснения изменений, не замена `labs.wallet` и `labs.rating`.
- `display_names.py` остается fallback/display layer, не source of truth для gameplay.

## Следующая фаза
Следующий этап после паузы:
1. Создать `docs/web_client_plan.md`.
2. Спроектировать минимальный web-client architecture поверх `pkg_genetics_game`.
3. Затем делать минимальный Flask/Jinja web-каркас.

Пока не делать:
- не начинать web-клиент без плана;
- не добавлять новые genes/alleles/mutations/tasks;
- не менять DDL/package/seed/tests/PySide6 GUI без отдельной задачи;
- не переносить бизнес-логику в Python.
