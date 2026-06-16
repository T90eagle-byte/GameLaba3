# Backend Compliance Audit: GameLR3 / «БиоСборка»

Дата аудита: 2026-06-16  
Рабочая папка: `C:\GameLR3`  
Ветка на момент начала: `main`  
`git status --short` до начала: чисто

## Источники

- `docs/ПСБД_ЛР1.pdf` — требования к игре, модели данных, многопользовательскому режиму и интерфейсу.
- `docs/ПСБД_ЛР2.pdf` — спецификация и описание пакета `PKG_GENETICS_GAME`.
- `docs/ai_context.md`, `docs/current_tasks.md`, `docs/project_roadmap.md`, `docs/gameplay_rules.md`, `docs/database_map.md`.
- `database/ddl/01_create_tables.sql`.
- `database/seeds/01_seed_core_game_data.sql`.
- `database/packages/spec/pkg_genetics_game.pks`.
- `database/packages/body/pkg_genetics_game.pkb`.
- `database/tests/01..09_*.sql`.
- `python_client/app/db/pkg_api.py`, `python_client/app/services/display_names.py`, GUI tabs.

## Краткий вывод

Backend в целом соответствует ЛР1/ЛР2: игровая логика находится в Oracle PL/SQL, центральный API — `pkg_genetics_game`, основные сущности БД реализованы, доменные справочники вынесены в `ref_*`, Python-клиент вызывает package через `callproc/callfunc`, smoke-tests `01..09` покрывают ключевые вертикали.

Главные остаточные замечания перед сдачей/web-клиентом:

1. В `database/README_RUN.md` осталась устаревшая инструкция про grant на `DBMS_CRYPTO`/`UTL_I18N`, хотя package body уже использует `STANDARD_HASH`.
2. `docs/database_map.md` содержит mojibake и устаревшие сведения; его лучше восстановить отдельным docs-fix.
3. Некоторые LR2-сигнатуры функционально закрыты, но адаптированы под текущую session-token модель и Python/Oracle compatibility. Если преподаватель требует буквальное совпадение сигнатур, нужны дополнительные overload/wrapper решения.
4. Для web-клиента нужен server-side API слой над `pkg_genetics_game`; браузер не должен напрямую подключаться к Oracle.
5. `display_names.py` всё ещё содержит fallback-словари для gene/trait/task/mutation display formatting. Основные enum-справочники уже в БД, но fallback-слой стоит подчистить после стабилизации web API.

## Общий аудит требований

