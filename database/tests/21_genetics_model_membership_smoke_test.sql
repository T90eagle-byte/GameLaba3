-- Validates explicit reference-only canonical gene membership for lab models.
-- It creates no users, laboratories, creatures, or genotypes.

@@../packages/spec/pkg_genetics_game.pks
@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql
@@../migrations/08_add_allele_display_names.sql
@@../migrations/09_add_lab_genetics_version.sql

declare
    v_gene_count     number;
    v_allele_count   number;
    v_genotype_count number;
    v_lab_count      number;
    v_creature_count number;
begin
    select count(*) into v_gene_count from genes;
    select count(*) into v_allele_count from alleles;
    select count(*) into v_genotype_count from genotypes;
    select count(*) into v_lab_count from labs;
    select count(*) into v_creature_count from creatures;
    dbms_application_info.set_client_info(
        'm21:' || v_gene_count || ':' || v_allele_count || ':' || v_genotype_count || ':' ||
        v_lab_count || ':' || v_creature_count
    );
end;
/

@@../migrations/10_add_genetics_model_membership.sql

declare
    v_snapshot varchar2(64);
    v_v1_count number;
    v_v3_count number;
begin
    select count(*) into v_v1_count from ref_genetics_model_genes where genetics_version = 1;
    select count(*) into v_v3_count from ref_genetics_model_genes where genetics_version = 3;
    v_snapshot := sys_context('USERENV', 'CLIENT_INFO');
    dbms_application_info.set_client_info(v_snapshot || ':' || v_v1_count || ':' || v_v3_count);
end;
/

