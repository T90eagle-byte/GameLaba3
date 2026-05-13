# Database map

## Источники

Карта составлена по `ПСБД_ЛР1.pdf` и `ПСБД_ЛР2.pdf`. ЛР2 считается более актуальной для структуры таблиц и PL/SQL-контракта, потому что содержит типы данных, ограничения и спецификацию пакета.

## Принятые решения для DDL

- Физические имена будущих таблиц и столбцов: `snake_case`, без quoted identifiers.
- В MVP используются 6 типов существ из ЛР2.
- Игровая авторизация реализуется через таблицу `users`.
- Oracle grants используются для доступа приложения к схеме, а не для создания отдельного Oracle-пользователя на каждого игрока.
- `genes` обязательно содержит `species_type`, `dominance_type`, `linkage_group`.
- `creatures` содержит только часто отображаемые фенотипические поля; полный фенотип возвращает `get_phenotype`.
- GUI-контракт не опирается на `dbms_output`; данные для Python возвращаются через OUT-параметры, `sys_refcursor` и простые функции.

## Типы существ

| Код | Тип |
| --- | --- |
| 1 | Хрящевые рыбы |
| 2 | Костные рыбы |
| 3 | Ракообразные |
| 4 | Моллюски |
| 5 | Черепахи |
| 6 | Млекопитающие |

## Логическая структура

| Сущность из PDF | Предлагаемое snake_case имя | Назначение |
| --- | --- | --- |
| Пользователи | `users` | Игровые аккаунты: имя, логин, хэш пароля. |
| Сессии | `sessions` | Входы пользователей, статус, время начала и завершения. |
| Лаборатория | `labs` | Сохраненное игровое состояние пользователя. |
| Ген | `genes` | Описание наследуемых признаков, типа существа и доминирования. |
| Аллель | `alleles` | Конкретные значения признаков для каждого гена. |
| Существо | `creatures` | Организмы, принадлежащие лаборатории. |
| Генотип | `genotypes` | Пары аллелей существа по каждому гену. |
| Эксперимент | `experiments` | История скрещиваний, мутаций и мутагенов. |
| Мутация | `mutations` | Типы покупаемых мутаций. |
| Мутация в лаборатории | `lab_mutations` | Запас купленных мутаций в лаборатории. |
| Задание | `tasks` | Заказы клиентов и награды. |
| Задание в лаборатории | `lab_tasks` | Статус задания в конкретной лаборатории. |
| Маркер задания | `task_markers` | Аллели, необходимые для выполнения задания. |

Имена выше являются проектной картой для будущей реализации. Они не создают миграции и не меняют PDF-модель.

## Таблицы и ключевые поля

### `users`

- `user_id` - PK.
- `username` - отображаемое имя, NOT NULL.
- `login` - уникальный логин, NOT NULL.
- `password_hash` - хэш пароля, NOT NULL.

Ограничение из ЛР2: логин состоит из строчных латинских букв, цифр и `_`, первый символ - буква.

### `sessions`

- `session_id` - PK.
- `user_id` - FK -> `users`.
- `status` - активна или завершена.
- `started_at` - дата начала.
- `ended_at` - дата конца, NULL для активной сессии.

### `labs`

- `lab_id` - PK.
- `user_id` - FK -> `users`.
- `session_id` - FK -> `sessions`, текущая или последняя сессия.
- `wallet` - монеты.
- `rating` - рейтинг лаборатории.
- `creature_count` - агрегатное количество существ.
- `active_task_count` - агрегатное количество активных заданий.
- `completed_task_count` - агрегатное количество выполненных заданий.
- `experiment_count` - агрегатное количество экспериментов.

Статистика должна пересчитываться в `get_lab_stats`, а не в Python.

### `genes`

- `gene_id` - PK.
- `gene_type` - тип признака.
- `species_type` - 0 для универсального гена, 1-6 для конкретного типа существа.
- `dominance_type` - `FULL`, `INCOMPLETE`, `CODOMINANT`.
- `linkage_group` - группа сцепления; NULL для независимых генов.
- `gene_name` - название.
- `description` - описание.

`linkage_group` включается в DDL как обязательный столбец модели, потому что механика `get_linked_allele_set` и `crossbreed` использует сцепленные группы. Само значение может быть NULL, если ген наследуется независимо.

### `alleles`

- `allele_id` - PK.
- `gene_id` - FK -> `genes`.
- `dominance` - сила доминирования.
- `description` - значение признака в текстовом виде.
- `trait_value` - числовое значение признака.

### `creatures`

- `creature_id` - PK.
- `lab_id` - FK -> `labs`.
- `species_type` - тип существа от 1 до 6.
- `creature_name` - имя существа.
- `phenotype_color` - часто отображаемый фенотипический признак, nullable cache.
- `phenotype_size` - часто отображаемый фенотипический признак, nullable cache.
- `phenotype_has_wings` - часто отображаемый фенотипический признак, nullable cache.
- `phenotype_nutrition_type` - часто отображаемый фенотипический признак, nullable cache.
- `phenotype_summary` - короткое текстовое описание фенотипа для списков и карточек.