| Требование | Реализация | Статус | Что доработать |
|---|---|---:|---|
| ЛР1: игра-симулятор скрещивания виртуальных существ с заданными свойствами | Есть существа, генотипы, фенотипы, скрещивание, мутации, задания и история экспериментов | OK | Нет обязательной доработки |
| ЛР1: 5 базовых видов минимум | Seed и ref table содержат 6 видов: хрящевые рыбы, костные рыбы, ракообразные, моллюски, черепахи, млекопитающие | OK, превышает минимум | В документации можно явно указать, что реализовано 6 видов |
| ЛР1: признаки цвет, размер, крылья, питание | Универсальные гены `color`, `size`, `nutrition_type`, `has_wings`; phenotype cache в `creatures` | OK | Нет |
| ЛР1: генетика и аллели | `genes`, `alleles`, `genotypes`; составные FK гарантируют, что аллели относятся к нужному гену | OK | Нет |
| ЛР1: неполное доминирование | `genes.dominance_type`, `ref_dominance_types`, логика `get_phenotype` | OK | Нет |
| ЛР1: сцепленные гены | `genes.linkage_group`; `crossbreed` обрабатывает группы сцепления; есть `get_linked_allele_set` | OK | Нет |
| ЛР1: мутации и мутагены | `mutations`, `mutation_rules`, `lab_mutations`; `apply_mutation`, `apply_mutagen`; experiment history | OK | Нет |
| ЛР1: задания с несколькими признаками | `tasks`, `lab_tasks`, `task_markers`; `check_task` проверяет требуемые аллели | OK | Если потребуется строгий FIND/BREED/MUTATE по происхождению существа — это отдельный backend/DDL этап |
| ЛР1: многопользовательский режим | `users`, `sessions`, `labs`; `g_current_session_*`, `g_current_lab_id`, `assert_lab_access`; тест `08` | OK | Нет |
| ЛР1: одну лабораторию нельзя открыть в двух active sessions | `load_lab` проверяет holder session и выдаёт `-20072`; тест `08` | OK | Нет |
| ЛР1: отчуждаемость и инструкции запуска | Есть `database/README_RUN.md`, `.env.example`, requirements | Частично | README обновить после `STANDARD_HASH`; `database_map.md` восстановить от mojibake |
| ЛР2: все программные модули объединены в package | Central API `pkg_genetics_game`; GUI работает через `pkg_api.py` wrapper над package | OK | Нет |
| ЛР2: `hash_password` SHA-256 | Public `hash_password`; body использует `STANDARD_HASH(p_password, 'SHA256')` | OK, адаптировано | README всё ещё говорит про `DBMS_CRYPTO`; исправить docs |
| ЛР2: `DBMS_CRYPTO` в описании hash | В текущем коде `DBMS_CRYPTO` отсутствует; последний commit заменил на `STANDARD_HASH` | OK для текущей политики без `DBMS_CRYPTO` | В отчёте преподавателю пояснить замену стандартной SQL-функцией Oracle |
| ЛР2: `show_*` демонстрационные процедуры | `show_lab_stats`, `show_creatures`, `show_tasks`, `show_mutation_history` есть и выводят через `dbms_output` | OK | GUI не должен читать `dbms_output`, это соблюдено |
| ЛР2: package cursors для GUI | `get_creatures_cursor`, `get_genotype_cursor`, `get_tasks_cursor`, `show_mutation_shop`, `get_experiment_history`, `get_reference_cursor` | OK | Нет |
| Справочники должны быть в БД | Добавлены `ref_species_types`, `ref_gene_types`, `ref_dominance_types`, `ref_task_statuses`, `ref_experiment_types`, `ref_mutagen_types`, `ref_mutation_types`, `ref_task_difficulties` | OK | Синхронизировать docs и убрать устаревшие fallback-пояснения |
| CHECK enum заменить/дополнить FK | FK на ref tables есть для species/gene/dominance/task status/experiment/mutation/task difficulty | OK | `sessions.status` оставлен CHECK как технический статус, это допустимо |
| Seed должен заполнять справочники | Seed начинает с idempotent `merge into ref_*`, затем core data | OK | Нет |
| Tests должны проверять справочники | `02` проверяет ref counts; `07` проверяет domain/FK consistency и `get_reference_cursor` | OK | Нет |
| Python не должен содержать игровые SQL-запросы | `pkg_api.py` использует `callproc/callfunc`; прямой SQL найден только `select 1 from dual` в connection health-check | OK | Для web-клиента сохранить тот же принцип через server-side API |
| Python не должен считать бизнес-логику | GUI отображает данные и вызывает package; совместимость мутаций/портреты — display-layer hints | OK | Следить при web-переносе: не переносить генетику/экономику в frontend |
| `display_names.py` не должен быть источником enum-справочников | GUI использует `*_display_name` из package cursors; `display_names.py` хранит fallback/formatting helpers | Частично OK | После web API стабилизации сократить fallback-словари или явно задокументировать их как display fallback |
| Smoke-tests | В проекте есть `01..09`; `09` покрывает LR2-compatible API wrappers | OK по структуре | В этом аудите Oracle не прогонялся; при сдаче прогнать полный `01..09` |

## LR2 Package API: сверка по методам

