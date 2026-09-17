-- Ordered, non-destructive update of an existing BioSborka schema.
-- Сохраняйте порядок зависимостей: аддитивные миграции, требуемые seed-данными,
-- выполняются до этих seed-данных. Каждый шаг идемпотентен и сохраняет историю игры.

set define off;
set serveroutput on size unlimited;
set verify off;

@@../migrations/01_release_lab_session_bindings.sql
@@../migrations/02_add_lab_names.sql
-- Эта миграция выполняется до core seed, чтобы добавить его display-колонки.
@@../migrations/15_add_catalog_display_names.sql
@@../seeds/01_seed_core_game_data.sql
@@../migrations/03_align_task_requirement_descriptions.sql
@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql
@@../migrations/08_add_allele_display_names.sql
@@../migrations/09_add_lab_genetics_version.sql
@@../migrations/10_add_genetics_model_membership.sql
@@../migrations/11_add_task_genetics_version.sql
@@../migrations/12_add_combined_experiment_support.sql
@@../migrations/13_add_controlled_hybridization.sql
@@../migrations/14_update_species_display_names.sql

-- Reapply the canonical reference seeds after all structures exist. Migrations
-- also invoke their prerequisite seeds, but this final pass makes the target
-- state explicit and repairs missing reference rows on recognized installs.
@@../seeds/02_seed_universal_morphology.sql
@@../seeds/03_seed_archetype_templates.sql
@@../seeds/04_seed_genetics_model_membership.sql
@@../seeds/05_seed_v3_tasks.sql

@@../packages/spec/pkg_genetics_game.pks
@@../packages/body/pkg_genetics_game.pkb
