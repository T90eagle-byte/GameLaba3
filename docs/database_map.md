# Database Map

## 1. Sources and Priority

This map reflects the current backend state:

- LR1 requirements PDF in `docs/`;
- LR2 requirements PDF in `docs/`;
- `database/ddl/01_create_tables.sql`;
- `database/packages/spec/pkg_genetics_game.pks`;
- `database/packages/body/pkg_genetics_game.pkb`;
- smoke-tests `database/tests/01..11_*.sql`.

If documents and implementation differ, the current DDL and public `pkg_genetics_game` API are the operational source of truth.

## 2. Backend Architecture

The backend is implemented in Oracle:

- physical schema and constraints live in `database/ddl/01_create_tables.sql`;
- seed data lives in `database/seeds/01_seed_core_game_data.sql`;
- gameplay operations are implemented in `pkg_genetics_game`;
- the Python GUI calls package functions/procedures and reads `SYS_REFCURSOR`;
- domain enum labels are stored in `ref_*` tables, not as Python source-of-truth dictionaries.

Password hashing uses Oracle `STANDARD_HASH(..., 'SHA256')`. No extra crypto or input-encoding packages are required for password hashing.

## 3. Sequences

Primary keys are backed by separate sequences:

- `users_seq`;
- `sessions_seq`;
- `labs_seq`;
- `genes_seq`;
- `alleles_seq`;
- `mutations_seq`;
- `mutation_rules_seq`;
- `tasks_seq`;
- `creatures_seq`;
- `genotypes_seq`;
- `experiments_seq`;
- `lab_mutations_seq`;
- `lab_tasks_seq`;
- `task_markers_seq`;
- `rating_events_seq`.

## 4. Domain Reference Tables

Domain enum values are stored in database reference tables. The GUI uses labels returned by package cursors and keeps only formatting/fallback helpers.

| Table | Key | Purpose |
| --- | --- | --- |
| `ref_species_types` | `species_type` | Species and universal gene scope, codes 0..6. |
| `ref_gene_types` | `gene_type` | Gene categories: trait, morphology, performance, physiology. |
| `ref_dominance_types` | `dominance_type` | Dominance models: FULL, INCOMPLETE, CODOMINANT. |
| `ref_task_statuses` | `task_status` | Task statuses: ACTIVE, COMPLETED. |
| `ref_experiment_types` | `experiment_type` | Experiment kinds: CROSS, MUTATION, MUTAGEN. |
| `ref_mutagen_types` | `mutagen_type` | Mutagen kinds: RADIATION, CHEMICAL. |
| `ref_mutation_types` | `mutation_type` | Mutation categories, codes 1..8. |
| `ref_task_difficulties` | `difficulty_code` | Task difficulty values: EASY, MEDIUM, HARD. |
| `ref_rating_event_types` | `event_type` | Rating/economy event kinds: TASK_REWARD, MUTAGEN_PENALTY, MUTATION_PURCHASE, EXPERIMENT_COST, RARE_TRAIT_BONUS, SYSTEM_ADJUSTMENT. |

Each reference table includes `display_name`.

## 5. Auth, Sessions, and Labs

### `users`

- `user_id` - primary key.
- `login` - unique login with format `^[a-z][a-z0-9_]{0,19}$`.
- `password_hash` - SHA-256 hex string.
- `username`, `created_at`, `updated_at`.

### `sessions`

- `session_id` - primary key.
- `user_id -> users(user_id)`.
- `session_token` - unique opaque client token.
- `status` - `ACTIVE` or `CLOSED`.
- `unique (session_id, user_id)` supports a composite lab relationship.

`status` remains a technical CHECK value and is not currently represented by a `ref_*` table.

### `labs`

- `lab_id` - primary key.
- `user_id -> users(user_id)`.
- `lab_name` - trimmed player-facing name, up to 60 characters; required after migration `02_add_lab_names.sql`.
- nullable `session_id -> sessions(session_id)`; it identifies only the active session currently holding the lab.
- `(session_id, user_id) -> sessions(session_id, user_id)`.
- `wallet`, `rating`.
- Aggregate counters: `creature_count`, `active_task_count`, `completed_task_count`, `experiment_count`.

`labs.wallet` and `labs.rating` remain the current aggregate state. Detailed explanations for changes are stored in `rating_events`.

`labs.session_id` is an active lock, not permanent ownership. `exit_lab` and `logout_user` release it, while `reset_other_user_sessions` closes only the caller's other active sessions and releases their labs. Ownership remains defined by `labs.user_id`.

`start_new_lab` keeps its original signature and also has a named overload. `rename_lab` validates the active session and ownership; `list_user_labs` is the source of current names for both the laboratory list and dashboard.

## 6. Genetics

### `genes`

- `gene_id` - primary key.
- `gene_type -> ref_gene_types(gene_type)`.
- `species_type -> ref_species_types(species_type)`.
- `dominance_type -> ref_dominance_types(dominance_type)`.
- `linkage_group` - nullable linked inheritance group.
- `gene_name`, `description`.

`species_type = 0` means a universal gene. Species-specific genes use values 1..6.

### `alleles`

- `allele_id` - primary key.
- `gene_id -> genes(gene_id)`.
- `unique (allele_id, gene_id)` supports composite foreign keys.
- `dominance`, `description`, `trait_value`.

### `creatures`

- `creature_id` - primary key.
- `lab_id -> labs(lab_id)`.
- `species_type -> ref_species_types(species_type)`.
- `creature_name`.
- Cached phenotype fields for GUI display: `phenotype_color`, `phenotype_size`, `phenotype_has_wings`, `phenotype_nutrition_type`, `phenotype_summary`.

