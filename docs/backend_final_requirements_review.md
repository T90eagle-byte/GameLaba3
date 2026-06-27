# Финальная сверка backend с требованиями ЛР1/ЛР2

Дата аудита: 2026-06-28  
Ветка: `main`  
Рабочая папка: `C:\GameLR3`  
Начальное состояние: `git status --short` был чистым.  
Состояние веток: `backend-rating-events` влит в `main` коммитом `ab97b47 Merge branch 'backend-rating-events'`.

## Краткий вывод

Backend в текущем состоянии в целом соответствует требованиям ЛР1/ЛР2 и фактической архитектуре проекта. Основная игровая логика находится в Oracle PL/SQL package `pkg_genetics_game`; Python-клиент вызывает package API и остается client/display-layer.

Сильнее всего закрыто:

- модель генетической игры: виды, гены, аллели, генотипы, фенотипы, скрещивание, мутации, мутагены, задания;
- многопользовательская модель: пользователи, сессии, лаборатории, запрет доступа к чужим лабораториям;
- справочники: доменные enum-значения вынесены в `ref_*` tables и связаны FK;
- LR2-compatible API: все методы из спецификации ЛР2 есть в package spec/body;
- explainable economy/rating: `rating_events` добавлен как журнал объяснения изменений `labs.wallet` и `labs.rating`;
- smoke-tests: runner запускает package и tests `01..10`, свежий прогон прошел с `Failed: 0`.

Оставшиеся риски не блокируют backend, но важны перед защитой:

- часть LR2-сигнатур адаптирована под session-token модель и Python/Oracle interoperability, а не всегда буквально повторяет PDF;
- `display_names.py` все еще содержит fallback-словари для display formatting, хотя основные enum-справочники уже в БД;
- несколько старых markdown-документов устарели или содержат mojibake; текущий код и свежие docs вроде `database_map.md` актуальнее;
- web-клиент пока не начат, для него нужен server-side API слой поверх package, без прямого подключения браузера к Oracle.

## Таблица ЛР1

