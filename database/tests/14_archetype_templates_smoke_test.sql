-- Validates the lr3-v3 reference-only archetype genotype templates.
-- The migrations are intentionally rerun to prove the template seed is idempotent.

@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/06_add_archetype_templates.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests number := 0;
    v_passed_tests number := 0;
    v_value        number;
    v_actual_code  varchar2(100);

    procedure pass_test(p_test_name in varchar2) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_test_name);
    end pass_test;

    procedure fail_test(p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_test_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(p_condition in boolean, p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        if p_condition then
            pass_test(p_test_name);
        else
            fail_test(p_test_name, p_detail);
        end if;
    end assert_true;

    procedure assert_mapping(
        p_archetype_code in varchar2,
        p_gene_name      in varchar2,
        p_expected_code  in varchar2
    ) is
    begin
        select a.description
          into v_actual_code
          from ref_archetype_alleles taa
          join ref_creature_archetypes r
            on r.archetype_id = taa.archetype_id
          join genes g
            on g.gene_id = taa.gene_id
          join alleles a
            on a.allele_id = taa.allele1_id
         where r.archetype_code = p_archetype_code
           and g.gene_name = p_gene_name;

        assert_true(
            v_actual_code = p_expected_code,
            p_archetype_code || '.' || p_gene_name || ' resolves to ' || p_expected_code,
            'actual=' || nvl(v_actual_code, '<null>')
        );
    exception
        when no_data_found then
            fail_test(p_archetype_code || '.' || p_gene_name || ' mapping exists');
    end assert_mapping;
begin
    dbms_output.put_line('--- ARCHETYPE TEMPLATE SMOKE TEST ---');

    select count(*)
      into v_value
      from ref_creature_archetypes
     where archetype_code in (
        'shark', 'ray', 'sawfish', 'generic_bony_fish', 'eel', 'pufferfish',
        'crab', 'crayfish', 'shrimp', 'octopus', 'squid', 'snail',
        'sea_turtle', 'sea_snake', 'whale', 'dolphin', 'seal', 'walrus'
     );
    assert_true(v_value = 18, 'All 18 expected archetypes exist', 'actual=' || v_value);

    select count(*)
      into v_value
      from ref_archetype_alleles taa
      join ref_creature_archetypes r
        on r.archetype_id = taa.archetype_id
      join genes g
        on g.gene_id = taa.gene_id
     where r.archetype_code in (
        'shark', 'ray', 'sawfish', 'generic_bony_fish', 'eel', 'pufferfish',
        'crab', 'crayfish', 'shrimp', 'octopus', 'squid', 'snail',
        'sea_turtle', 'sea_snake', 'whale', 'dolphin', 'seal', 'walrus'
     )
       and g.species_type = 0
       and g.gameplay_enabled = 'N';
    assert_true(v_value = 324, 'All 18 by 18 template rows exist', 'actual=' || v_value);

    select count(*)
      into v_value
      from (
          select taa.archetype_id
            from ref_archetype_alleles taa
            join ref_creature_archetypes r
              on r.archetype_id = taa.archetype_id
            join genes g
              on g.gene_id = taa.gene_id
           where r.archetype_code in (
                'shark', 'ray', 'sawfish', 'generic_bony_fish', 'eel', 'pufferfish',
                'crab', 'crayfish', 'shrimp', 'octopus', 'squid', 'snail',
                'sea_turtle', 'sea_snake', 'whale', 'dolphin', 'seal', 'walrus'
           )
             and g.species_type = 0
             and g.gameplay_enabled = 'N'
           group by taa.archetype_id
          having count(*) <> 18
      );
    assert_true(v_value = 0, 'Every archetype has exactly 18 template genes', 'incomplete=' || v_value);

    select count(*)
      into v_value
      from ref_archetype_alleles
     where allele1_id <> allele2_id;
    assert_true(v_value = 0, 'All current templates are homozygous', 'heterozygous=' || v_value);

    select count(*)
      into v_value
      from ref_archetype_alleles taa
      join genes g
        on g.gene_id = taa.gene_id
     where g.species_type <> 0
        or g.gameplay_enabled <> 'N';
    assert_true(v_value = 0, 'Templates use disabled universal morphology genes only', 'unexpected=' || v_value);

    select count(*)
      into v_value
      from ref_archetype_alleles taa
      join alleles a1
        on a1.allele_id = taa.allele1_id
      join alleles a2
        on a2.allele_id = taa.allele2_id
     where a1.gene_id <> taa.gene_id
        or a2.gene_id <> taa.gene_id;
    assert_true(v_value = 0, 'Every template allele belongs to its template gene', 'mismatches=' || v_value);

    assert_mapping('ray', 'body_shape', 'disc');
    assert_mapping('sawfish', 'snout_type', 'saw');
    assert_mapping('eel', 'body_shape', 'eel_like');
    assert_mapping('crab', 'front_appendage_type', 'claw');
    assert_mapping('shrimp', 'body_shape', 'shrimp_like');
    assert_mapping('octopus', 'front_appendage_count', 'eight');
    assert_mapping('squid', 'rear_appendage_count', 'two');
    assert_mapping('snail', 'dorsal_type', 'shell');
    assert_mapping('sea_snake', 'front_appendage_count', 'zero');
    assert_mapping('whale', 'body_size', 'giant');
    assert_mapping('dolphin', 'tail_type', 'cetacean');
    assert_mapping('seal', 'body_shape', 'pinniped');
    assert_mapping('walrus', 'front_appendage_type', 'flipper');

    select count(*)
      into v_value
      from genotypes gt
      join creatures c
        on c.creature_id = gt.creature_id
      join labs l
        on l.lab_id = c.lab_id
      join genes g
        on g.gene_id = gt.gene_id
     where nvl(l.genetics_version, 1) = 1
       and g.gameplay_enabled = 'N';
    assert_true(v_value = 0, 'Legacy v1 runtime genotypes remain unchanged', 'reference_gene_rows=' || v_value);

    select count(*)
      into v_value
      from user_objects
     where object_name = 'PKG_GENETICS_GAME'
       and object_type in ('PACKAGE', 'PACKAGE BODY')
       and status = 'VALID';
    assert_true(v_value = 2, 'Package specification and body remain valid', 'actual=' || v_value);

    select count(*)
      into v_value
      from user_errors
     where name = 'PKG_GENETICS_GAME'
       and type in ('PACKAGE', 'PACKAGE BODY');
    assert_true(v_value = 0, 'Package user_errors remain clean', 'actual=' || v_value);

    dbms_output.put_line('Passed: ' || v_passed_tests || ', Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20990, 'Archetype template smoke test failed: ' || v_failed_tests);
    end if;
end;
/