@@../migrations/10_add_genetics_model_membership.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests       number := 0;
    v_passed_tests       number := 0;
    v_value              number;
    v_snapshot           varchar2(64);
    v_gene_count         number;
    v_allele_count       number;
    v_genotype_count     number;
    v_lab_count          number;
    v_creature_count     number;
    v_seed_v1_count      number;
    v_seed_v3_count      number;
    v_error_code         number;
    v_gene_id            number;

    procedure pass_test(p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_test_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end pass_test;

    procedure fail_test(p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_test_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(p_condition in boolean, p_test_name in varchar2, p_detail in varchar2 default null) is
    begin
        if p_condition then
            pass_test(p_test_name, p_detail);
        else
            fail_test(p_test_name, p_detail);
        end if;
    end assert_true;

    procedure assert_member(
        p_version      in number,
        p_species_type in number,
        p_gene_name    in varchar2
    ) is
    begin
        select count(*)
          into v_value
          from ref_genetics_model_genes mg
          join genes g on g.gene_id = mg.gene_id
         where mg.genetics_version = p_version
           and g.species_type = p_species_type
           and g.gene_name = p_gene_name;
        assert_true(
            v_value = 1,
            'v' || p_version || ' contains ' || p_gene_name || ' for species=' || p_species_type,
            'actual=' || v_value
        );
    end assert_member;

    procedure assert_absent_from_v3(
        p_gene_name in varchar2
    ) is
    begin
        select count(*)
          into v_value
          from ref_genetics_model_genes mg
          join genes g on g.gene_id = mg.gene_id
         where mg.genetics_version = 3
           and g.gene_name = p_gene_name;
        assert_true(v_value = 0, 'v3 excludes legacy ' || p_gene_name, 'actual=' || v_value);
    end assert_absent_from_v3;

begin
    v_snapshot := sys_context('USERENV', 'CLIENT_INFO');
    v_gene_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 2));
    v_allele_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 3));
    v_genotype_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 4));
    v_lab_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 5));
    v_creature_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 6));
    v_seed_v1_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 7));
    v_seed_v3_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 8));

    dbms_output.put_line('--- GENETICS MODEL MEMBERSHIP SMOKE TEST ---');

    select count(*) into v_value from user_tables where table_name = 'REF_GENETICS_MODEL_GENES';
    assert_true(v_value = 1, 'REF_GENETICS_MODEL_GENES exists');

    select count(*)
      into v_value
      from user_constraints
     where table_name = 'REF_GENETICS_MODEL_GENES'
       and constraint_name = 'PK_REF_GENETICS_MODEL_GENES'
       and constraint_type = 'P'
       and status = 'ENABLED';
    assert_true(v_value = 1, 'Membership composite primary key is enabled');

    select count(*)
      into v_value
      from user_constraints
     where table_name = 'REF_GENETICS_MODEL_GENES'
       and constraint_name = 'FK_REF_GENETICS_MODEL_GENES_GENE'
       and constraint_type = 'R'
       and status = 'ENABLED';
    assert_true(v_value = 1, 'Membership foreign key to GENES is enabled');

    select count(*)
      into v_value
      from user_constraints
     where table_name = 'REF_GENETICS_MODEL_GENES'
       and constraint_name = 'CK_REF_GENETICS_MODEL_GENES_VERSION'
       and constraint_type = 'C'
       and status = 'ENABLED';
    assert_true(v_value = 1, 'Membership version check is enabled');

    select min(gene_id) into v_gene_id from genes;
    savepoint invalid_membership_version;
    begin
        insert into ref_genetics_model_genes (genetics_version, gene_id)
        values (2, v_gene_id);
        fail_test('Membership rejects genetics_version=2', 'insert unexpectedly succeeded');
        rollback to invalid_membership_version;
    exception
        when others then
            v_error_code := sqlcode;
            rollback to invalid_membership_version;
            assert_true(v_error_code = -2290, 'Membership rejects genetics_version=2', 'sqlcode=' || v_error_code);
    end;

    select count(*) into v_value from ref_genetics_model_genes where genetics_version = 1;
    assert_true(v_value = 12, 'v1 has exact legacy membership count', 'actual=' || v_value);
    assert_true(v_value = v_seed_v1_count, 'Repeated seed preserves v1 count');

    assert_member(1, 0, 'color');
    assert_member(1, 0, 'size');
    assert_member(1, 0, 'nutrition_type');
    assert_member(1, 0, 'has_wings');
    assert_member(1, 1, 'fin_shape');
    assert_member(1, 2, 'fin_shape');
    assert_member(1, 3, 'claw_form');
    assert_member(1, 3, 'shell_armor');
    assert_member(1, 4, 'beak_nose_shape');
    assert_member(1, 5, 'shell_armor');
    assert_member(1, 5, 'speed_level');
    assert_member(1, 6, 'fur_density');

    select count(*)
      into v_value
      from ref_genetics_model_genes mg
      join genes g on g.gene_id = mg.gene_id
     where mg.genetics_version = 1
       and g.species_type = 0
       and g.gene_type = 'morphology';
    assert_true(v_value = 0, 'v1 excludes universal morphology-only genes');

    select count(*) into v_value from ref_genetics_model_genes where genetics_version = 3;
    assert_true(v_value = 19, 'v3 has 18 morphology genes plus nutrition_type', 'actual=' || v_value);
    assert_true(v_value = v_seed_v3_count, 'Repeated seed preserves v3 count');

    assert_member(3, 0, 'body_shape');
    assert_member(3, 0, 'body_proportion');
    assert_member(3, 0, 'body_size');
    assert_member(3, 0, 'body_cover');
    assert_member(3, 0, 'body_color');
    assert_member(3, 0, 'mouth_type');
    assert_member(3, 0, 'snout_type');
    assert_member(3, 0, 'eye_type');
    assert_member(3, 0, 'front_appendage_count');
    assert_member(3, 0, 'front_appendage_type');
    assert_member(3, 0, 'front_appendage_size');
    assert_member(3, 0, 'rear_appendage_count');
    assert_member(3, 0, 'rear_appendage_type');
    assert_member(3, 0, 'rear_appendage_size');
    assert_member(3, 0, 'tail_type');
    assert_member(3, 0, 'tail_size');
    assert_member(3, 0, 'dorsal_type');
    assert_member(3, 0, 'dorsal_size');
    assert_member(3, 0, 'nutrition_type');

    assert_absent_from_v3('color');
    assert_absent_from_v3('size');
    assert_absent_from_v3('has_wings');
    assert_absent_from_v3('fin_shape');
    assert_absent_from_v3('shell_armor');
    assert_absent_from_v3('claw_form');
    assert_absent_from_v3('beak_nose_shape');
    assert_absent_from_v3('speed_level');
    assert_absent_from_v3('fur_density');

    select count(*)
      into v_value
      from ref_genetics_model_genes mg
      left join genes g on g.gene_id = mg.gene_id
     where g.gene_id is null;
    assert_true(v_value = 0, 'Every membership mapping resolves to a gene');

    select count(*)
      into v_value
      from (
            select genetics_version, gene_id
              from ref_genetics_model_genes
             group by genetics_version, gene_id
            having count(*) > 1
      );
    assert_true(v_value = 0, 'Membership has no duplicate version/gene pairs');

    select count(*) into v_value from genes;
    assert_true(v_value = v_gene_count, 'Migration preserves GENES count', 'actual=' || v_value);
    select count(*) into v_value from alleles;
    assert_true(v_value = v_allele_count, 'Migration preserves ALLELES count', 'actual=' || v_value);
    select count(*) into v_value from genotypes;
    assert_true(v_value = v_genotype_count, 'Migration preserves GENOTYPES count', 'actual=' || v_value);
    select count(*) into v_value from labs;
    assert_true(v_value = v_lab_count, 'Migration preserves LABS count', 'actual=' || v_value);
    select count(*) into v_value from creatures;
    assert_true(v_value = v_creature_count, 'Migration preserves CREATURES count', 'actual=' || v_value);

    select count(*)
      into v_value
      from user_objects
     where object_name = 'PKG_GENETICS_GAME'
       and object_type in ('PACKAGE', 'PACKAGE BODY')
       and status = 'VALID';
    assert_true(v_value = 2, 'Package specification and body remain valid', 'actual=' || v_value);

    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME';
    assert_true(v_value = 0, 'Package user_errors remain clean', 'actual=' || v_value);

    dbms_output.put_line('Passed: ' || v_passed_tests || ', Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20990, 'Genetics model membership smoke test failed: ' || v_failed_tests);
    end if;
end;
/