| Метод из ЛР2 | Текущая реализация | Статус | Что доработать |
|---|---|---:|---|
| `register_user` | Есть: `p_username`, `p_login`, `p_password`, `p_user_id out` | OK | Нет |
| `login_user` | Есть, возвращает session token | OK | Нет |
| `logout_user` | Есть, закрывает ACTIVE session | OK | Нет |
| `update_user_profile` | Есть | OK | Нет |
| `hash_password` | Есть public wrapper над `hash_password_sha256` | OK | README обновить по `STANDARD_HASH` |
| `load_lab` | Есть, session-token aware | OK | Нет |
| `start_new_lab` | Есть, но принимает `p_session_token` + `p_lab_id out` | OK, адаптировано | Если нужно буквальное LR2 API, добавить no-token overload на основе текущего session context |
| `list_user_labs` | Есть | OK | Нет |
| `exit_lab` | Есть, очищает `g_current_lab_id` после `assert_lab_access` | OK, адаптировано | Не зануляет `labs.session_id`, так как поле `NOT NULL`; поведение закреплено тестом `09` |
| `switch_lab` | Есть | OK | Нет |
| `show_lab_stats` | Есть, wrapper над `get_lab_stats` | OK | Нет |
| `get_lab_stats` | Есть, пересчитывает агрегаты | OK | Нет |
| `show_creatures` | Есть, wrapper над `get_creatures_cursor` | OK | Нет |
| `get_creatures_cursor` | Есть, возвращает species display label и phenotype cache | OK | Нет |
| `get_genotype_cursor` | Есть, возвращает gene/allele/dominance display labels | OK | Нет |
| `get_phenotype` | Есть, обновляет phenotype cache | OK | Нет |
| `get_dominant_allele` | Есть | OK | Нет |
| `get_inherited_allele` | Есть | OK | Нет |
| `get_linked_allele_set` | Есть | OK | Нет |
| `calculate_punnett_probabilities` | Есть | OK | Нет |
| `crossbreed` | Есть, учитывает linkage group | OK | Нет |
| `rename_creature` | Есть | OK | Нет |
| `apply_mutation` | Есть | OK | Нет |
| `buy_mutation` | Есть, возвращает `number` 1/0 вместо PL/SQL `boolean` | OK, адаптировано | Для буквальной LR2-спецификации можно документировать замену из-за Python/SQL interoperability |
| `make_experiment` | Есть | OK | Нет |
| `show_tasks` | Есть, wrapper над `get_tasks_cursor` | OK | Нет |
| `check_task` | Есть | OK | Нет |
| `complete_task` | Есть, дополнительно возвращает completion flag, wallet/rating after | OK, расширено | Для буквальной LR2-сигнатуры можно добавить overload без OUT-параметров, если потребуется |
| `apply_mutagen` | Есть, принимает `varchar2` (`RADIATION`/`CHEMICAL`) вместо integer | OK, адаптировано | При строгом требовании добавить wrapper/mapping для integer-кодов |
| `show_mutation_history` | Есть, wrapper над `get_experiment_history` | OK | Нет |
| `show_mutation_shop` | Есть no-arg refcursor | OK | Нет |
| `generate_starting_creatures` | Есть | OK | Нет |
| `create_creature_of_type` | Есть | OK | Нет |
| `delete_lab` | Есть, но принимает `p_session_token`, `p_lab_id` | OK, адаптировано | Если нужно буквальное LR2 API, добавить `delete_lab(p_lab_id)` wrapper для current session context |

## Проверка DDL и seed

| Область | Наблюдение | Статус | Что доработать |
|---|---|---:|---|
| Sequences | Созданы `*_seq` для основных PK | OK | Нет |
| Users/sessions/labs | Есть PK, FK, unique, login format, session status constraints | OK | Нет |
| Domain refs | Все основные `ref_*` tables есть до core tables | OK | Нет |
| Genes/alleles/genotypes | Есть species/gene/dominance refs, linkage group, allele/genotype integrity | OK | Нет |
| Creatures | Есть species FK и phenotype cache fields | OK | Нет |
| Experiments | FK на ref experiment types, parent consistency checks | OK | Нет |
| Mutations | FK на ref mutation types, rules link target allele to gene | OK | Нет |
| Tasks | `difficulty_code` FK на ref difficulties, task markers by allele | OK | Нет |
| Seed refs | `merge into ref_*` в начале seed | OK | Нет |
| Seed content | Универсальные гены, species-specific genes, 8 colors, mutations, tasks, markers | OK | Нет |

