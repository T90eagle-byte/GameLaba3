# Current Tasks

## Current Stage
Backend-фаза закрыта. Проект готов к паузе или к следующей фазе: planning web-клиента.

## Backend Checkpoint
- `backend-rating-events` влит в `main`.
- `rating_events` реализован как backend-журнал объяснения изменений экономики и рейтинга.
- `labs.wallet` и `labs.rating` остаются aggregate state.
- `rating_events` не заменяет агрегаты, а объясняет изменения.
- `RARE_TRAIT_BONUS` зарезервирован, но не начисляется автоматически.

## Актуальные документы
- Главный документ по соответствию backend требованиям: `docs/backend_final_requirements_review.md`.
- `docs/backend_compliance_audit.md` является предварительным/историческим аудитом.
- `docs/database_map.md` описывает актуальную структуру БД, `ref_*`, `difficulty_code`, `rating_events` и package cursors.
- `database/README_RUN.md` описывает runner и запуск tests `01..10`.

## Подтвержденные проверки
- Полный Oracle runner `01..10` прошел с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.
- `STANDARD_HASH` используется вместо `DBMS_CRYPTO`.
- Прямые SQL-запросы к игровым таблицам в `pkg_api.py` отсутствуют.

## Следующая фаза
Следующий шаг — не backend-доработки, а web-client planning:
1. Создать `docs/web_client_plan.md`.
2. Зафиксировать архитектуру web-клиента как display/client layer поверх `pkg_genetics_game`.
3. После утверждения плана сделать минимальный Flask/Jinja web-каркас.

## Не делать без отдельной задачи
- Не менять DDL, seed, package spec/body и smoke-tests.
- Не начинать web-клиент без `docs/web_client_plan.md`.
- Не переносить генетику, экономику, рейтинг или задания в Python/web/frontend.
- Не удалять PySide6 GUI: он остается desktop-версией.
- Не добавлять новую волну backend content expansion.
