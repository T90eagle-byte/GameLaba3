set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests number := 0;
    v_passed_tests number := 0;
    v_value        number;

    procedure pass_test(p_test_name in varchar2) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_test_name);
    end pass_test;

    procedure fail_test(
        p_test_name in varchar2,
        p_detail    in varchar2 default null
    ) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_test_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(
        p_condition in boolean,
        p_test_name in varchar2,
        p_detail    in varchar2 default null
    ) is
    begin
        if p_condition then
            pass_test(p_test_name);
        else
            fail_test(p_test_name, p_detail);
        end if;
    end assert_true;
begin
    dbms_output.put_line('--- SEED DATA SMOKE TEST ---');

    -- 1) Gene count >= 12
    select count(*) into v_value from genes;
    assert_true(v_value >= 12, 'Gene count >= 12', 'actual=' || v_value);

    -- 2) Allele count >= 30
    select count(*) into v_value from alleles;
    assert_true(v_value >= 38, 'Allele count >= 38 after content expansion', 'actual=' || v_value);

    -- 2a) Color gene has at least 8 configured alleles
    select count(*)
      into v_value
      from alleles a
      join genes g
        on g.gene_id = a.gene_id
     where g.gene_name = 'color'
       and g.species_type = 0;
    assert_true(v_value >= 8, 'Color gene has >= 8 alleles', 'actual=' || v_value);

    -- 2b) Required color allele codes exist
    select count(distinct lower(a.description))
      into v_value
      from alleles a
      join genes g
        on g.gene_id = a.gene_id
     where g.gene_name = 'color'
       and g.species_type = 0
       and lower(a.description) in (
            'green_color', 'blue_color', 'red_color', 'yellow_color',
            'purple_color', 'orange_color', 'white_color', 'black_color'
       );
    assert_true(v_value = 8, 'Required 8 color allele codes exist', 'covered=' || v_value);
    -- 2c) First safe content expansion allele codes exist
    select count(distinct lower(a.description))
      into v_value
      from alleles a
      join genes g
        on g.gene_id = a.gene_id
     where (g.gene_name = 'size' and g.species_type = 0 and lower(a.description) = 'medium_size')
        or (g.gene_name = 'fin_shape' and g.species_type = 1 and lower(a.description) = 'crescent_fin')
        or (g.gene_name = 'fin_shape' and g.species_type = 2 and lower(a.description) = 'ribbon_fin')
        or (g.gene_name = 'shell_armor' and g.species_type = 3 and lower(a.description) = 'ridged_armor')
        or (g.gene_name = 'claw_form' and g.species_type = 3 and lower(a.description) = 'hooked_claws')
        or (g.gene_name = 'beak_nose_shape' and g.species_type = 4 and lower(a.description) = 'spiral_profile')
        or (g.gene_name = 'shell_armor' and g.species_type = 5 and lower(a.description) = 'plated_shell')
        or (g.gene_name = 'fur_density' and g.species_type = 6 and lower(a.description) = 'soft_fur');
    assert_true(v_value = 8, 'Required content expansion allele codes exist', 'covered=' || v_value);


    -- 2d) Rating/economy event type reference values exist
    select count(*)
      into v_value
      from ref_rating_event_types ret
     where ret.event_type in (
            'TASK_REWARD',
            'MUTAGEN_PENALTY',
            'MUTATION_PURCHASE',
            'EXPERIMENT_COST',
            'RARE_TRAIT_BONUS',
            'SYSTEM_ADJUSTMENT'
       );
    assert_true(v_value = 6, 'Rating event type ref contains 6 values', 'actual=' || v_value);

    -- 3) Each gene has at least 2 alleles
    select count(*)
      into v_value
      from (
            select g.gene_id, count(a.allele_id) as allele_cnt
              from genes g
              left join alleles a
                on a.gene_id = g.gene_id
             group by g.gene_id
           )
     where allele_cnt < 2;
    assert_true(v_value = 0, 'Each gene has >= 2 alleles', 'genes with <2 alleles=' || v_value);

    -- 4) Mutation count >= 8
    select count(*) into v_value from mutations;
    assert_true(v_value >= 20, 'Mutation count >= 20 after content expansion', 'actual=' || v_value);
    -- 4a) First safe content expansion mutation codes exist
    select count(distinct lower(m.mutation_name))
      into v_value
      from mutations m
     where lower(m.mutation_name) in (
            'red_color_mutation',
            'medium_size_mutation',
            'cartilaginous_crescent_fin_mutation',
            'bony_ribbon_fin_mutation',
            'hooked_claws_mutation',
            'spiral_profile_mutation',
            'plated_shell_mutation',
            'soft_fur_mutation'
       );
    assert_true(v_value = 8, 'Required content expansion mutations exist', 'covered=' || v_value);

    -- 5) mutation_rules reference existing mutation_id/gene_id/target_allele_id
    select count(*)
      into v_value
      from mutation_rules mr
      left join mutations m
        on m.mutation_id = mr.mutation_id
      left join genes g
        on g.gene_id = mr.gene_id
      left join alleles a
        on a.allele_id = mr.target_allele_id
     where m.mutation_id is null
        or g.gene_id is null
        or a.allele_id is null;
    assert_true(v_value = 0, 'mutation_rules FK references are valid', 'invalid rows=' || v_value);

    -- 6) mutation_rules target_allele_id belongs to same gene_id
    select count(*)
      into v_value
      from mutation_rules mr
      join alleles a
        on a.allele_id = mr.target_allele_id
     where a.gene_id <> mr.gene_id;
    assert_true(v_value = 0, 'mutation_rules allele belongs to same gene', 'mismatched rows=' || v_value);

    -- 7) mutation_rules cover a broad gene set
    select count(distinct mr.gene_id)
      into v_value
      from mutation_rules mr;
    assert_true(v_value >= 10, 'mutation_rules cover >= 10 genes', 'distinct genes=' || v_value);

    -- 8) mutation_rules include required universal genes
    select count(distinct g.gene_name)
      into v_value
      from mutation_rules mr
      join genes g
        on g.gene_id = mr.gene_id
     where g.species_type = 0
       and g.gene_name in ('color', 'size', 'nutrition_type', 'has_wings');
    assert_true(v_value = 4, 'mutation_rules cover universal genes color/size/nutrition_type/has_wings', 'covered=' || v_value);

    -- 9) mutation_rules include species-specific coverage for all 1..6
    select count(distinct g.species_type)
      into v_value
      from mutation_rules mr
      join genes g
        on g.gene_id = mr.gene_id
     where g.species_type between 1 and 6;
    assert_true(v_value = 6, 'mutation_rules cover species_type 1..6', 'covered species=' || v_value);

    -- 10) mutation_rules are coherent per mutation (no mixed exclusive species-specific rule sets)
    select count(*)
      into v_value
      from (
            select mr.mutation_id
              from mutation_rules mr
              join genes g
                on g.gene_id = mr.gene_id
             where g.species_type between 1 and 6
             group by mr.mutation_id
            having count(distinct g.species_type) > 1
           );
    assert_true(v_value = 0, 'mutation_rules are coherent per mutation species scope', 'mixed mutations=' || v_value);

    -- 11) Task count >= 12
    select count(*) into v_value from tasks;
    assert_true(v_value >= 21, 'Task count >= 21 after content expansion', 'actual=' || v_value);
    -- 11a) First safe content expansion task codes exist
    select count(distinct lower(t.task_name))
      into v_value
      from tasks t
     where lower(t.task_name) in (
            'task_red_specimen',
            'task_medium_specimen',
            'task_winged_red_specimen',
            'task_crescent_fin_cartilaginous',
            'task_ribbon_fin_bony',
            'task_hooked_crustacean',
            'task_spiral_mollusk',
            'task_plated_turtle',
            'task_soft_fur_mammal'
       );
    assert_true(v_value = 9, 'Required content expansion tasks exist', 'covered=' || v_value);

    -- 12) Each task has at least one task_marker
    select count(*)
      into v_value
      from (
            select t.task_id
              from tasks t
              left join task_markers tm
                on tm.task_id = t.task_id
             group by t.task_id
            having count(tm.task_marker_id) = 0
           );
    assert_true(v_value = 0, 'Each task has >= 1 task_marker', 'tasks with no markers=' || v_value);

    -- 13) task_markers reference existing task and allele
    select count(*)
      into v_value
      from task_markers tm
      left join tasks t
        on t.task_id = tm.task_id
      left join alleles a
        on a.allele_id = tm.allele_id
     where t.task_id is null
        or a.allele_id is null;
    assert_true(v_value = 0, 'task_markers references are valid', 'invalid rows=' || v_value);

    -- 14) Task markers cover all species_type 1..6
    select count(distinct g.species_type)
      into v_value
      from task_markers tm
      join alleles a
        on a.allele_id = tm.allele_id
      join genes g
        on g.gene_id = a.gene_id
     where g.species_type between 1 and 6;
    assert_true(v_value = 6, 'task_markers cover species_type 1..6', 'covered species=' || v_value);

    -- 15) Task markers include universal traits
    select count(distinct g.gene_name)
      into v_value
      from task_markers tm
      join alleles a
        on a.allele_id = tm.allele_id
      join genes g
        on g.gene_id = a.gene_id
     where g.species_type = 0
       and g.gene_name in ('color', 'size', 'nutrition_type', 'has_wings');
    assert_true(v_value = 4, 'task_markers cover universal traits color/size/nutrition_type/has_wings', 'covered=' || v_value);

    -- 16) Required universal genes exist
    select count(*)
      into v_value
      from genes g
     where g.species_type = 0
       and g.gene_name in ('color', 'size', 'nutrition_type', 'has_wings');
    assert_true(v_value = 4, 'Universal genes set exists', 'actual=' || v_value);

    -- 17) Data exists for all 6 species_type values
    select count(distinct g.species_type)
      into v_value
      from genes g
     where g.species_type between 1 and 6;
    assert_true(v_value = 6, 'All species_type 1..6 are present in genes', 'distinct species_type count=' || v_value);

    -- 18) Task markers do not contain conflicting alleles of the same gene in one task
    select count(*)
      into v_value
      from (
            select tm.task_id, a.gene_id
              from task_markers tm
              join alleles a
                on a.allele_id = tm.allele_id
             group by tm.task_id, a.gene_id
            having count(distinct tm.allele_id) > 1
           );
    assert_true(v_value = 0, 'No conflicting task_markers within one task gene', 'conflicting groups=' || v_value);


    -- 19) Reference tables are populated
    select count(*)
      into v_value
      from ref_species_types
     where species_type between 0 and 6;
    assert_true(v_value = 7, 'ref_species_types contains 0..6', 'covered=' || v_value);

    select count(*)
      into v_value
      from ref_gene_types
     where gene_type in ('trait', 'morphology', 'performance', 'physiology');
    assert_true(v_value = 4, 'ref_gene_types contains required codes', 'covered=' || v_value);

    select count(*)
      into v_value
      from ref_dominance_types
     where dominance_type in ('FULL', 'INCOMPLETE', 'CODOMINANT');
    assert_true(v_value = 3, 'ref_dominance_types contains required codes', 'covered=' || v_value);

    select count(*)
      into v_value
      from ref_task_statuses
     where task_status in ('ACTIVE', 'COMPLETED');
    assert_true(v_value = 2, 'ref_task_statuses contains ACTIVE/COMPLETED', 'covered=' || v_value);

    select count(*)
      into v_value
      from ref_experiment_types
     where experiment_type in ('CROSS', 'MUTATION', 'MUTAGEN');
    assert_true(v_value = 3, 'ref_experiment_types contains required codes', 'covered=' || v_value);

    select count(*)
      into v_value
      from ref_mutagen_types
     where mutagen_type in ('RADIATION', 'CHEMICAL');
    assert_true(v_value = 2, 'ref_mutagen_types contains RADIATION/CHEMICAL', 'covered=' || v_value);

    select count(*)
      into v_value
      from ref_mutation_types
     where mutation_type between 1 and 8;
    assert_true(v_value = 8, 'ref_mutation_types contains 1..8', 'covered=' || v_value);

    select count(*)
      into v_value
      from ref_task_difficulties
     where difficulty_code in ('EASY', 'MEDIUM', 'HARD');
    assert_true(v_value = 3, 'ref_task_difficulties contains EASY/MEDIUM/HARD', 'covered=' || v_value);

    select count(*)
      into v_value
      from tasks t
     where t.difficulty_code is null;
    assert_true(v_value = 0, 'All tasks have difficulty_code', 'tasks without difficulty=' || v_value);

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    if v_failed_tests > 0 then
        raise_application_error(-20200, 'Seed data smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
end;
/