| Требование | Реализация | Файлы/объекты | Статус | Комментарий |
| --- | --- | --- | --- | --- |
| Игра-симулятор генетического скрещивания | Есть существа, генотипы, phenotype cache, скрещивание и задания | `creatures`, `genotypes`, `crossbreed`, `calculate_punnett_probabilities`, tests `03`, `04` | OK | Backend реализует основной игровой цикл. |
| Виртуальные существа | Таблица существ с видом, именем и phenotype fields | `creatures`, `get_creatures_cursor`, seed generation | OK | Стартовая лаборатория создает 30 существ. |
| Минимум 5 видов | Реализовано 6 видов и универсальный scope 0 для генов | `ref_species_types`, `genes.species_type`, `creatures.species_type` | OK | Виды: хрящевые рыбы, костные рыбы, ракообразные, моллюски, черепахи, млекопитающие. |
| Признаки: цвет, размер, крылья, питание | Универсальные гены и phenotype cache | genes `color`, `size`, `has_wings`, `nutrition_type`; `creatures.phenotype_*` | OK | Цвет расширен до 8 вариантов, размер имеет дополнительный `medium_size`. |
| Гены, аллели, генотипы, фенотипы | Нормализованные таблицы и package-расчет phenotype | `genes`, `alleles`, `genotypes`, `get_phenotype` | OK | Composite FK не дает присвоить аллель чужому гену. |
| Полное доминирование | Домен `FULL`, dominance values у аллелей | `ref_dominance_types`, `genes.dominance_type`, `get_phenotype` | OK | Проверяется seed/tests. |
| Неполное доминирование | Домен `INCOMPLETE` и phenotype output intermediate | `get_phenotype`, test `07` | OK | `07` проверяет intermediate phenotype. |
| Кодоминирование | Домен `CODOMINANT` и отображение обоих признаков | `get_phenotype`, test `07` | OK | Требование сверх базового минимума закрыто. |
| Сцепленные гены | `genes.linkage_group` и LR2 helper | `crossbreed`, `get_linked_allele_set`, test `09` | OK | Сцепление есть, но smoke-test не исчерпывает все комбинации наследования. |
| Мутации | Directed mutations через правила | `mutations`, `mutation_rules`, `buy_mutation`, `apply_mutation`, tests `05`, `07` | OK | Rules проверяются на FK и coherent species scope. |
| Мутагены | RADIATION/CHEMICAL создают измененное существо с риском/штрафом | `apply_mutagen`, `ref_mutagen_types`, tests `05`, `07` | OK | `ref_mutagen_types` есть как справочник, но FK на него нет, потому что тип передается параметром API. |
| Задания | Marker-based completion | `tasks`, `lab_tasks`, `task_markers`, `check_task`, `complete_task`, test `06` | OK | Происхождение существа не проверяется; формулировки должны оставаться честными: найти/предъявить. |
| История экспериментов | История CROSS/MUTATION/MUTAGEN | `experiments`, `get_experiment_history`, `show_mutation_history`, test `05` | OK | История событий рейтинга вынесена отдельно в `rating_events`. |
| Многопользовательский режим | Пользователи, сессии, session context, запрет чужого доступа | `users`, `sessions`, `labs`, `assert_lab_access`, test `08` | OK | Одна лаборатория не должна быть открыта в другой active session. |
| Лаборатории | Лаборатория содержит существ, задания, мутации, агрегаты | `labs`, `start_new_lab`, `load_lab`, `delete_lab` | OK | `labs.session_id` остается NOT NULL; `exit_lab` очищает package context. |
| Сессии | Session token и ACTIVE/CLOSED status | `sessions`, `login_user`, `logout_user` | OK | `sessions.status` оставлен technical CHECK, не `ref_*`. |
| Защита доступа к чужим лабораториям | Package access checks и negative tests | `assert_lab_access`, tests `06`, `07`, `08`, `10` | OK | Для чужой истории рейтинга корректен отказ `ORA-20023`. |
| Стартовая генерация существ | Генерация 30 существ и 3 ACTIVE tasks | `generate_starting_creatures`, `start_new_lab`, tests `01`, `03`, `09` | OK | Покрыто несколькими smoke-tests. |
| Экономика/кошелек | `labs.wallet`, покупки, награды, штрафы | `buy_mutation`, `complete_task`, `apply_mutagen`, tests `05`, `06`, `10` | OK | `rating_events` объясняет изменения, но не заменяет aggregate field. |
| Рейтинг | `labs.rating`, награды и штрафы | `complete_task`, `apply_mutation`, `apply_mutagen`, `rating_events` | OK | Rare trait bonus зарезервирован, но не начисляется автоматически. |
| Интерфейсные требования с точки зрения backend API | Package cursors возвращают данные и labels | `get_*_cursor`, `show_*`, `pkg_api.py` | OK | GUI/web должны вызывать package, не таблицы напрямую. |

## Таблица ЛР2 package API

