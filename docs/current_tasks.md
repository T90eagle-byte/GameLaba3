# Current Tasks

## 1) Текущий статус (checkpoint)

PL/SQL backend MVP реализован полностью.

Подтверждено на Oracle:
- DDL выполнен
- seed data загружен
- package specification и package body успешно компилируются
- smoke-tests `01..06` прошли успешно (`Failed: 0`)
- stubs / `Not implemented yet` в package body отсутствуют

Реализованы все группы API:
- auth/session
- labs
- creatures/genetics
- crossbreed
- mutations/experiments
- tasks

## 2) Последнее зафиксированное изменение

- `database/tests/01_auth_labs_smoke_test.sql` обновлен под новую логику `start_new_lab`:
  ожидается `active_task_count = 3`, так как лаборатории сразу назначаются 3 стартовые `ACTIVE` задачи.

## 3) Ближайший план

1. Зафиксировать успешный Oracle-прогон в Git.
2. Начать этап Python GUI-клиента:
   - подключение к Oracle;
   - окно авторизации;
   - выбор/создание лаборатории;
   - просмотр существ;
   - просмотр генотипа/фенотипа;
   - скрещивание;
   - мутации;
   - задания;
   - история экспериментов.

## 4) Точка входа в следующую сессию

- `database/README_RUN.md`
- `database/packages/spec/pkg_genetics_game.pks`
- `database/packages/body/pkg_genetics_game.pkb`
- `database/tests/01_auth_labs_smoke_test.sql`
- `database/tests/06_tasks_smoke_test.sql`

## 5) Ключевые риски следующего этапа

- при переходе к GUI важно корректно реализовать fetch `SYS_REFCURSOR`, OUT-параметры и обработку Oracle-ошибок;
- недопустим перенос бизнес-логики из PL/SQL в Python;
- любые расширения API нужно делать с учетом совместимости текущего package contract.
