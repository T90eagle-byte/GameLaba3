# Oracle schema: запуск и обновление

Текущий marker схемы — **14**. Этот документ описывает рабочие entry points,
а не историю отдельных этапов разработки.

Новые SQL/PLSQL изменения статически проверены на совместимость с Oracle 12.2.
Runtime validation на Oracle 12.2 должна быть выполнена на университетском
стенде.

## Подготовка

Из корня репозитория создайте локальный `python_client/.env` по примеру и
задайте параметры Oracle. Не коммитьте пароль, DSN или `.env`.

Для разработки установите зависимости проекта в `.venv`, чтобы использовать
`python-oracledb` runner.

## Canonical install/update

Остановите web-приложение перед изменением схемы.

| Состояние назначенной schema | Entry point SQL Developer / SQLcl |
| --- | --- |
| Пустая assigned schema | `database/installers/university_existing_schema_install.sql` |
| Существующая BioSborka schema | `database/installers/university_existing_schema_update.sql` |

Запускайте выбранный файл целиком (`F5`) под назначенным schema user. Update
path не создаёт и не удаляет Oracle user, не использует `TRUNCATE` и сохраняет
пользователей, лаборатории, существ, генотипы, сессии, эксперименты и историю.

Оба path используют общий порядок:

1. DDL для fresh schema, если он нужен;
2. migrations `01..14`;
3. production seeds `01..05`;
4. current package spec/body;
5. readiness validation;
6. запись marker `14` только после успешной validation.

Для диагностики существует общий файл
`database/installers/apply_current_schema_update.sql`; не заменяйте им
защищённые install/update entry points при развёртывании.

## Проверка готовности

После install/update проверьте:

```powershell
.\.venv\Scripts\python.exe database\scripts\check_runtime_readiness.py
```

Готовая schema имеет `schema.ready=true`, `PACKAGE VALID`, `PACKAGE BODY
VALID` и `USER_ERRORS=0`. Проверка также охватывает обязательные таблицы,
package signatures, migrations и reference/seed relationships. Demo-набор ЛР3
не является обязательной частью основной readiness:

```powershell
.\.venv\Scripts\python.exe database\scripts\check_lr3_demo_data.py
```

## Backend tests

Runner автоматически находит numbered smoke-tests `01..30` и перед запуском
полного набора компилирует package:

```powershell
.\.venv\Scripts\python.exe database\scripts\run_tests.py --dry-run
.\.venv\Scripts\python.exe database\scripts\run_tests.py
```

Для focused investigation используйте `--files`; например, Test 30 проверяет
связный v3 lifecycle с temporary fixture и exact cleanup:

```powershell
.\.venv\Scripts\python.exe database\scripts\run_tests.py --files database\tests\30_v3_end_to_end_acceptance_smoke_test.sql
```

Не запускайте полный runner как часть обычного startup или production update,
если это не согласованная release validation.

## Fresh и existing installations

Fresh install создаёт current schema сразу. Existing installation обновляется
только versioned migrations: historical laboratories сохраняют
`genetics_version=1`, новые лаборатории создаются v3. Не переустанавливайте
existing schema ради перехода на v3.