## Проверка клиента и подготовки к web

| Требование web-подготовки | Текущая ситуация | Статус | Что доработать |
|---|---|---:|---|
| Единая точка backend API | `pkg_genetics_game` уже центральный API | OK | Web server должен вызывать package, а не таблицы напрямую |
| Отсутствие прямого SQL в GUI-клиенте | `pkg_api.py` вызывает `callproc/callfunc`; SQL есть только в `connection.py` как `select 1 from dual` health-check | OK | Для web API оставить health-check отдельно и не смешивать с gameplay |
| Refcursor-to-dict boundary | Сейчас в `pkg_api.py` есть `_rows_from_refcursor` | OK | Web server может переиспользовать эту идею для JSON mapping |
| Транзакции | Package body не делает `commit/rollback`; Python connection включает `autocommit=True` | OK для GUI | Для web-клиента явно решить: autocommit per request или controlled transaction wrapper |
| Session model | Package хранит package globals (`g_current_*`) и проверяет active session/lab | OK для stateful DB session | Для web важно использовать connection/session management осторожно; не шарить один Oracle session между пользователями |
| Ошибки | Package использует `raise_application_error`; GUI мапит Oracle errors | OK | Web API должен вернуть user-friendly error JSON и не раскрывать лишние DB details |
| Display labels | Backend cursors возвращают display labels из DB | OK | Web API должен отдавать эти labels напрямую frontend-клиенту |

## Документационные несоответствия

| Файл | Проблема | Статус | Что доработать |
|---|---|---:|---|
| `database/README_RUN.md` | Prerequisites всё ещё требуют `DBMS_CRYPTO` и `UTL_I18N`, хотя package использует `STANDARD_HASH` | TODO | Убрать устаревший grant, оставить `DBMS_RANDOM` и отметить `STANDARD_HASH` |
| `docs/database_map.md` | Файл содержит mojibake и устарел относительно ref tables/task difficulty DB | TODO | Восстановить UTF-8 и обновить карту БД |
| `docs/ai_context.md`, `docs/current_tasks.md`, `docs/project_roadmap.md`, `docs/gameplay_rules.md` | Некоторые формулировки устарели после DB refs и LR2 API stage | TODO | Обновить после принятия этого audit как новой контрольной точки |

## Рекомендованные следующие шаги

1. Исправить docs-only хвосты: `database/README_RUN.md`, `docs/database_map.md`, при необходимости `docs/current_tasks.md`/`project_roadmap.md`.
2. Решить, нужна ли буквальная совместимость LR2-сигнатур или достаточно текущей адаптированной session-token модели.
3. Для web-клиента спроектировать thin backend service:
   - endpoints вызывают только `pkg_genetics_game`;
   - refcursors конвертируются в JSON;
   - Oracle session/connection не шарится между пользователями;
   - бизнес-логика не переносится в frontend.
4. Прогнать package compile и полный Oracle smoke suite `01..09` перед началом web-работ.
5. После web API design добавить отдельный контрактный тест на JSON/API layer, не меняя PL/SQL smoke-tests.

## Проверки, выполненные во время аудита

- `git status --short` до начала: чисто.
- Текущая ветка: `main`.
- Последние релевантные коммиты:
  - `e6369f1 Заменить DBMS_CRYPTO на STANDARD_HASH`;
  - `943e635 Дополнить пакет API по требованиям ЛР2`;
  - `11b8f87 Вынести справочные значения в базу данных`.
- PDF ЛР1/ЛР2 прочитаны локально через `fitz`.
- `python -m compileall -f python_client` прошёл после запуска с повышенным доступом к существующим `__pycache__`.
- Marker-check: clean.
- `rg` по `DBMS_CRYPTO|UTL_I18N|STANDARD_HASH|DBMS_RANDOM` показал устаревшие строки только в `database/README_RUN.md`; package body использует `STANDARD_HASH`.
- `rg` по клиенту показал package calls в `pkg_api.py`; direct gameplay SQL в клиенте не найден.
- Oracle tests в рамках этого docs-only аудита не запускались.
