# Database map

## Источники и приоритет

Карта основана на:
- `docs/ПСБД_ЛР1.pdf`
- `docs/ПСБД_ЛР2.pdf`

При конфликте деталей приоритет у ЛР2 и фактического DDL:
- `database/ddl/01_create_tables.sql`

## Физическая схема (актуально)

### Базовые сущности
- `users`
- `sessions`
- `labs`

### Генетика и существа
- `genes`
- `alleles`
- `creatures`
- `genotypes`

### Эксперименты, мутации, задания
- `mutations`
- `mutation_rules`
- `experiments`
- `lab_mutations`
- `tasks`
- `lab_tasks`
- `task_markers`

Все PK используют отдельные sequence (`*_seq`).

## Ключевые бизнес-ограничения, уже зафиксированные в DDL

1. `users.login` — уникальный.
2. `sessions` хранит `session_token`, статус `ACTIVE/CLOSED`, и имеет `unique (session_id, user_id)` для составной связи.
3. `labs` привязана к владельцу:
   - FK `labs.session_id -> sessions.session_id`
   - составной FK `(session_id, user_id) -> sessions(session_id, user_id)`
4. `genes` содержит:
   - `species_type` (`0..6`)
   - `dominance_type` (`FULL/INCOMPLETE/CODOMINANT`)
   - `linkage_group` (nullable, `> 0` если не null)
5. `creatures` содержит кэш-поля фенотипа:
   - `phenotype_color`
   - `phenotype_size`
   - `phenotype_has_wings` (`Y/N`)
   - `phenotype_nutrition_type`
   - `phenotype_summary`
6. Целостность генотипа усилена:
   - `alleles` имеет `unique (allele_id, gene_id)`
   - `genotypes` ссылается составными FK:
     - `(allele1_id, gene_id) -> alleles(allele_id, gene_id)`
     - `(allele2_id, gene_id) -> alleles(allele_id, gene_id)`
7. `mutation_rules` связывает мутацию с конкретным геном и целевым аллелем:
   - FK `mutation_id -> mutations`
   - FK `gene_id -> genes`
   - составной FK `(target_allele_id, gene_id) -> alleles(allele_id, gene_id)`
   - `target_slot in ('1', '2', 'ANY')`
8. `lab_tasks.task_status` ограничен `ACTIVE/COMPLETED`.
9. `experiments` имеет строгую проверку типа:
   - `CROSS` требует `parent2_id is not null`
   - `MUTATION` и `MUTAGEN` требуют `parent2_id is null`

## Seed coverage (файл `01_seed_core_game_data.sql`)

Загружаются:
- 6 типов существ (через `species_type` в генах);
- 12 генов (универсальные + видоспецифичные);
- 24 аллеля (минимум 2 на каждый ген);
- 4 мутации;
- правила `mutation_rules`, согласованные с `genes/alleles`;
- 6 заданий и их `task_markers`.

## Совместимость с pkg_genetics_game

Схема соответствует контракту:
- `database/packages/spec/pkg_genetics_game.pks`
- `database/packages/body/pkg_genetics_game.pkb`

Реализованные блоки в body уже используют эту карту без изменения DDL:
- auth/session/labs;
- генерация стартовых существ и базовый фенотип.

## Примечание для Python GUI

Python не должен читать `dbms_output`.  
Доступ к игровым данным — только через:
- OUT-параметры;
- `sys_refcursor`;
- функции с простыми return-типами.

