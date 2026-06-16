# Current Tasks

## Текущий статус
Проект находится на контрольной точке после backend-аудита, подготовки expansion-plan и добавления воспроизводимого runner для backend smoke-tests.

Уже закрыто:
- backend compliance audit;
- `STANDARD_HASH` вместо `DBMS_CRYPTO`;
- ref-tables `ref_*` и backend labels из БД;
- LR2-compatible package API;
- перенос прямых SQL-вызовов из `pkg_api.py` в package;
- docs-fix по `README_RUN`, `database_map`, roadmap и gameplay notes;
- Python runner `database/scripts/run_tests.py`.

## Главная незакрытая точка
Нужен живой Oracle-прогон smoke-tests `01..09`.

Что известно сейчас:
- локально runner подготовлен и dry-run проверен;
- package/spec/body и docs согласованы;
- локальный честный прогон против Oracle не выполнен из-за недоступности рабочего Oracle окружения в текущей машине;
- поэтому статус backend считается подготовленным к прогону, но не окончательно подтверждённым live-run результатом.

## Что запускать на стенде
Полный прогон:
- `./.venv/Scripts/python.exe database/scripts/run_tests.py`

Точечный прогон спорных тестов:
- `./.venv/Scripts/python.exe database/scripts/run_tests.py --files database/tests/05_mutations_experiments_smoke_test.sql database/tests/07_strict_compliance_smoke_test.sql`

## Следующий технический этап
Вариант 1:
- выполнить живой Oracle-прогон `01..09`;
- зафиксировать реальные результаты;
- только потом решать, нужны ли backend-fix или test-fix.

Вариант 2:
- если прогон подтверждает стабильность, переходить к безопасным seed/content quick wins из `docs/backend_expansion_plan.md`.

Отложено до отдельного решения:
- web-клиент;
- крупный DDL-трек `rating_events`;
- расширение provenance/task-origin модели;
- новые большие backend-механики.

## Правила текущей контрольной точки
- Не переносить бизнес-логику из Oracle PL/SQL в Python.
- Не начинать web-клиент в этой задаче.
- Не менять package/DDL/seed/tests без доказанной необходимости.
- Не трогать `.env`.
- Не хардкодить Oracle host/port/SID/service name в коде или docs как источник истины.