Creatures allow species values 1..6 only. Universal species code 0 is for genes, not creature rows.

### `genotypes`

- `genotype_id` - primary key.
- `creature_id -> creatures(creature_id)`.
- `gene_id -> genes(gene_id)`.
- `(allele1_id, gene_id) -> alleles(allele_id, gene_id)`.
- `(allele2_id, gene_id) -> alleles(allele_id, gene_id)`.
- `unique (creature_id, gene_id)`.

Composite allele foreign keys prevent an allele from being attached to the wrong gene.

## 7. Mutations and Experiments

### `mutations`

- `mutation_id` - primary key.
- `mutation_name` - unique technical name.
- `mutation_type -> ref_mutation_types(mutation_type)`.
- `description`, `cost`, `rating_effect`.

### `mutation_rules`

- `mutation_rule_id` - primary key.
- `mutation_id -> mutations(mutation_id)`.
- `gene_id -> genes(gene_id)`.
- `(target_allele_id, gene_id) -> alleles(allele_id, gene_id)`.
- `target_slot` - `1`, `2`, or `ANY`.

### `experiments`

- `experiment_id` - primary key.
- `lab_id -> labs(lab_id)`.
- `parent1_id`, `parent2_id`, `offspring_id -> creatures(creature_id)`.
- `mutation_id -> mutations(mutation_id)`, nullable.
- `experiment_type -> ref_experiment_types(experiment_type)`.
- `created_at`.

Constraints require `parent2_id` for `CROSS` and forbid it for `MUTATION`/`MUTAGEN`.

### `lab_mutations`

- `lab_mutation_id` - primary key.
- `lab_id -> labs(lab_id)`.
- `mutation_id -> mutations(mutation_id)`.
- `quantity`.
- `unique (lab_id, mutation_id)`.

## 8. Tasks

### `tasks`

- `task_id` - primary key.
- `task_name` - unique technical name.
- `description`.
- `rating_reward`, `money_reward`.
- `difficulty_code -> ref_task_difficulties(difficulty_code)`.
- `created_at`.

`difficulty_code` makes task difficulty a database domain value instead of a Python dictionary.

### `lab_tasks`

- `lab_task_id` - primary key.
- `lab_id -> labs(lab_id)`.
- `task_id -> tasks(task_id)`.
- `task_status -> ref_task_statuses(task_status)`.
- `assigned_at`, `completed_at`.
- `unique (lab_id, task_id)`.

### `task_markers`

- `task_marker_id` - primary key.
- `task_id -> tasks(task_id)`.
- `allele_id -> alleles(allele_id)`.
- `unique (task_id, allele_id)`.

Task completion checks are marker-based: `check_task` checks required alleles. Creature origin is not checked.

## 9. Rating and Economy Events

### `rating_events`

- `rating_event_id` - primary key.
- `lab_id -> labs(lab_id)`.
- Optional links: `creature_id -> creatures`, `task_id -> tasks`, `experiment_id -> experiments`.
- `event_type -> ref_rating_event_types(event_type)`.
- `rating_delta`, `wallet_delta`, `description`, `created_at`.

`rating_events` is an append-only explanation log. It does not replace `labs.wallet` or `labs.rating`; those fields remain aggregate state. Package code records events after the aggregate update so future clients can explain why wallet/rating changed. `RARE_TRAIT_BONUS` is reserved but is not automatically awarded yet.

## 10. Package API and Display Labels

The central backend API is `pkg_genetics_game`. The Python client does not query gameplay tables directly.

Package cursors return technical fields plus display labels from database reference tables where the GUI needs them:

- `get_reference_cursor(p_ref_name)` - whitelist-based access to `ref_*` tables.
- `get_creatures_cursor` - creature rows plus `species_display_name`.
- `get_genotype_cursor` - genes, alleles, gene type labels, dominance labels, and allele display fields.
- `get_tasks_cursor` - tasks, statuses, `difficulty_code`, and `difficulty_display_name`.
- `show_mutation_shop` - mutation shop rows plus `mutation_type_display_name`.
- `get_experiment_history` - experiment history rows plus `experiment_type_display_name`.
- `get_rating_events_cursor` - rating/economy event history with event type labels.

LR2 demonstration procedures such as `show_creatures`, `show_tasks`, `show_mutation_history`, and `show_lab_stats` use `dbms_output` only for manual diagnostics and smoke-tests. The GUI does not depend on `dbms_output`.

## 11. Seed Coverage

`database/seeds/01_seed_core_game_data.sql` fills:

- all `ref_*` domain tables;
- species values 1..6 plus universal gene scope 0 in `ref_species_types`;
- genes, alleles, and inheritance metadata;
- mutations and `mutation_rules`;
- tasks with `difficulty_code`;
- `task_markers`.

Smoke-test `02_seed_data_smoke_test.sql` checks reference data, non-null `tasks.difficulty_code`, and seed relationship consistency.

## 12. Python GUI Integration

Python GUI remains a display/client layer:

- calls `pkg_genetics_game` through `callproc`/`callfunc`;
- reads `SYS_REFCURSOR`;
- contains no direct SQL queries to gameplay tables;
- does not calculate genetics, mutations, tasks, economy, or rating;
- uses display labels from package cursors, while `display_names.py` keeps only formatting and fallback helpers.

`DBMS_OUTPUT` is for smoke-tests and manual backend diagnostics, not for the user interface.
