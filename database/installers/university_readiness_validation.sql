-- Common non-destructive validation for Docker and university schema flows.
set define off;
set serveroutput on size unlimited;
set verify off;

declare
    v_required_tables          number;
    v_required_columns         number;
    v_valid_objects            number;
    v_package_errors           number;
    v_required_routines        number;
    v_hybrid_signature         number;
    v_lab_mutation_shop_signature number;
    v_missing_rules            number;
    v_missing_markers          number;
    v_bad_legacy_descriptions  number;
    v_archetypes               number;
    v_expected_archetypes      number;
    v_templates                number;
    v_bad_template_counts      number;
    v_morphology_genes         number;
    v_v1_membership            number;
    v_v3_membership            number;
    v_v3_tasks                 number;
    v_expected_v3_tasks        number;
    v_hybrid_species           number;
    v_marine_species_names     number;
    v_hybrid_experiment        number;
    v_hybrid_rating_event      number;
    v_hybrid_economics         number;
begin
    select count(*) into v_required_tables
      from user_tables
     where table_name in (
        'USERS', 'SESSIONS', 'LABS', 'GENES', 'ALLELES', 'MUTATIONS',
        'MUTATION_RULES', 'TASKS', 'TASK_MARKERS', 'CREATURES', 'GENOTYPES',
        'EXPERIMENTS', 'LAB_MUTATIONS', 'LAB_TASKS', 'RATING_EVENTS',
        'REF_SPECIES_TYPES', 'REF_GENE_TYPES', 'REF_DOMINANCE_TYPES',
        'REF_TASK_STATUSES', 'REF_EXPERIMENT_TYPES', 'REF_MUTAGEN_TYPES',
        'REF_MUTATION_TYPES', 'REF_TASK_DIFFICULTIES', 'REF_RATING_EVENT_TYPES',
        'REF_EXPERIMENT_ECONOMICS', 'REF_CREATURE_ARCHETYPES',
        'REF_ARCHETYPE_ALLELES', 'REF_GENETICS_MODEL_GENES'
     );

    select count(*) into v_required_columns
      from user_tab_columns
     where (table_name = 'LABS' and column_name in ('LAB_NAME', 'GENETICS_VERSION'))
        or (table_name = 'TASKS' and column_name = 'GENETICS_VERSION')
        or (table_name = 'EXPERIMENTS' and column_name = 'MUTAGEN_TYPE')
        or (table_name = 'CREATURES' and column_name = 'ARCHETYPE_ID')
        or (table_name = 'GENES' and column_name = 'GAMEPLAY_ENABLED')
        or (table_name = 'ALLELES' and column_name = 'DISPLAY_NAME');

    select count(*) into v_valid_objects
      from user_objects
     where object_name = 'PKG_GENETICS_GAME'
       and object_type in ('PACKAGE', 'PACKAGE BODY')
       and status = 'VALID';

    select count(*) into v_package_errors
      from user_errors
     where name = 'PKG_GENETICS_GAME'
       and type in ('PACKAGE', 'PACKAGE BODY');

    select count(distinct procedure_name) into v_required_routines
      from user_procedures
     where object_name = 'PKG_GENETICS_GAME'
       and procedure_name in (
           'START_NEW_LAB', 'GET_MORPHOLOGY_CURSOR', 'GET_LAB_MORPHOLOGY_CURSOR',
           'MAKE_EXPERIMENT', 'HYBRIDIZE', 'GET_TASKS_CURSOR',
           'SHOW_LAB_MUTATION_SHOP'
       );

    select count(*) into v_hybrid_signature
      from (
          select subprogram_id
            from user_arguments
           where package_name = 'PKG_GENETICS_GAME'
             and object_name = 'HYBRIDIZE'
             and data_level = 0
             and argument_name is not null
           group by subprogram_id
          having count(*) = 6
             and count(distinct case when argument_name in (
                 'P_LAB_ID', 'P_PARENT1_ID', 'P_PARENT2_ID',
                 'P_MUTAGEN_TYPE', 'P_OFFSPRING_NAME', 'P_OFFSPRING_ID'
             ) then argument_name end) = 6
      );

    select count(*) into v_lab_mutation_shop_signature
      from (
          select subprogram_id
            from user_arguments
           where package_name = 'PKG_GENETICS_GAME'
             and object_name = 'SHOW_LAB_MUTATION_SHOP'
             and data_level = 0
             and argument_name is not null
           group by subprogram_id
          having count(*) = 1
             and count(distinct case when argument_name = 'P_LAB_ID' then argument_name end) = 1
      );

    select count(*) into v_missing_rules
      from mutations m
     where not exists (select 1 from mutation_rules mr where mr.mutation_id = m.mutation_id);

    select count(*) into v_missing_markers
      from tasks t
     where not exists (select 1 from task_markers tm where tm.task_id = t.task_id);

    select count(*) into v_bad_legacy_descriptions
      from tasks
     where genetics_version = 1
       and (description is null or instr(lower(description), 'носительств') = 0);

    select count(*) into v_archetypes from ref_creature_archetypes;
    select count(*) into v_expected_archetypes
      from ref_creature_archetypes
     where archetype_code in (
        'shark', 'ray', 'sawfish', 'generic_bony_fish', 'eel', 'pufferfish',
        'crab', 'crayfish', 'shrimp', 'octopus', 'squid', 'snail',
        'sea_turtle', 'sea_snake', 'whale', 'dolphin', 'seal', 'walrus'
     );

    select count(*) into v_templates from ref_archetype_alleles;
    select count(*) into v_bad_template_counts
      from (
          select archetype_id
            from ref_archetype_alleles
           group by archetype_id
          having count(*) <> 18
      );

    select count(*) into v_morphology_genes
      from genes
     where species_type = 0
       and gameplay_enabled = 'N'
       and gene_name in (
          'body_shape', 'body_proportion', 'body_size', 'body_cover', 'body_color',
          'mouth_type', 'snout_type', 'eye_type', 'front_appendage_count',
          'front_appendage_type', 'front_appendage_size', 'rear_appendage_count',
          'rear_appendage_type', 'rear_appendage_size', 'tail_type', 'tail_size',
          'dorsal_type', 'dorsal_size'
       );

    select count(*) into v_v1_membership
      from ref_genetics_model_genes where genetics_version = 1;
    select count(*) into v_v3_membership
      from ref_genetics_model_genes where genetics_version = 3;

    select count(*) into v_v3_tasks
      from tasks where genetics_version = 3;
    select count(*) into v_expected_v3_tasks
      from tasks
     where genetics_version = 3
       and task_name in (
          'task_v3_disc_saw', 'task_v3_eel_yellow', 'task_v3_shrimp_claws',
          'task_v3_cephalopod_shell', 'task_v3_snake_shell',
          'task_v3_cetacean_broad', 'task_v3_brown_cetacean',
          'task_v3_giant_pinniped', 'task_v3_disc_fish_tail',
          'task_v3_cetacean_rear_flippers', 'task_v3_white_broad_cephalopod',
          'task_v3_long_tailed_pointed'
       );

    select count(*) into v_hybrid_species
      from ref_species_types where species_type = 7;
    select count(*) into v_marine_species_names
      from ref_species_types
     where (species_type = 5 and display_name = 'Морские рептилии')
        or (species_type = 6 and display_name = 'Морские млекопитающие');
    select count(*) into v_hybrid_experiment
      from ref_experiment_types where experiment_type = 'HYBRIDIZATION';
    select count(*) into v_hybrid_rating_event
      from ref_rating_event_types where event_type = 'HYBRIDIZATION_PENALTY';
    select count(*) into v_hybrid_economics
      from ref_experiment_economics
     where experiment_type = 'HYBRIDIZATION'
       and genetics_version = 3
       and mutagen_type = 'RADIATION'
       and wallet_cost = 0
       and rating_effect = -50
       and active_flag = 'Y';

    if v_required_tables <> 28
       or v_required_columns <> 7
       or v_valid_objects <> 2
       or v_package_errors <> 0
       or v_required_routines <> 7
       or v_hybrid_signature <> 1
       or v_lab_mutation_shop_signature <> 1
       or v_missing_rules <> 0
       or v_missing_markers <> 0
       or v_bad_legacy_descriptions <> 0
       or v_archetypes <> 18
       or v_expected_archetypes <> 18
       or v_templates <> 324
       or v_bad_template_counts <> 0
       or v_morphology_genes <> 18
       or v_v1_membership <> 12
       or v_v3_membership <> 19
       or v_v3_tasks <> 12
       or v_expected_v3_tasks <> 12
       or v_hybrid_species <> 1
       or v_marine_species_names <> 2
       or v_hybrid_experiment <> 1
       or v_hybrid_rating_event <> 1
       or v_hybrid_economics <> 1 then
        raise_application_error(
            -20983,
            'Current v3 schema readiness failed. Inspect tables/columns, package, archetypes/templates, model membership, tasks, and hybridization references.'
        );
    end if;

    dbms_output.put_line('PACKAGE and PACKAGE BODY: VALID');
    dbms_output.put_line('USER_ERRORS for PKG_GENETICS_GAME: 0');
    dbms_output.put_line('Archetypes/templates: 18/324');
    dbms_output.put_line('Model membership v1/v3: 12/19');
    dbms_output.put_line('V3 tasks: 12');
    dbms_output.put_line('Version-aware mutation catalog API: OK');
    dbms_output.put_line('Controlled hybridization references: OK');
    dbms_output.put_line('Current v3 schema readiness: OK');
end;
/
