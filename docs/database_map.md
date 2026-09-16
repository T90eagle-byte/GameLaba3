# Карта базы данных «БиоСборки»

## Статус схемы

Текущая версия установки — **14**. Маркер хранится в
`app_install_state.install_version`. Новая или существующая схема приводится к
этому состоянию через DDL, миграции `01..14`, production seeds `01..05` и
`pkg_genetics_game`. Для существующей базы используется versioned update, а не
переустановка или удаление данных.

Новые SQL/PLSQL изменения статически проверены на совместимость с Oracle 12.2.
Runtime validation на Oracle 12.2 должна быть выполнена на университетском
стенде.

## Пользователи, сессии и лаборатории

| Объект | Назначение |
| --- | --- |
| `users` | Учётные записи: логин, SHA-256 hash пароля, отображаемое имя. |
| `sessions` | Непрозрачные session tokens со статусом `ACTIVE`/`CLOSED`. |
| `labs` | Сохранённые игры: владелец, имя, Монеты (`wallet`), рейтинг, счётчики и `genetics_version`. |
| `rating_events` | Append-only история изменений Монет и рейтинга. |

`labs.session_id` — временная блокировка активной лаборатории, а не её
владелец. Обычный конфликт не закрывает другие сессии. `recover_lab_access`
явно передаёт только выбранную собственную лабораторию текущей сессии.

Исторические лаборатории имеют `genetics_version=1`. Новые лаборатории
создаются как `genetics_version=3`.

## Существа и генетика

| Объект | Назначение |
| --- | --- |
| `creatures` | Существа лаборатории; `species_type` 1..6 для обычных видов, 7 для гибрида. |
| `genes`, `alleles` | Справочник генов и аллелей с типом доминирования и optional linkage group. |
| `genotypes` | Две аллельные позиции для одного `creature_id + gene_id`; составные FK не дают привязать аллель к чужому гену. |
| `ref_genetics_model_genes` | Канонический состав генов каждой модели: v1 и v3. |
| `ref_species_types` | Виды: 1..6, универсальная область генов 0 и гибрид 7. |

### Модель v3

Канонический генотип v3 состоит из 19 генов: `nutrition_type` и 18
универсальных морфологических traits:

`body_shape`, `body_proportion`, `body_size`, `body_cover`, `body_color`,
`mouth_type`, `snout_type`, `eye_type`, `front_appendage_count`,
`front_appendage_type`, `front_appendage_size`, `rear_appendage_count`,
`rear_appendage_type`, `rear_appendage_size`, `tail_type`, `tail_size`,
`dorsal_type`, `dorsal_size`.

`get_phenotype` в Oracle определяет выраженный фенотип. Web и desktop-клиенты
его не рассчитывают самостоятельно.

## Архетипы и морфология

| Объект | Назначение |
| --- | --- |
| `ref_creature_archetypes` | 18 стартовых шаблонов для шести обычных видов. |
| `ref_archetype_alleles` | Две стартовые аллели каждого гена для архетипа. |

У стартовых v3-существ есть `archetype_id`. Потомство и мутагенные клоны могут
не иметь архетипа: их отображение строится по сохранённому v3-генотипу.
Гибрид всегда имеет `species_type=7`, `archetype_id=NULL` и ровно 19
канонических генов.

## Задания

| Объект | Назначение |
| --- | --- |
| `tasks` | Каталог заданий; `genetics_version` разделяет v1/v3. |
| `task_markers` | Аллельные условия legacy v1-заданий. |
| `lab_tasks` | Назначенные и завершённые задания конкретной лаборатории. |

v1 проверяет носительство требуемых marker alleles. v3 использует сохранённый
выраженный фенотип через package API; web показывает понятное условие, но не
вычисляет его.

## Мутации и эксперименты

| Объект | Назначение |
| --- | --- |
| `mutations`, `mutation_rules` | Направленные мутации и разрешённые цели. |
| `lab_mutations` | Купленные единицы мутаций в лаборатории. |
| `experiments` | История `CROSS`, `MUTATION`, `MUTAGEN`, `CROSSBREED_MUTAGEN`, `HYBRIDIZATION`. |
| `ref_mutagen_types` | Допустимые мутагены `RADIATION` и `CHEMICAL`. |
| `ref_experiment_economics` | Настроенные последствия экспериментов для Монет и рейтинга. |

`CROSSBREED_MUTAGEN` — одна логическая история для операции «Скрещивание +
мутаген», без промежуточных history rows. `HYBRIDIZATION` доступна только для
двух разных обычных v3-видов; гибриды не могут стать родителями, но могут
получать мутацию или мутаген.

## Совместимость моделей

v1 остаётся полностью читаемой и воспроизводимой для исторических лабораторий.
v3 использует только `ref_genetics_model_genes` и universal morphology. Старые
legacy genes не удаляются и не переносятся в v3 задним числом.

## Доступ к данным

`pkg_genetics_game` — единственный источник gameplay truth. Python clients
получают данные из package cursors и вызывают package procedures/functions.
В web-клиенте нет прямого gameplay SQL; разрешён только технический health
check `select 1 from dual`.