| Метод | Spec | Body | Тест | Статус | Комментарий |
| --- | --- | --- | --- | --- | --- |
| `register_user` | Да | Да | `01`, `09` | OK | Сигнатура совпадает с PDF: username, login, password, user_id out. |
| `login_user` | Да | Да | `01`, `09` | OK | Возвращает session token. |
| `logout_user` | Да | Да | `01`, `08` | OK | Закрывает session и очищает context. |
| `update_user_profile` | Да | Да | Косвенно | OK | Public API есть, отдельного exhaustive test нет. |
| `hash_password` | Да | Да | `09` | OK | Использует `STANDARD_HASH(..., 'SHA256')`, не `DBMS_CRYPTO`. |
| `load_lab` | Да | Да | `01`, `08` | OK, адаптировано | Принимает `p_session_token`; это session-token модель проекта. |
| `start_new_lab` | Да | Да | `01`, `03`, `09` | OK, адаптировано | В проекте принимает `p_session_token`, в PDF указан более короткий вариант. |
| `list_user_labs` | Да | Да | `01` | OK | Возвращает `SYS_REFCURSOR`. |
| `exit_lab` | Да | Да | `09` | OK | Очищает текущий lab context, не зануляет `labs.session_id`. |
| `switch_lab` | Да | Да | `01`, `08` | OK | Session-token aware. |
| `show_lab_stats` | Да | Да | `09` | OK | Demo wrapper через `dbms_output`. |
| `get_lab_stats` | Да | Да | `01`, `03`, `04`, `06` | OK | Возвращает aggregate values через OUT parameters. |
| `show_creatures` | Да | Да | `09` | OK | Demo wrapper над cursor. |
| `get_creatures_cursor` | Да | Да | `03`, `07`, `08` | OK | Возвращает species label и phenotype fields. |
| `get_genotype_cursor` | Да | Да | `03`, `08` | OK | Возвращает gene/allele/dominance labels. |
| `get_phenotype` | Да | Да | `03`, `07` | OK | Обновляет/возвращает summary. |
| `get_dominant_allele` | Да | Да | `09` | OK | LR2 helper. |
| `get_inherited_allele` | Да | Да | `09` | OK | Возвращает существующий allele_id. |
| `get_linked_allele_set` | Да | Да | `09` | OK | Использует linkage_group. |
| `calculate_punnett_probabilities` | Да | Да | `04` | OK | Возвращает probabilities cursor. |
| `crossbreed` | Да | Да | `04`, `09` | OK | Создает offspring и experiment row. |
| `rename_creature` | Да | Да | `04` | OK | Покрыто smoke-test. |
| `apply_mutation` | Да | Да | `05`, `07` | OK | Может записывать `SYSTEM_ADJUSTMENT`, если mutation rating effect реально меняет рейтинг. |
| `buy_mutation` | Да | Да | `05`, `10` | OK, адаптировано | Возвращает `number` 1/0 вместо PL/SQL boolean для Python compatibility. |
| `make_experiment` | Да | Да | `05` | OK | Покрывает CROSS/MUTATION branches. |
| `show_tasks` | Да | Да | `09` | OK | Demo wrapper над tasks cursor. |
| `check_task` | Да | Да | `06`, `07` | OK | Marker-based check. |
| `complete_task` | Да | Да | `06`, `10` | OK, расширено | Дополнительно возвращает completion flag, wallet/rating after. |
| `apply_mutagen` | Да | Да | `05`, `07`, `10` | OK, адаптировано | Принимает `varchar2` RADIATION/CHEMICAL вместо integer-кода из PDF. |
| `show_mutation_history` | Да | Да | `09` | OK | Demo wrapper над experiment history. |
| `show_mutation_shop` | Да | Да | `05`, `09` | OK | No-arg `SYS_REFCURSOR`. |
| `generate_starting_creatures` | Да | Да | `01`, `03`, `09` | OK | Создает стартовый набор через `start_new_lab`. |
| `create_creature_of_type` | Да | Да | Косвенно | OK | Используется генерацией стартовых существ. |
| `delete_lab` | Да | Да | `01`, `08` | OK, адаптировано | В проекте принимает session token для защиты доступа. |

## Таблица справочников

| Справочник | DDL | Seed | FK usage | Тест | Статус |
| --- | --- | --- | --- | --- | --- |
| `ref_species_types` | Да | Да | `genes.species_type`, `creatures.species_type` | `02`, `07` | OK |
| `ref_gene_types` | Да | Да | `genes.gene_type` | `02`, `07` | OK |
| `ref_dominance_types` | Да | Да | `genes.dominance_type` | `02`, `07` | OK |
| `ref_task_statuses` | Да | Да | `lab_tasks.task_status` | `02`, `07` | OK |
| `ref_experiment_types` | Да | Да | `experiments.experiment_type` | `02`, `07` | OK |
| `ref_mutagen_types` | Да | Да | Нет FK | `02` | Частично |
| `ref_mutation_types` | Да | Да | `mutations.mutation_type` | `02`, `07` | OK |
| `ref_task_difficulties` | Да | Да | `tasks.difficulty_code` | `02`, `07` | OK |
| `ref_rating_event_types` | Да | Да | `rating_events.event_type` | `02`, `07`, `10` | OK |

