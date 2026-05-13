# Gameplay rules

## Цель игры

Игрок управляет лабораторией, получает коллекцию существ, работает с генетикой и выполняет задания клиентов.

Бизнес-решения принимает Oracle PL/SQL (`pkg_genetics_game`), Python GUI только вызывает API и отображает результаты.

## Реально реализованный игровой блок (текущий)

### 1) Пользователь и сессия
- `register_user`
- `login_user` (возвращает `session_token`)
- `logout_user`
- `update_user_profile`

### 2) Лаборатория
- `start_new_lab` (создает лабораторию, стартовые счетчики и экономику)
- `load_lab`
- `switch_lab`
- `list_user_labs`
- `get_lab_stats`
- `delete_lab`

### 3) Стартовые существа
- `generate_starting_creatures` создает 30 существ (6 типов × 5);
- `create_creature_of_type`:
  - берет гены `species_type = 0` и `species_type = p_species_type`;
  - случайно выбирает по 2 аллеля на ген;
  - создает `genotypes`;
  - вызывает `get_phenotype`.

### 4) Фенотип и отображение
- `get_phenotype` вычисляет фенотип по `dominance_type`:
  - `FULL`
  - `INCOMPLETE`
  - `CODOMINANT`
- кэширует результат в `creatures` (`phenotype_*`, `phenotype_summary`);
- `get_creatures_cursor` и `get_genotype_cursor` отдают GUI-готовые курсоры.

## Стартовые данные MVP

Из `database/seeds/01_seed_core_game_data.sql`:
- универсальные гены: `color`, `size`, `nutrition_type`, `has_wings`;
- видоспецифичные гены (плавники, панцирь, клешни, шерсть, форма клюва/носа, скорость);
- мутации и `mutation_rules`;
- задания и `task_markers`.

## Что пока не реализовано в геймплее

- расчет решетки Пеннета;
- скрещивание (`crossbreed`);
- переименование существа (`rename_creature`);
- покупка/применение мутаций и мутагенов;
- история экспериментов;
- логика заданий (`get_tasks_cursor`, `check_task`, `complete_task`).

Эти части пока оставлены stubs в `pkg_genetics_game.pkb`.

## Правила интеграции GUI

- не использовать `dbms_output` как источник данных;
- получать данные через `sys_refcursor`, OUT-параметры и простые return-значения;
- не переносить генетические вычисления, экономику, задания и мутации в Python.

## Следующий игровой этап

После полного прогона SQL-цепочки в Oracle:
1. реализовать блок скрещивания:
   - `calculate_punnett_probabilities`
   - `crossbreed`
   - `rename_creature`
2. затем реализовать блок мутаций и заданий.

