-- Безопасная чистая установка в назначенную существующую схему Oracle.
-- Запускайте через SQL Developer F5 под назначенным пользователем схемы.
-- Скрипт сохраняет назначенного пользователя и все игровые данные.

whenever sqlerror exit sql.sqlcode rollback;
set define off;
set serveroutput on size unlimited;
set verify off;

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
@@apply_current_schema_update.sql
@@university_readiness_validation.sql
@@mark_current_schema_version.sql
