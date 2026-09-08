-- Safe clean installation into an assigned existing Oracle schema.
-- Run with SQL Developer F5 while connected as the assigned schema user.
-- This script preserves the assigned user and all existing game data.

whenever sqlerror exit sql.sqlcode rollback;
set define off serveroutput on size unlimited verify off;

declare
    v_game_table_count number;
begin
    select count(*) into v_game_table_count
      from user_tables
     where table_name in (
        'USERS', 'SESSIONS', 'LABS', 'GENES', 'ALLELES', 'MUTATIONS',
        'MUTATION_RULES', 'TASKS', 'TASK_MARKERS', 'CREATURES', 'GENOTYPES',
        'EXPERIMENTS', 'LAB_MUTATIONS', 'LAB_TASKS', 'RATING_EVENTS',
        'REF_SPECIES_TYPES', 'REF_GENE_TYPES', 'REF_DOMINANCE_TYPES',
        'REF_TASK_STATUSES', 'REF_EXPERIMENT_TYPES', 'REF_MUTAGEN_TYPES',
        'REF_MUTATION_TYPES', 'REF_TASK_DIFFICULTIES', 'REF_RATING_EVENT_TYPES'
     );
    if v_game_table_count > 0 then
        raise_application_error(
            -20981,
            'BioSborka objects already exist. No changes were made. Use university_existing_schema_update.sql only for a complete existing installation.'
        );
    end if;
end;
/

@@../ddl/01_create_tables.sql
@@../migrations/01_release_lab_session_bindings.sql
@@../migrations/02_add_lab_names.sql
@@../seeds/01_seed_core_game_data.sql
@@../migrations/03_align_task_requirement_descriptions.sql
@@../packages/spec/pkg_genetics_game.pks
@@../packages/body/pkg_genetics_game.pkb
@@university_readiness_validation.sql
