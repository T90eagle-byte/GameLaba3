# Current Tasks

## Текущий статус
Первый безопасный backend/content expansion завершён и подтверждён живым Oracle-прогоном.

Закрыто:
- backend compliance audit;
- `STANDARD_HASH` вместо `DBMS_CRYPTO`;
- ref-tables `ref_*` и backend labels из БД;
- LR2-compatible package API;
- перенос прямых SQL-вызовов из `pkg_api.py` в package;
- backend-test runner для package/seed/tests;
- первый seed-only content expansion без DDL и без package changes.

## Подтверждённая контрольная точка
- Seed через runner прошёл.
- Smoke-test `02`: `Passed: 32`, `Failed: 0`.
- Smoke-test `07`: `Passed: 46`, `Failed: 0`.
- Полный Oracle smoke suite `01..09`: все тесты с `Failed: 0`.
- Package `PKG_GENETICS_GAME`: `VALID`.
- `user_errors`: clean.
- Runner пригоден для локального Docker Oracle и учебного стенда.

## Что изменилось в content expansion
Добавлены только данные существующей модели:
- новые allele codes для существующих genes;
- coherent directed mutations;
- честные marker-based tasks;
- fallback display labels в Python.

Не менялось:
- DDL;
- package spec/body;
- `pkg_api.py`;
- PySide6 GUI/layout;
- web-клиент.

## Следующий крупный этап
Rating foundation / `rating_events`.

Цель:
- сделать рейтинг объяснимым;
- добавить backend-историю изменений рейтинга;
- подготовить данные для будущего web dashboard.

## Правила перед следующим этапом
- Не начинать web-клиент одновременно с rating DDL.
- Не переносить расчёты рейтинга в Python.
- Не расширять контент снова без отдельной задачи.
- DDL/package/test changes для `rating_events` делать отдельным сфокусированным коммитом.