# Backend Compliance Audit: предварительный аудит

Дата исходного аудита: 2026-06-16
Статус: исторический документ.

## Важно

Этот файл оставлен как предварительный audit/checkpoint. Главный актуальный документ по соответствию backend требованиям ЛР1/ЛР2 теперь:

- `docs/backend_final_requirements_review.md`

Финальная сверка учитывает изменения, которые были сделаны после этого предварительного аудита:

- `STANDARD_HASH` вместо `DBMS_CRYPTO`;
- справочники `ref_*` и FK;
- LR2-compatible package API;
- seed-only content expansion;
- `rating_events`;
- backend runner для tests `01..10`;
- свежий полный Oracle-прогон `01..10` с `Failed: 0`;
- package status `VALID` и clean `user_errors`.

## Исторический вывод

Предварительный аудит выявил основные направления доработки:

- убрать прямые SQL-запросы из Python-клиента;
- вынести доменные справочники в БД;
- добавить LR2-compatible wrappers;
- заменить `DBMS_CRYPTO` на более переносимый `STANDARD_HASH`;
- подготовить воспроизводимый запуск package/tests;
- зафиксировать, что будущий web-клиент должен быть только display/client layer.

Эти пункты закрыты последующими backend-коммитами и финально сверены в `docs/backend_final_requirements_review.md`.

## Текущее правило

При расхождении этого файла с текущей реализацией или другими docs использовать как source of truth:

1. `database/ddl/01_create_tables.sql`;
2. `database/packages/spec/pkg_genetics_game.pks`;
3. `database/packages/body/pkg_genetics_game.pkb`;
4. `database/tests/01..10_*.sql`;
5. `docs/backend_final_requirements_review.md`.
