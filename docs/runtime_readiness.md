# Диагностика готовности

Перед защитой или развёртыванием выполните:

```powershell
.\.venv\Scripts\python.exe database\scripts\check_runtime_readiness.py
```

Проверка разделяет три состояния:

- liveness web-процесса: `GET /health/live` всегда возвращает `200`, если Flask запущен;
- доступность Oracle: поле `database.connected` в `GET /health`;
- готовность схемы: поле `schema.ready` в `GET /health` и код завершения CLI.

`schema.ready=true` означает, что обязательные таблицы, package `PKG_GENETICS_GAME`, его `VALID` spec/body, отсутствие package errors, миграционные инварианты, reference/seed-данные и web API присутствуют. Набор пользователей ЛР3 не входит в это условие: его отдельно проверяет `database/scripts/check_lr3_demo_data.py`.

Если web жив, но схема не готова, не выполняйте игровые операции. Проверьте переменные Oracle, доступность Docker/Listener, затем запустите `database/scripts/run_tests.py`. Для старой схемы примените нужную миграцию из `database/migrations` при остановленном приложении и повторите проверку. HTTP-ответы не содержат пароли, DSN, пользовательские токены или traceback.
