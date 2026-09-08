-- Common non-destructive validation for the university schema scripts.
set define off serveroutput on size unlimited verify off;

declare
    v_valid_objects number;
    v_package_errors number;
    v_mutation_rules number;
    v_task_markers number;
    v_missing_rules number;
    v_missing_markers number;
    v_required_tables number;
begin
    select count(*) into v_required_tables
      from user_tables
     where table_name in (
        'USERS', 'SESSIONS', 'LABS', 'GENES', 'ALLELES', 'MUTATIONS',
        'MUTATION_RULES', 'TASKS', 'TASK_MARKERS', 'CREATURES', 'GENOTYPES',
        'EXPERIMENTS', 'LAB_MUTATIONS', 'LAB_TASKS', 'RATING_EVENTS',
        'REF_SPECIES_TYPES', 'REF_GENE_TYPES', 'REF_DOMINANCE_TYPES',
        'REF_TASK_STATUSES', 'REF_EXPERIMENT_TYPES', 'REF_MUTAGEN_TYPES',
        'REF_MUTATION_TYPES', 'REF_TASK_DIFFICULTIES', 'REF_RATING_EVENT_TYPES'
     );
    select count(*) into v_valid_objects
      from user_objects
     where object_name = 'PKG_GENETICS_GAME'
       and object_type in ('PACKAGE', 'PACKAGE BODY')
       and status = 'VALID';

    select count(*) into v_package_errors
      from user_errors
     where name = 'PKG_GENETICS_GAME'
       and type in ('PACKAGE', 'PACKAGE BODY');

    select count(*) into v_mutation_rules from mutation_rules;
    select count(*) into v_task_markers from task_markers;
    select count(*) into v_missing_rules
      from mutations m
     where not exists (select 1 from mutation_rules mr where mr.mutation_id = m.mutation_id);
    select count(*) into v_missing_markers
      from tasks t
     where not exists (select 1 from task_markers tm where tm.task_id = t.task_id);

    if v_required_tables <> 24
       or v_valid_objects <> 2 or v_package_errors <> 0
       or v_mutation_rules < 20 or v_task_markers < 21
       or v_missing_rules <> 0 or v_missing_markers <> 0 then
        raise_application_error(-20983, 'Schema readiness validation failed. Inspect package status, USER_ERRORS, mutation_rules and task_markers.');
    end if;

    dbms_output.put_line('PACKAGE and PACKAGE BODY: VALID');
    dbms_output.put_line('USER_ERRORS for PKG_GENETICS_GAME: 0');
    dbms_output.put_line('Basic schema readiness: OK');
end;
/
