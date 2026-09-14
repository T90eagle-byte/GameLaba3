-- Validates the lr3-v3 universal morphology dictionary and the gameplay gate.
-- The migration is deliberately invoked twice to prove idempotency.

@@../migrations/05_add_universal_morphology.sql
@@../migrations/05_add_universal_morphology.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests            number := 0;
    v_passed_tests            number := 0;
    v_value                   number;
    v_actual_codes            varchar2(4000);
    v_user_id                 number;
    v_lab_id                  number;
    v_session_token           varchar2(128);
    v_login                   varchar2(20) := 'm' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password                varchar2(100) := 'morphology_smoke_123';
    v_creature_id             number;
    v_runtime_gene_count      number;
    v_creature_gene_count     number;

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

    procedure assert_allele_set(
        p_gene_name      in varchar2,
        p_expected_codes in varchar2
    ) is
    begin
        select listagg(a.description, ',') within group (order by a.description)
          into v_actual_codes
          from genes g
          join alleles a
            on a.gene_id = g.gene_id
         where g.gene_name = p_gene_name
           and g.species_type = 0
           and g.gameplay_enabled = 'N';

        assert_true(
            v_actual_codes = p_expected_codes,
            'Alleles for ' || p_gene_name,
            'actual=' || nvl(v_actual_codes, '<null>')
        );
    end assert_allele_set;

    procedure cleanup_test_data is
    begin
        if v_session_token is not null and v_lab_id is not null then
            begin
                pkg_genetics_game.delete_lab(v_session_token, v_lab_id);
            exception
                when others then
                    dbms_output.put_line('[WARN] cleanup delete_lab: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end if;

        if v_session_token is not null then
            begin
                pkg_genetics_game.logout_user(v_session_token);
            exception
                when others then
                    if sqlcode <> -20021 then
                        dbms_output.put_line('[WARN] cleanup logout_user: ' || sqlcode || ' / ' || sqlerrm);
                    end if;
            end;
        end if;

        delete from sessions
         where user_id = v_user_id
            or user_id in (select user_id from users where login = v_login);
        delete from users
         where user_id = v_user_id
            or login = v_login;
    exception
        when others then
            dbms_output.put_line('[WARN] cleanup direct delete: ' || sqlcode || ' / ' || sqlerrm);
    end cleanup_test_data;
begin
    dbms_output.put_line('--- UNIVERSAL MORPHOLOGY SMOKE TEST ---');

    select count(*)
      into v_value
      from genes
     where gene_name in (
        'body_shape', 'body_proportion', 'body_size', 'body_cover', 'body_color',
        'mouth_type', 'snout_type', 'eye_type',
        'front_appendage_count', 'front_appendage_type', 'front_appendage_size',
        'rear_appendage_count', 'rear_appendage_type', 'rear_appendage_size',
        'tail_type', 'tail_size', 'dorsal_type', 'dorsal_size'
     )
       and species_type = 0
       and gameplay_enabled = 'N';
    assert_true(v_value = 18, 'All 18 reference morphology genes exist and are disabled', 'actual=' || v_value);

    select count(*)
      into v_value
      from genes
     where gameplay_enabled = 'N'
       and gene_name not in (
            'body_shape', 'body_proportion', 'body_size', 'body_cover', 'body_color',
            'mouth_type', 'snout_type', 'eye_type',
            'front_appendage_count', 'front_appendage_type', 'front_appendage_size',
            'rear_appendage_count', 'rear_appendage_type', 'rear_appendage_size',
            'tail_type', 'tail_size', 'dorsal_type', 'dorsal_size'
       );
    assert_true(v_value = 0, 'Only approved reference morphology genes are disabled', 'unexpected=' || v_value);

    select count(*)
      into v_value
      from (
          select gene_name
            from genes
           where gene_name in (
                'body_shape', 'body_proportion', 'body_size', 'body_cover', 'body_color',
                'mouth_type', 'snout_type', 'eye_type',
                'front_appendage_count', 'front_appendage_type', 'front_appendage_size',
                'rear_appendage_count', 'rear_appendage_type', 'rear_appendage_size',
                'tail_type', 'tail_size', 'dorsal_type', 'dorsal_size'
           )
             and species_type = 0
           group by gene_name
          having count(*) > 1
      );
    assert_true(v_value = 0, 'No duplicate morphology gene codes', 'duplicates=' || v_value);

    assert_allele_set('body_shape', 'cephalopod,cetacean,crustacean,disc,eel_like,pinniped,shark_like,shrimp_like,snail_like,streamlined');
    assert_allele_set('body_proportion', 'broad,compact,elongated,flattened,fusiform');
    assert_allele_set('body_size', 'giant,large,medium,small');
    assert_allele_set('body_cover', 'chitin,hard_shell,leathery_skin,rough_skin,scales,smooth_skin,soft_body');
    assert_allele_set('body_color', 'black,blue,brown,gray,green,orange,red,white,yellow');
    assert_allele_set('mouth_type', 'beak,filter_feeding,jawed,standard,suction');
    assert_allele_set('snout_type', 'blunt,elongated,hammer,pointed,saw,standard');
    assert_allele_set('eye_type', 'large,lateral,stalked,standard');
    assert_allele_set('front_appendage_count', 'eight,four,six,two,zero');
    assert_allele_set('front_appendage_type', 'claw,fin,flipper,none,tentacle,walking_leg');
    assert_allele_set('front_appendage_size', 'large,medium,none,small');
    assert_allele_set('rear_appendage_count', 'eight,four,six,two,zero');
    assert_allele_set('rear_appendage_type', 'fin,flipper,none,tentacle,walking_leg');
    assert_allele_set('rear_appendage_size', 'large,medium,none,small');
    assert_allele_set('tail_type', 'cetacean,crustacean,elongated,fish,none,paddle');
    assert_allele_set('tail_size', 'large,medium,none,small');
    assert_allele_set('dorsal_type', 'carapace,dorsal_fin,none,ridge,shell');
    assert_allele_set('dorsal_size', 'large,medium,none,small');

    select count(*)
      into v_value
      from genes
     where (gene_name, species_type) in (
        ('color', 0), ('size', 0), ('nutrition_type', 0), ('has_wings', 0),
        ('fin_shape', 1), ('shell_armor', 3), ('claw_form', 3),
        ('beak_nose_shape', 4), ('speed_level', 5), ('fur_density', 6)
     )
       and gameplay_enabled = 'Y';
    assert_true(v_value = 10, 'Legacy gameplay genes remain enabled', 'actual=' || v_value);

    select count(*)
      into v_value
      from ref_archetype_alleles;
    assert_true(v_value = 0, 'Archetype allele templates remain empty', 'actual=' || v_value);

    select count(*)
      into v_value
      from genotypes gt
      join genes g
        on g.gene_id = gt.gene_id
     where g.gameplay_enabled = 'N';
    assert_true(v_value = 0, 'Existing genotypes were not assigned reference-only genes', 'actual=' || v_value);

    select count(*)
      into v_value
      from user_constraints
     where constraint_name in ('PK_GENES', 'PK_ALLELES', 'UQ_ALLELES_ALLELE_GENE', 'FK_ALLELES_GENE_ID', 'CK_GENES_GAMEPLAY_ENABLED')
       and status = 'ENABLED';
    assert_true(v_value = 5, 'Gene and allele constraints remain enabled', 'actual=' || v_value);

    begin
        pkg_genetics_game.register_user('Morphology smoke', v_login, v_password, v_user_id);
        v_session_token := pkg_genetics_game.login_user(v_login, v_password);
        pkg_genetics_game.start_new_lab(v_session_token, v_lab_id);

        select count(*)
          into v_runtime_gene_count
          from genes
         where species_type in (0, 1)
           and gameplay_enabled = 'Y';

        select min(creature_id)
          into v_creature_id
          from creatures
         where lab_id = v_lab_id
           and species_type = 1;

        select count(*)
          into v_creature_gene_count
          from genotypes
         where creature_id = v_creature_id;
        assert_true(v_creature_gene_count = v_runtime_gene_count, 'New creature uses exactly enabled runtime genes', 'actual=' || v_creature_gene_count || ', expected=' || v_runtime_gene_count);

        select count(*)
          into v_value
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
         where gt.creature_id = v_creature_id
           and g.gameplay_enabled = 'N';
        assert_true(v_value = 0, 'Disabled morphology genes are absent from new creature genotype', 'actual=' || v_value);

        select count(*)
          into v_value
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
         where gt.creature_id = v_creature_id
           and g.gene_name = 'color'
           and g.gameplay_enabled = 'Y';
        assert_true(v_value = 1, 'Existing enabled genes remain in new creature genotype', 'actual=' || v_value);
    exception
        when others then
            fail_test('Gameplay gate regression flow', sqlerrm);
    end;

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

    cleanup_test_data;
    dbms_output.put_line('Passed: ' || v_passed_tests || ', Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20990, 'Universal morphology smoke test failed: ' || v_failed_tests);
    end if;
exception
    when others then
        cleanup_test_data;
        raise;
end;
/
