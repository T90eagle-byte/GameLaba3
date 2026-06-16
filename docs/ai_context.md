# AI Context: GameLR3 / «БиоСборка»

## Workspace
- Актуальный workspace: `C:\GameLR3`.
- Старый путь под `C:\Users\User\DATA` не использовать как рабочий ориентир в задачах.
- Коммиты писать на русском языке.

## Архитектура
- Backend реализован на Oracle PL/SQL.
- Центральный backend API: `pkg_genetics_game`.
- Python-клиенты должны оставаться client/display-layer.
- Бизнес-логика генетики, мутаций, заданий, экономики и рейтинга не переносится из PL/SQL в Python.
- Текущий PySide6 GUI сохраняется как desktop-версия.
- Следующий переносимый клиент планируется как web-клиент через браузер, но он ещё не реализуется на этой контрольной точке.

## Причина смены стратегии клиента
- На учебном стенде Windows Server 2012 R2 PySide6/Qt6 оказался ненадёжным вариантом из-за ошибок загрузки `QtGui/QtWidgets` даже после установки VC_redist.
- Поэтому для пересдачи и переносимости основной будущий путь — web-клиент, работающий поверх уже стабилизированного Oracle backend.
- Desktop GUI не удаляется и остаётся полезной локальной версией.

## Что уже стабилизировано
- `STANDARD_HASH` используется вместо `DBMS_CRYPTO`.
- `DBMS_CRYPTO` отсутствует в package body.
- Доменные справочники `ref_*` вынесены в БД.
- LR2-compatible wrappers добавлены в package API.
- Прямые SQL-запросы к игровым таблицам убраны из `pkg_api.py`.
- Python GUI остаётся display-layer only.
- Подготовлен `docs/backend_compliance_audit.md`.
- Подготовлен `docs/backend_expansion_plan.md`.
- Обновлены `docs/current_tasks.md`, `docs/project_roadmap.md`, `docs/gameplay_rules.md`.
- Обновлён `database/README_RUN.md`.
- Добавлен `database/scripts/run_tests.py` для воспроизводимого запуска backend smoke-tests `01..09`.

## Backend Test Runner
- Runner читает подключение из `python_client/.env`.
- Поддерживаются оба варианта подключения: `ORACLE_SERVICE` и `ORACLE_SID`.
- Runner нужен в том числе для стендов, где DBeaver 21.2.1 нестабилен на `SET DEFINE OFF` и одиночном `/`.
- Основная команда полного прогона на стенде:
  - `./.venv/Scripts/python.exe database/scripts/run_tests.py`
- Точечный прогон спорных тестов:
  - `./.venv/Scripts/python.exe database/scripts/run_tests.py --files database/tests/05_mutations_experiments_smoke_test.sql database/tests/07_strict_compliance_smoke_test.sql`

## Текущая контрольная точка
- Backend-аудит выполнен.
- Expansion plan подготовлен.
- Runner для backend-тестов добавлен.
- Живой Oracle-прогон `01..09` локально не выполнен, потому что в текущем окружении не были доступны рабочие Oracle endpoints / Docker daemon / `sqlplus` / `sqlcl`.
- Поэтому главный текущий риск — нужен честный живой Oracle-прогон `01..09` на стенде или на машине с доступной БД.

## Ограничения учебного стенда
- ОС: Windows Server 2012 R2 Datacenter.
- Python: 3.12 x64.
- SQL-клиент: DBeaver 21.2.1.
- Oracle connection может использовать host/port/SID, например SID `ORCL`; реальные значения брать только из `.env` и не хардкодить.
- DBeaver может ошибаться на `SET DEFINE OFF` и одиночном `/`.
- Package body и smoke-tests надёжнее запускать целиком или через Python runner.
- Будущий web-клиент тоже должен читать подключение из `.env` и поддерживать SID/service_name.

## Следующий технический этап
- Приоритет 1: выполнить живой Oracle-прогон `01..09` и зафиксировать реальный статус backend.
- Приоритет 2: если backend smoke-tests зелёные, переходить к безопасным quick wins из `docs/backend_expansion_plan.md`.
- Крупный DDL-трек `rating_events` и похожие расширения отложены до подтверждения стабильности backend.

## Что пока не делать
- Не начинать backend-content expansion без отдельного решения.
- Не начинать web-клиент в рамках этой контрольной точки.
- Не менять package, DDL, seed, tests и GUI без явной необходимости.
- Не трогать `.env`.
