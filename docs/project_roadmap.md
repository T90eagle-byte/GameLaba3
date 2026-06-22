# Project Roadmap: GameLR3 / «БиоСборка»

## Уже завершённые этапы

### 1. Backend stabilization
- `pkg_genetics_game` является центральным backend API.
- Package spec/body согласованы и компилируются.
- `STANDARD_HASH` заменил `DBMS_CRYPTO`.
- Подготовлены smoke-tests `01..09`.

### 2. Domain reference tables
- Доменные enum-значения вынесены в `ref_*` таблицы.
- Package cursors возвращают display labels из БД.
- Python не является источником истины для игровых enum-справочников.

### 3. LR2 package compatibility
- В package добавлены LR2-compatible wrappers.
- Прямые SQL-запросы к игровым таблицам убраны из `pkg_api.py`.
- Python остаётся клиентом/display-layer.

### 4. Desktop GUI delivery
- PySide6 GUI реализован и локально пригоден как desktop-клиент.
- Основные игровые вкладки, портреты существ и onboarding-подсказки завершены.
- GUI не удаляется и остаётся рабочей локальной версией.

### 5. Backend audit and planning
- Подготовлен `docs/backend_compliance_audit.md`.
- Подготовлен `docs/backend_expansion_plan.md`.
- Обновлены docs по запуску БД и карте схемы.
- Добавлен `database/scripts/run_tests.py` для воспроизводимого запуска package/tests.

## Текущая стадия: backend checkpoint before expansion
Цель текущей стадии — сохранить стабильный backend checkpoint и не потерять контекст перед следующим крупным этапом.

Что уже есть:
- backend-аудит завершён;
- expansion-plan подготовлен;
- runner для smoke-tests добавлен;
- структура проекта подготовлена к будущему web-клиенту без переноса бизнес-логики в Python.

Что ещё нужно:
- живой Oracle-прогон smoke-tests `01..09`;
- подтверждение стабильности package на учебном стенде;
- после этого — решение, идём ли в safe content expansion или сразу в web-client foundation.

## Ограничения учебного стенда
- Windows Server 2012 R2 Datacenter.
- Python 3.12 x64.
- DBeaver 21.2.1.
- DBeaver может некорректно исполнять скрипты с `SET DEFINE OFF` и одиночным `/`.
- PySide6/Qt6 не считается надёжным вариантом для пересдачи на этом стенде.
- Поэтому долгосрочный переносимый клиент — web-клиент через браузер.

## Следующие этапы

### Ближайший обязательный этап
- Выполнить живой Oracle smoke-run `01..09` через стенд или рабочее Oracle окружение.

### После подтверждения стабильности
- Safe seed/content expansion quick wins из `docs/backend_expansion_plan.md`.
- Подготовка backend contracts для будущего web-клиента.

### Отложенные крупные треки
- `rating_events` и история рейтинга.
- Строгая provenance-модель для задач BREED/MUTATE.
- Более крупные DDL-изменения для расширенной игровой прогрессии.
- Сам web-клиент как отдельный этап после подтверждения backend stability.

## Active Quick Win Batch
Current branch: `backend-content-expansion-quick-wins`.

Goal:
- increase gameplay variety through existing backend data model;
- keep `pkg_genetics_game` API unchanged;
- keep expansion marker-based and honest until strict task provenance is implemented as a separate DDL/backend track.
