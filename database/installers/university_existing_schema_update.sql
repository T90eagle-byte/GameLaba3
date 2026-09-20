-- Безопасное обновление существующей схемы BioSborka.
-- Запускайте через SQL Developer F5 под назначенным пользователем схемы.
-- Скрипт сохраняет назначенного пользователя и все игровые данные.

whenever sqlerror exit sql.sqlcode rollback;
set define off;
set serveroutput on size unlimited;
set verify off;

declare
    v_required_table_count number;
begin
    select count(*) into v_required_table_count
      from user_tables
     where table_name in (
        'USERS', 'SESSIONS', 'LABS', 'GENES', 'ALLELES', 'MUTATIONS',
        'MUTATION_RULES', 'TASKS', 'TASK_MARKERS', 'CREATURES', 'GENOTYPES',
        'EXPERIMENTS', 'LAB_MUTATIONS', 'LAB_TASKS', 'RATING_EVENTS',
        'REF_SPECIES_TYPES', 'REF_GENE_TYPES', 'REF_DOMINANCE_TYPES',
        'REF_TASK_STATUSES', 'REF_EXPERIMENT_TYPES', 'REF_MUTAGEN_TYPES',
        'REF_MUTATION_TYPES', 'REF_TASK_DIFFICULTIES', 'REF_RATING_EVENT_TYPES'
     );
    if v_required_table_count <> 24 then
        raise_application_error(
            -20982,
            'Expected an existing BioSborka schema. No changes were made; use university_existing_schema_install.sql only for an empty assigned schema.'
        );
    end if;
end;
/

@@apply_current_schema_update.sql
@@university_readiness_validation.sql
@@mark_current_schema_version.sql
