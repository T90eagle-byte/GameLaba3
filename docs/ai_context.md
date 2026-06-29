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
- Будущий переносимый клиент должен быть web-клиентом через браузер, но web-код пока не начат.
- Бизнес-логика должна оставаться в Oracle PL/SQL package.

## Причина будущего web-клиента
- На учебном стенде Windows Server 2012 R2 PySide6/Qt6 ненадежен из-за ошибок загрузки `QtGui/QtWidgets`.
- Desktop GUI не удалять: он остается локальной desktop-версией.
- Для пересдачи и переносимости будущий клиент должен работать через браузер.
- Для слабого стенда предпочтителен простой Flask/Jinja интерфейс без тяжелого frontend-фреймворка.

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
- Stateless API `preview_offspring_options` добавлен и по умолчанию возвращает ровно 3 preview-варианта потомства.
- `database/scripts/run_tests.py` запускает package/seed/tests через `python-oracledb`, читает подключение из `python_client/.env`, поддерживает `ORACLE_SERVICE` и `ORACLE_SID`.

## Финальная сверка backend
- Главный актуальный документ по соответствию backend требованиям: `docs/backend_final_requirements_review.md`.
- Аудит уровней 3/4/5: `docs/grade_requirements_audit.md`.
- Аудит hardening уровня 4: `docs/level4_backend_hardening_review.md`.
- Уровень 3 закрыт уверенно.
- Уровень 4 закрыт железно и защищаемо: есть сложная генетика, неполное доминирование, кодоминирование, сцепленные гены, мутации, мутагены RADIATION/CHEMICAL, риск через wallet/rating, последствия через `rating_events`, задания как “заказы клиента”, эволюционная линия как путь через эксперименты и preview трёх вариантов потомства.
- Уровень 5 не заявлять как реализованный.

Подтвержденные проверки после offspring-preview hardening:
- Ветка `backend-offspring-preview` влита в `main` merge-коммитом `81d8293`.
- Полный Oracle runner `01..11` прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Текущая ближайшая фаза
Backend hardening уровня 4 завершен. Ближайшая фаза — проектирование легкого web-клиента без реализации web-кода в этом checkpoint.

Цели web planning:
- создать `docs/web_client_plan.md`;
- зафиксировать Flask/Jinja как простой server-side web поверх `pkg_genetics_game`;
- описать маршруты, страницы, сервисы и демонстрационный flow;
- сохранить правило: web не считает генетику, экономику, рейтинг и задания.

## Следующая фаза после плана
1. Реализовать минимальный Flask/Jinja skeleton.
2. Подключить auth/labs/dashboard.
3. Добавить creatures/tasks/crossbreed с preview трёх вариантов.
4. Добавить mutations/experiments/rating events.
5. Подготовить запуск на слабом учебном стенде.

## Важные ограничения
- Не реализовывать требования на 5 сейчас.
- Не добавлять экосистему, смертность, совет по этике или закрытие лаборатории.
- Не начинать web-реализацию без отдельной задачи.
- Не переносить бизнес-логику в Python/web/frontend.
- Не менять DDL/package/seed/tests/PySide6 GUI без отдельной задачи.
