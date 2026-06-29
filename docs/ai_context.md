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
- `database/scripts/run_tests.py` запускает package/seed/tests через `python-oracledb`, читает подключение из `python_client/.env`, поддерживает `ORACLE_SERVICE` и `ORACLE_SID`.

## Финальная сверка backend
- Главный актуальный документ по соответствию backend требованиям: `docs/backend_final_requirements_review.md`.
- Аудит уровней 3/4/5: `docs/grade_requirements_audit.md`.
- Уровень 3 закрыт уверенно.
- Уровень 4 закрыт в основном, но перед web-этапом нужно укрепить защитные формулировки и демонстрацию вокруг “заказов клиента” и “эволюционных линий”.
- Уровень 5 не заявлять как реализованный.

Подтвержденные проверки после rating-events:
- Полный Oracle runner `01..10` прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Текущая ближайшая фаза
Сначала не web. Ближайшая фаза: hardening уровня 4 без изменения стабильного backend.

Цели hardening:
- явно оформить задания как “заказы клиента” в документах/демо;
- описать “эволюционную линию” как последовательность скрещиваний и мутаций для получения нужного фенотипа;
- подготовить defense demo script;
- подготовить requirements cheatsheet для уровней 3/4/5;
- проверить, как лучше показать 3 варианта потомства через текущие probabilities/preview.

## Следующая фаза после hardening
1. Создать `docs/web_client_plan.md`.
2. Спроектировать простой web-client architecture поверх `pkg_genetics_game`.
3. Затем сделать минимальный Flask/Jinja web-каркас.

## Важные ограничения
- Не реализовывать требования на 5 сейчас.
- Не добавлять экосистему, смертность, совет по этике или закрытие лаборатории.
- Не начинать web-клиент без отдельного плана.
- Не переносить бизнес-логику в Python/web/frontend.
- Не менять DDL/package/seed/tests/PySide6 GUI без отдельной задачи.
