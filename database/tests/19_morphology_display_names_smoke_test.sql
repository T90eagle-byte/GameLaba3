-- Validates additive Russian display names for universal morphology alleles.
-- The test creates and removes only its own laboratory and user.

@@../packages/spec/pkg_genetics_game.pks
@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql
@@../migrations/08_add_allele_display_names.sql

declare
    v_morphology_allele_count number;
    v_morphology_allele_id_sum number;
    v_genotype_count number;
    v_template_count number;
begin
    select count(*), sum(a.allele_id)
      into v_morphology_allele_count, v_morphology_allele_id_sum
      from alleles a
      join genes g on g.gene_id = a.gene_id
     where g.species_type = 0
       and g.gene_type = 'morphology';
    select count(*) into v_genotype_count from genotypes;
    select count(*) into v_template_count from ref_archetype_alleles;
    dbms_application_info.set_client_info(
        'morph:' || v_morphology_allele_count || ':' || v_morphology_allele_id_sum || ':' || v_genotype_count || ':' || v_template_count
    );
end;
/

@@../migrations/08_add_allele_display_names.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests             number := 0;
    v_passed_tests             number := 0;
    v_value                    number;
    v_user_id                  number;
    v_lab_id                   number;
    v_session_token            varchar2(128);
    v_login                    varchar2(20) := 'd' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password                 varchar2(100) := 'display_name_123';
    v_dolphin_id               number;
    v_whale_id                 number;
    v_offspring_id             number;
    v_before_legacy_summary    varchar2(1000);
    v_after_legacy_summary     varchar2(1000);
    v_cursor                   sys_refcursor;
    v_cursor_open              boolean := false;
    v_gene_code                varchar2(50);
    v_gene_display_name        varchar2(255);
    v_allele1_code             varchar2(255);
    v_allele2_code             varchar2(255);
    v_expressed_code           varchar2(4000);
    v_allele1_display_name     varchar2(255);
    v_allele2_display_name     varchar2(255);
    v_expressed_display_name   varchar2(4000);
    v_trait_count              number;
    v_missing_display_count    number;
    v_snapshot                 varchar2(64);
    v_snapshot_allele_count    number;
    v_snapshot_allele_id_sum   number;
    v_snapshot_genotype_count  number;
    v_snapshot_template_count  number;

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

    procedure assert_display(
        p_gene_code     in varchar2,
        p_technical_code in varchar2,
        p_display_name  in varchar2
    ) is
        v_display_name alleles.display_name%type;
    begin
        select a.display_name
          into v_display_name
          from alleles a
          join genes g on g.gene_id = a.gene_id
         where g.gene_name = p_gene_code
           and g.species_type = 0
           and a.description = p_technical_code;
        assert_true(v_display_name = p_display_name, p_technical_code || ' display name', 'actual=' || nvl(v_display_name, '<null>'));
    end assert_display;

    procedure close_cursor is
    begin
        if v_cursor_open then
            close v_cursor;
            v_cursor_open := false;
        end if;
    end close_cursor;

    procedure read_morphology(p_creature_id in number) is
    begin
        v_trait_count := 0;
        v_missing_display_count := 0;
        v_cursor := pkg_genetics_game.get_morphology_cursor(p_creature_id);
        v_cursor_open := true;
        loop
            fetch v_cursor into
                v_gene_code,
                v_gene_display_name,
                v_allele1_code,
                v_allele2_code,
                v_expressed_code,
                v_allele1_display_name,
                v_allele2_display_name,
                v_expressed_display_name;
            exit when v_cursor%notfound;
            v_trait_count := v_trait_count + 1;
            if v_allele1_code is null
               or v_allele2_code is null
               or v_expressed_code is null
               or v_allele1_display_name is null
               or v_allele2_display_name is null
               or v_expressed_display_name is null then
                v_missing_display_count := v_missing_display_count + 1;
            end if;
        end loop;
        close_cursor;
    exception
        when others then
            close_cursor;
            raise;
    end read_morphology;

    procedure cleanup_test_data is
    begin
        close_cursor;
        if v_session_token is not null and v_lab_id is not null then
            begin
                pkg_genetics_game.delete_lab(v_session_token, v_lab_id);
            exception
                when others then
                    dbms_output.put_line('[WARN] cleanup lab: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end if;
        begin
            delete from sessions
             where user_id = v_user_id
                or user_id in (select user_id from users where login = v_login);
            delete from users
             where user_id = v_user_id
                or login = v_login;
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup user: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end cleanup_test_data;
begin
    dbms_output.put_line('--- MORPHOLOGY DISPLAY-NAME SMOKE TEST ---');

    v_snapshot := sys_context('USERENV', 'CLIENT_INFO');
    v_snapshot_allele_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 2));
    v_snapshot_allele_id_sum := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 3));
    v_snapshot_genotype_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 4));
    v_snapshot_template_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 5));

    select count(*)
      into v_value
      from user_tab_columns
     where table_name = 'ALLELES'
       and column_name = 'DISPLAY_NAME'
       and data_type = 'VARCHAR2'
       and char_length = 128
       and nullable = 'Y';
    assert_true(v_value = 1, 'ALLELES.DISPLAY_NAME is nullable VARCHAR2(128 CHAR)');

    select count(*)
      into v_value
      from alleles a
      join genes g on g.gene_id = a.gene_id
     where g.species_type = 0
       and g.gene_type = 'morphology';
    assert_true(v_value = 98, 'All 98 morphology alleles remain present', 'actual=' || v_value);
    assert_true(v_value = v_snapshot_allele_count, 'Repeated seed keeps morphology allele count');

    select sum(a.allele_id)
      into v_value
      from alleles a
      join genes g on g.gene_id = a.gene_id
     where g.species_type = 0
       and g.gene_type = 'morphology';
    assert_true(v_value = v_snapshot_allele_id_sum, 'Repeated seed keeps morphology allele IDs', 'actual=' || v_value);

    select count(*)
      into v_value
      from alleles a
      join genes g on g.gene_id = a.gene_id
     where g.species_type = 0
       and g.gene_type = 'morphology'
       and a.display_name is not null;
    assert_true(v_value = 98, 'All morphology alleles have display names', 'actual=' || v_value);

    select count(*)
      into v_value
      from (
            select g.gene_name, a.description
              from alleles a
              join genes g on g.gene_id = a.gene_id
             where g.species_type = 0
               and g.gene_type = 'morphology'
             group by g.gene_name, a.description
            having count(*) > 1
      );
    assert_true(v_value = 0, 'Technical morphology codes remain unique');

    assert_display('body_shape', 'disc', 'Дискообразная');
    assert_display('body_shape', 'cetacean', 'Китообразная');
    assert_display('front_appendage_type', 'flipper', 'Ласты');
    assert_display('front_appendage_type', 'claw', 'Клешни');
    assert_display('snout_type', 'saw', 'Пилообразная');
    assert_display('body_size', 'giant', 'Гигантский');
    assert_display('tail_type', 'crustacean', 'Хвост ракообразного');
    assert_display('dorsal_type', 'shell', 'Раковина');

    select count(*) into v_value from ref_archetype_alleles;
    assert_true(v_value = 324, 'Reference archetype templates remain unchanged', 'actual=' || v_value);
    assert_true(v_value = v_snapshot_template_count, 'Repeated seed keeps reference template count');

    select count(*) into v_value from genotypes;
    assert_true(v_value = v_snapshot_genotype_count, 'Repeated seed keeps existing genotype count', 'actual=' || v_value);

    pkg_genetics_game.register_user('Display-name smoke', v_login, v_password, v_user_id);
    v_session_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.start_new_lab(v_session_token, v_lab_id);

    select min(c.creature_id)
      into v_dolphin_id
      from creatures c
      join ref_creature_archetypes r on r.archetype_id = c.archetype_id
     where c.lab_id = v_lab_id
       and r.archetype_code = 'dolphin';
    select min(c.creature_id)
      into v_whale_id
      from creatures c
      join ref_creature_archetypes r on r.archetype_id = c.archetype_id
     where c.lab_id = v_lab_id
       and r.archetype_code = 'whale';

    v_before_legacy_summary := pkg_genetics_game.get_phenotype(v_dolphin_id);
    read_morphology(v_dolphin_id);
    assert_true(v_trait_count = 18, 'Starter morphology cursor returns 18 traits', 'actual=' || v_trait_count);
    assert_true(v_missing_display_count = 0, 'Starter morphology cursor returns technical and display values');
    v_after_legacy_summary := pkg_genetics_game.get_phenotype(v_dolphin_id);
    assert_true(v_before_legacy_summary = v_after_legacy_summary, 'Legacy get_phenotype remains unchanged');

    pkg_genetics_game.crossbreed(v_lab_id, v_dolphin_id, v_whale_id, 'display_name_offspring', v_offspring_id);
    read_morphology(v_offspring_id);
    assert_true(v_trait_count = 18, 'Offspring morphology cursor returns 18 traits', 'actual=' || v_trait_count);
    assert_true(v_missing_display_count = 0, 'Offspring morphology cursor returns display values');

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
        raise_application_error(-20993, 'Morphology display-name smoke test had ' || v_failed_tests || ' failure(s).');
    end if;
exception
    when others then
        cleanup_test_data;
        raise;
end;
/
