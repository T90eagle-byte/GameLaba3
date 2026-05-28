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

    -- 2) Allele count >= 24
    select count(*) into v_value from alleles;
    assert_true(v_value >= 24, 'Allele count >= 24', 'actual=' || v_value);

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
    assert_true(v_value >= 8, 'Mutation count >= 8', 'actual=' || v_value);

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
    assert_true(v_value >= 12, 'Task count >= 12', 'actual=' || v_value);

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

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    if v_failed_tests > 0 then
        raise_application_error(-20200, 'Seed data smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
end;
/

