# University Upgrade Checklist

Целевой сценарий: Windows Server 2012 R2, Oracle 12.2, Python 3.12, Waitress,
existing assigned Oracle schema, без Docker.

Новые SQL/PLSQL изменения статически проверены на совместимость с Oracle 12.2.
Runtime validation на Oracle 12.2 должна быть выполнена на университетском
стенде.

1. Остановите Waitress/web-приложение.
2. Зафиксируйте текущую версию deployment и сделайте доступный администратору
   backup/снимок схемы.
3. Не удаляйте Oracle schema, пользователей, таблицы или данные.
4. Сохраните deployment `.env` вне Git.
5. Обновите application files.
6. В SQL Developer подключитесь как назначенный schema user и запустите с `F5`
   `database/installers/university_existing_schema_update.sql`.
7. Убедитесь, что `app_install_state.install_version = 14`.
8. Убедитесь, что `PKG_GENETICS_GAME` имеет `PACKAGE VALID` и `PACKAGE BODY
   VALID`.
9. Убедитесь, что `USER_ERRORS=0` для package.
10. В PowerShell установите путь к deployment env и выполните:

    ```powershell
    $env:BIOSBORKA_ENV_FILE = "$PWD\deployment\windows\.env"
    .\.venv\Scripts\python.exe database\scripts\check_runtime_readiness.py
    ```

11. Проверьте `schema.ready=true` в выводе readiness.
12. Выполните Oracle/web smoke, согласованный для релиза.
13. Запустите `deployment\windows\start-web.cmd`.
14. Откройте `/health/live`: web-process должен ответить `200`.
15. Откройте `/health`: Oracle connectivity и `schema.ready` должны быть true.
16. Войдите в demo v3-лабораторию и откройте существа, Задания, эксперименты и
    detail гибрида.
17. Только после этих проверок считайте update успешным.

Для пустой назначенной schema используйте
`database/installers/university_existing_schema_install.sql`, а не update
entry point. Не придумывайте DSN, пароль или учётные данные: они задаются
локально в `deployment\windows\.env`.