Фенотипические поля в `creatures` являются удобным кешем для часто отображаемых признаков. Источник истины - `genotypes` + `genes` + `alleles`; полный фенотип возвращается функцией `get_phenotype(p_creature_id)`.

### `genotypes`

- `genotype_id` - PK по ЛР2.
- `creature_id` - FK -> `creatures`.
- `gene_id` - FK -> `genes`.
- `allele1_id` - FK -> `alleles`.
- `allele2_id` - FK -> `alleles`.

На уровне правил желательно обеспечить уникальность пары `creature_id + gene_id`, чтобы у существа был один генотип по каждому гену.

### `experiments`

- `experiment_id` - PK.
- `lab_id` - FK -> `labs`.
- `parent1_id` - FK -> `creatures`.
- `parent2_id` - FK -> `creatures`, может быть NULL для одиночной мутации.
- `mutation_id` - FK -> `mutations`, может быть NULL.
- `offspring_id` - FK -> `creatures`.
- `experiment_type` - `CROSS`, `MUTATION`, `MUTAGEN` или другой утвержденный тип.

### `mutations`

- `mutation_id` - PK.
- `mutation_name` - название.
- `mutation_type` - числовой тип.
- `description` - описание эффекта.
- `cost` - стоимость покупки.
- `rating_effect` - влияние на рейтинг.

### `lab_mutations`

- `lab_id` - FK -> `labs`.
- `mutation_id` - FK -> `mutations`.
- `quantity` - доступное количество.

Логический ключ: `lab_id + mutation_id`.

### `tasks`

- `task_id` - PK.
- `task_name` - название.
- `description` - описание заказа.
- `rating_reward` - изменение рейтинга.
- `money_reward` - награда монетами.

В ЛР1 есть поле целевого значения задания, в ЛР2 требования вынесены в `task_markers`.

### `lab_tasks`

- `lab_id` - FK -> `labs`.
- `task_id` - FK -> `tasks`.
- `task_status` - `ACTIVE` или `COMPLETED`.

Логический ключ: `lab_id + task_id`.

### `task_markers`

- `task_id` - FK -> `tasks`.
- `allele_id` - FK -> `alleles`.

Задание считается выполненным, если все требуемые аллели найдены в генотипе проверяемого существа.

## PL/SQL package map

Основной пакет по ЛР2:

```text
pkg_genetics_game
```

### Пользователи и сессии

- `register_user(p_username, p_login, p_password, p_user_id OUT)`
- `login_user(p_login, p_password) RETURN varchar2`
- `logout_user(p_session_token)`
- `update_user_profile(p_user_id, p_username, p_password)`
- `hash_password(p_password) RETURN varchar2`

### Лаборатории

- `start_new_lab(p_lab_id OUT)`
- `load_lab(p_session_token, p_lab_id)`
- `list_user_labs(p_user_id) RETURN sys_refcursor`
- `exit_lab(p_lab_id)`
- `switch_lab(p_session_token, p_new_lab_id)`
- `delete_lab(p_lab_id)`

### Статистика и данные для GUI

- `show_lab_stats(p_lab_id)`
- `get_lab_stats(...)`
- `show_creatures(p_lab_id)`
- `get_creatures_cursor(p_lab_id) RETURN sys_refcursor`
- `get_genotype_cursor(p_creature_id) RETURN sys_refcursor`
- `get_phenotype(p_creature_id) RETURN varchar2`

Для GUI приоритетнее функции с курсорами и OUT-параметрами. Процедуры `show_*`, которые пишут в `dbms_output`, полезны для отладки и текстового интерфейса.

Для Python-клиента `dbms_output` не используется. Если экрану GUI нужен список или история, для него должен существовать `sys_refcursor`-контракт или процедура с OUT-параметрами.

### Генетика и эксперименты

- `get_dominant_allele(p_creature_id, p_gene_id) RETURN varchar2`
- `get_inherited_allele(p_parent_id, p_gene_id) RETURN integer`
- `get_linked_allele_set(p_creature_id, p_linkage_group) RETURN varchar2`
- `calculate_punnett_probabilities(...) RETURN sys_refcursor`
- `crossbreed(...)`
- `rename_creature(...)`
- `apply_mutation(...)`
- `buy_mutation(...) RETURN boolean`
- `make_experiment(...)`
- `apply_mutagen(...)`
- `show_mutation_history(...)`
- `show_mutation_shop RETURN sys_refcursor`
- `generate_starting_creatures(...)`
- `create_creature_of_type(...)`

### Задания

- `show_tasks(p_lab_id)`
- `check_task(p_lab_id, p_task_id, p_creature_id) RETURN integer`
- `complete_task(p_lab_id, p_task_id, p_creature_id)`

## Оставшиеся DDL-детали

- Уточнить, нужен ли отдельный `session_token`, или токеном считается `session_id`.
- Уточнить длину и формат `password_hash`: в тексте одновременно встречается `CHAR(512)` и SHA-256 как 64 hex-символа.
- Утвердить точный набор кешируемых фенотипических полей в `creatures`; базовый набор для DDL: `phenotype_color`, `phenotype_size`, `phenotype_has_wings`, `phenotype_nutrition_type`, `phenotype_summary`.
- Определить каскадное удаление лаборатории: через FK `ON DELETE CASCADE` или строго через `delete_lab`.
