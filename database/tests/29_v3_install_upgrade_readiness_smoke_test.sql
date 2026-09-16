-- Validates the reproducible v3 installation target without changing data.
set serveroutput on size unlimited;
set verify off;

declare
    v_failed number := 0;
    v_actual number;

    procedure assert_count(
        p_label    in varchar2,
        p_actual   in number,
        p_expected in number
    ) is
    begin
        if p_actual = p_expected then
            dbms_output.put_line('[PASS] ' || p_label || ': ' || p_actual);
        else
            v_failed := v_failed + 1;
            dbms_output.put_line('[FAIL] ' || p_label || ': expected ' || p_expected || ', got ' || p_actual);
        end if;
    end assert_count;
begin
    select count(*) into v_actual
      from app_install_state
     where install_key = 'schema'
       and install_version = 14;
    assert_count('schema install version 14', v_actual, 1);

    select count(*) into v_actual from ref_creature_archetypes;
    assert_count('archetypes', v_actual, 18);

    select count(*) into v_actual from ref_archetype_alleles;
    assert_count('archetype template rows', v_actual, 324);

    select count(*) into v_actual
      from (
          select archetype_id
            from ref_archetype_alleles
           group by archetype_id
          having count(*) <> 18
      );
    assert_count('archetypes with non-18 template rows', v_actual, 0);

    select count(*) into v_actual
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
    assert_count('universal morphology genes', v_actual, 18);

    select count(*) into v_actual
      from ref_genetics_model_genes where genetics_version = 1;
    assert_count('v1 model membership', v_actual, 12);

    select count(*) into v_actual
      from ref_genetics_model_genes where genetics_version = 3;
    assert_count('v3 model membership', v_actual, 19);

    select count(*) into v_actual
      from tasks where genetics_version = 3;
    assert_count('v3 tasks', v_actual, 12);

    select count(*) into v_actual
      from ref_species_types where species_type = 7;
    assert_count('hybrid species', v_actual, 1);

    select count(*) into v_actual
      from ref_species_types
     where (species_type = 5 and display_name = 'Морские рептилии')
        or (species_type = 6 and display_name = 'Морские млекопитающие');
    assert_count('marine species display names', v_actual, 2);

    select count(*) into v_actual
      from ref_experiment_types where experiment_type = 'HYBRIDIZATION';
    assert_count('hybridization experiment type', v_actual, 1);

    select count(*) into v_actual
      from ref_experiment_economics
     where experiment_type = 'HYBRIDIZATION'
       and genetics_version = 3
       and mutagen_type = 'RADIATION'
       and wallet_cost = 0
       and rating_effect = -50
       and active_flag = 'Y';
    assert_count('hybridization economics', v_actual, 1);

    select count(*) into v_actual
      from user_objects
     where object_name = 'PKG_GENETICS_GAME'
       and object_type in ('PACKAGE', 'PACKAGE BODY')
       and status = 'VALID';
    assert_count('valid package objects', v_actual, 2);

    select count(*) into v_actual
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
    assert_count('version-aware mutation shop signature', v_actual, 1);

    select count(*) into v_actual
      from user_errors
     where name = 'PKG_GENETICS_GAME'
       and type in ('PACKAGE', 'PACKAGE BODY');
    assert_count('package compile errors', v_actual, 0);

    select count(*) into v_actual
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
    assert_count('public hybridize signature', v_actual, 1);

    dbms_output.put_line('Failed: ' || v_failed);
    if v_failed <> 0 then
        raise_application_error(-20984, 'V3 install/upgrade readiness smoke test failed.');
    end if;
end;
/