Оставшиеся CHECK constraints выглядят допустимыми техническими ограничениями:

- `sessions.status in ('ACTIVE', 'CLOSED')`: технический статус сессии;
- `mutation_rules.target_slot in ('1', '2', 'ANY')`: технический слот правила;
- `creatures.phenotype_has_wings in ('Y', 'N')`: cache/display value.

## Таблица rating_events

| Элемент | Реализация | Тест | Статус |
| --- | --- | --- | --- |
| `rating_events_seq` | Sequence в DDL | Fresh deploy/runner | OK |
| `ref_rating_event_types` | Reference table с 6 типами | `02`, `10` | OK |
| `rating_events` | FK на lab, creature, task, experiment, event type | `07`, `10` | OK |
| `record_rating_event` | Internal helper только записывает event, не меняет aggregates | `10` косвенно | OK |
| `get_rating_events_cursor` | Public cursor с access check и labels | `10` | OK |
| `show_rating_history` | Demo procedure через `dbms_output` | Public API | OK |
| `complete_task` events | Пишет `TASK_REWARD` после успешной награды | `10` | OK |
| `buy_mutation` events | Пишет `MUTATION_PURCHASE` после списания кошелька | `10` | OK |
| `apply_mutagen` events | Пишет `MUTAGEN_PENALTY` после штрафа | `10` | OK |
| `apply_mutation` events | Пишет `SYSTEM_ADJUSTMENT` при фактическом rating delta | `07` косвенно | OK |
| `delete_lab` cleanup | Удаляет связанные `rating_events` перед удалением lab | `01`, `08`, `10` косвенно | OK |
| No double accounting | Events пишутся после aggregate update и проверяются суммой delta | `10` | OK |
| `RARE_TRAIT_BONUS` | Зарезервирован, не начисляется автоматически | Docs/tests ref count | OK |
| Runner includes test 10 | `SMOKE_TEST_FILES` содержит `10_rating_events_smoke_test.sql` | `--dry-run` | OK |

## Python/client-layer audit

`python_client/app/db/pkg_api.py` вызывает package через `cursor.callproc` и `cursor.callfunc`. Прямого gameplay SQL в `pkg_api.py` не найдено. Health-check уровня подключения допустим отдельно от gameplay API.

Python не считает:

- генетику;
- наследование;
- экономику;
- рейтинг;
- выполнение заданий.

`display_names.py` остается display/fallback helper. Риск: в файле все еще есть task/name/difficulty fallback mappings, включая старую fallback-логику difficulty по task name. Это не является source of truth для backend, потому что package cursors возвращают `*_display_name` и `difficulty_code`, но перед web stage стоит либо сократить fallback-словари, либо явно оставить их как compatibility fallback.

Для будущего web-клиента важно сохранить то же правило: server-side API вызывает `pkg_genetics_game`; frontend получает готовые данные/labels и не рассчитывает gameplay deltas.

## Docs consistency audit

Актуально:

- `database/README_RUN.md` уже описывает `STANDARD_HASH`, runner, DBeaver caveats и test `10`;
- `docs/database_map.md` актуально описывает `ref_*`, `rating_events`, `difficulty_code`, package cursors;
- `docs/gameplay_rules.md` корректно описывает marker-based tasks и `rating_events` как explanation log.

Устарело или требует cleanup:

- `docs/current_tasks.md` все еще говорит, что `rating_events` in progress on branch `backend-rating-events`, хотя ветка влита в `main` и tests `01..10` свежо прошли;
- `docs/project_roadmap.md` тоже описывает `rating_events` как current stage, а не completed stage;
- `docs/ai_context.md` и старый `docs/backend_compliance_audit.md` содержат mojibake и местами старые сведения про `01..09` до rating-events track;
- старый `backend_compliance_audit.md` полезен как historical audit, но не должен быть последним документом перед сдачей.

