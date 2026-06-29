# Current Tasks

## Current Stage
Ближайшая фаза — завершить проверку backend hardening под уровень “хорошо” (4), затем перейти к планированию web-клиента. Web-клиент пока не начинать.

## Почему не сразу web
Backend уже стабилен и прошел финальную сверку, но перед переносом в web нужно сделать защиту требований уровня 4 максимально ясной:
- показать “заказы клиента” через существующую систему заданий;
- объяснить “эволюционную линию” как последовательность скрещиваний/мутаций до нужного фенотипа;
- подготовить короткий demo script для пересдачи;
- подготовить requirements cheatsheet;
- P0 по трём вариантам потомства закрыт через stateless backend API `preview_offspring_options`, который по умолчанию возвращает 3 варианта без изменения состояния лаборатории.

## Backend Checkpoint
- `backend-rating-events` влит в `main`.
- `rating_events` реализован как backend-журнал объяснения изменений экономики и рейтинга.
- `labs.wallet` и `labs.rating` остаются aggregate state.
- Полный Oracle runner `01..11` должен быть прогнан после hardening; предыдущий стабильный checkpoint `01..10` проходил с `Failed: 0`.
- `PKG_GENETICS_GAME`: `PACKAGE VALID`, `PACKAGE BODY VALID`.
- `user_errors`: clean.

## Актуальные документы
- Главный документ по соответствию backend требованиям: `docs/backend_final_requirements_review.md`.
- Аудит уровней оценки: `docs/grade_requirements_audit.md`.
- `docs/backend_compliance_audit.md` является предварительным/историческим аудитом.
- `docs/database_map.md` описывает актуальную структуру БД, `ref_*`, `difficulty_code`, `rating_events` и package cursors.

## Не делать в текущей фазе
- Не менять DDL/seed без отдельной причины; package/test изменения допустимы только для завершения offspring preview hardening.
- Не добавлять требования на 5: экосистему, смертность, совет по этике, закрытие лаборатории.
- Не начинать Flask/Jinja до отдельной команды.
- Не переносить генетику, экономику, рейтинг или задания в Python/web/frontend.
- Не удалять PySide6 GUI: он остается desktop-версией.

## Следующая фаза после hardening
После укрепления уровня 4:
1. Создать `docs/web_client_plan.md`.
2. Зафиксировать архитектуру web-клиента как display/client layer поверх `pkg_genetics_game`.
3. Делать минимальный Flask/Jinja web-каркас, простой и быстрый для слабого учебного стенда.