Что не найдено как проблема в коде:

- `DBMS_CRYPTO` и `UTL_I18N` не требуются package body;
- `STANDARD_HASH` используется для password hash;
- runner включает `01..10`;
- DDL содержит ref tables и FK для доменных справочников.

## Test coverage

| Test | Покрывает | Статус покрытия |
| --- | --- | --- |
| `01_auth_labs_smoke_test.sql` | registration/login/logout, lab create/list/load/switch/delete, stats | OK smoke |
| `02_seed_data_smoke_test.sql` | seed coverage, refs, alleles, mutations, tasks, rating event refs | OK smoke/data coverage |
| `03_creature_generation_smoke_test.sql` | starting creatures, species distribution, genotype/phenotype cursors | OK smoke |
| `04_crossbreed_smoke_test.sql` | Punnett probabilities, offspring creation, experiment history, rename | OK smoke |
| `05_mutations_experiments_smoke_test.sql` | mutation shop, buy/apply mutation, mutagen, experiment history | OK smoke |
| `06_tasks_smoke_test.sql` | task cursor, check/complete, refill, negative cases | OK smoke |
| `07_strict_compliance_smoke_test.sql` | refs/FK consistency, content invariants, access blocks, mutagen economics | OK broad smoke |
| `08_multiuser_sessions_smoke_test.sql` | multiuser/session isolation and one-active-lab behavior | OK smoke |
| `09_lr2_package_api_compat_smoke_test.sql` | LR2 wrappers/helpers and demo procedures | OK compat smoke |
| `10_rating_events_smoke_test.sql` | rating event refs/table/cursor, event deltas, foreign access | OK feature smoke |

Blind spots:

- tests are smoke-tests, not exhaustive property-based genetics tests;
- random generation can cover broad behavior but not every genotype combination deterministically;
- web API contract tests do not exist yet because web stage has not started;
- strict task provenance types FIND/BREED/MUTATE are intentionally postponed.

Свежий Oracle-прогон во время этого аудита:

- `database/scripts/run_tests.py --dry-run`: includes package spec/body and tests `01..10`;
- `database/scripts/run_tests.py`: completed successfully;
- all tests `01..10`: `Failed: 0`;
- package status: `PACKAGE VALID`, `PACKAGE BODY VALID`;
- `user_errors`: clean.

## Итоговый список действий

### Critical before defense

- Обновить stale context docs: `docs/current_tasks.md`, `docs/project_roadmap.md`, `docs/ai_context.md`.
- Исправить mojibake в старых markdown-документах или явно считать `backend_final_requirements_review.md` новым source-of-truth audit.
- Перед финальной демонстрацией еще раз прогнать runner `01..10` на стенде или локальном Oracle.

### Should fix

- Зафиксировать в README/docs, что некоторые LR2 signatures адаптированы под session-token модель.
- Решить, нужно ли добавлять буквальные overload wrappers для `start_new_lab`, `delete_lab`, `complete_task`, `apply_mutagen`, если преподаватель требует exact PDF signature.
- Сократить fallback-словари в `display_names.py` после стабилизации web/API слоя или явно пометить их как UI compatibility fallback.

### Nice to have

- Добавить отдельный test на `update_user_profile`.
- Добавить больше deterministic tests для linked inheritance и rare phenotype combinations.
- Добавить отдельную проверку `SYSTEM_ADJUSTMENT` event от `apply_mutation`, если это хотят показать как часть rating history.

### Postpone to web stage

- Web-клиент через browser.
- Server-side HTTP API поверх `pkg_genetics_game`.
- JSON contract tests.
- Строгие provenance tasks для BREED/MUTATE.
- Автоматический `RARE_TRAIT_BONUS` после проектирования устойчивого backend-критерия редкости.
