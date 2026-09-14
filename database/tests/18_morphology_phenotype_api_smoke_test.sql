-- Validates the read-only universal morphology phenotype API.
-- The test creates and removes only its own laboratory and user.

@@../packages/spec/pkg_genetics_game.pks
@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests           number := 0;
    v_passed_tests           number := 0;
    v_value                  number;
    v_user_id                number;
    v_lab_id                 number;
    v_session_token          varchar2(128);
    v_login                  varchar2(20) := 'p' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password               varchar2(100) := 'morphology_api_123';
    v_dolphin_id             number;
    v_whale_id               number;
    v_legacy_id              number;
    v_partial_id             number;
    v_offspring_id           number;
    v_morphology_gene_id     number;
    v_original_allele_id     number;
    v_template_allele_id     number;
    v_replacement_allele_id  number;
    v_replacement_code       varchar2(255);
    v_hetero_gene_id         number;
    v_hetero_gene_code       varchar2(50);
    v_hetero_expected        varchar2(4000);
    v_before_legacy_summary  varchar2(1000);
    v_after_legacy_summary   varchar2(1000);
    v_cursor                 sys_refcursor;
    v_cursor_open            boolean := false;
    v_gene_code              varchar2(50);
    v_gene_display_name      varchar2(255);
    v_allele1_code           varchar2(255);
    v_allele2_code           varchar2(255);
    v_expressed_code          varchar2(4000);
    v_allele1_display_name    varchar2(255);
    v_allele2_display_name    varchar2(255);
    v_expressed_display_name  varchar2(4000);
    v_trait_count            number;
    v_duplicate_codes        number;
    v_missing_gene_displays  number;
    v_homozygous_mismatches  number;
    v_target_expressed        varchar2(4000);
    v_target_allele1          varchar2(255);
    v_target_allele2          varchar2(255);
    v_partial_error_code     number;

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

    procedure close_cursor is
    begin
        if v_cursor_open then
            close v_cursor;
            v_cursor_open := false;
        end if;
    end close_cursor;

    procedure read_morphology(
        p_creature_id       in number,
        p_target_gene_code  in varchar2 default null
    ) is
        v_seen_codes varchar2(4000) := '|';
    begin
        v_trait_count := 0;
        v_duplicate_codes := 0;
        v_missing_gene_displays := 0;
        v_homozygous_mismatches := 0;
        v_target_expressed := null;
        v_target_allele1 := null;
        v_target_allele2 := null;

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
            if instr(v_seen_codes, '|' || v_gene_code || '|') > 0 then
                v_duplicate_codes := v_duplicate_codes + 1;
            end if;
            v_seen_codes := v_seen_codes || v_gene_code || '|';
            if v_gene_display_name is null then
                v_missing_gene_displays := v_missing_gene_displays + 1;
            end if;
            if v_allele1_code = v_allele2_code and v_expressed_code <> v_allele1_code then
                v_homozygous_mismatches := v_homozygous_mismatches + 1;
            end if;
            if v_gene_code = p_target_gene_code then
                v_target_expressed := v_expressed_code;
                v_target_allele1 := v_allele1_code;
                v_target_allele2 := v_allele2_code;
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
    dbms_output.put_line('--- MORPHOLOGY PHENOTYPE API SMOKE TEST ---');

    pkg_genetics_game.register_user('Morphology API smoke', v_login, v_password, v_user_id);
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

    select count(*)
      into v_value
      from genotypes gt
      join genes g on g.gene_id = gt.gene_id
     where gt.creature_id = v_dolphin_id
       and g.species_type = 0
       and g.gene_type = 'morphology';
    assert_true(v_value = 18, 'Starter has 18 morphology rows', 'actual=' || v_value);

    v_before_legacy_summary := pkg_genetics_game.get_phenotype(v_dolphin_id);
    read_morphology(v_dolphin_id);
    assert_true(v_trait_count = 18, 'Starter morphology cursor returns 18 traits', 'actual=' || v_trait_count);
    assert_true(v_duplicate_codes = 0, 'Starter morphology cursor has unique technical codes');
    assert_true(v_missing_gene_displays = 0, 'Starter morphology cursor has gene display names');
    assert_true(v_homozygous_mismatches = 0, 'Homozygous starter expressions match their alleles');
    v_after_legacy_summary := pkg_genetics_game.get_phenotype(v_dolphin_id);
    assert_true(v_before_legacy_summary = v_after_legacy_summary, 'Legacy get_phenotype remains unchanged by morphology read');

    select count(*)
      into v_value
      from genotypes gt
      join creatures c on c.creature_id = gt.creature_id
      join ref_archetype_alleles taa on taa.archetype_id = c.archetype_id and taa.gene_id = gt.gene_id
     where c.creature_id = v_dolphin_id
       and (gt.allele1_id <> taa.allele1_id or gt.allele2_id <> taa.allele2_id);
    assert_true(v_value = 0, 'Starter morphology initially matches its archetype template');

    select gt.gene_id, gt.allele1_id, taa.allele1_id
      into v_morphology_gene_id, v_original_allele_id, v_template_allele_id
      from genotypes gt
      join genes g on g.gene_id = gt.gene_id
      join creatures c on c.creature_id = gt.creature_id
      join ref_archetype_alleles taa on taa.archetype_id = c.archetype_id and taa.gene_id = gt.gene_id
     where gt.creature_id = v_dolphin_id
       and g.gene_name = 'body_shape';

    select allele_id, description
      into v_replacement_allele_id, v_replacement_code
      from (
            select allele_id, description
              from alleles
             where gene_id = v_morphology_gene_id
               and allele_id <> v_original_allele_id
             order by allele_id
      )
     where rownum = 1;
    update genotypes
       set allele1_id = v_replacement_allele_id,
           allele2_id = v_replacement_allele_id
     where creature_id = v_dolphin_id
       and gene_id = v_morphology_gene_id;

    read_morphology(v_dolphin_id, 'body_shape');
    assert_true(v_target_expressed = v_replacement_code, 'Morphology cursor reads changed GENOTYPES value', 'actual=' || v_target_expressed);
    assert_true(v_template_allele_id <> v_replacement_allele_id, 'Changed morphology value differs from archetype template');

    select gene_id, gene_name
      into v_hetero_gene_id, v_hetero_gene_code
      from (
            select gt1.gene_id, g.gene_name
              from genotypes gt1
              join genotypes gt2 on gt2.creature_id = v_whale_id and gt2.gene_id = gt1.gene_id
              join genes g on g.gene_id = gt1.gene_id
             where gt1.creature_id = v_dolphin_id
               and g.species_type = 0
               and g.gene_type = 'morphology'
               and gt1.allele1_id <> gt2.allele1_id
             order by gt1.gene_id
      )
     where rownum = 1;
    assert_true(v_hetero_gene_id is not null, 'Dual parents have a differing morphology gene');

    pkg_genetics_game.crossbreed(v_lab_id, v_dolphin_id, v_whale_id, 'morphology_api_offspring', v_offspring_id);
    select count(*) into v_value from creatures where creature_id = v_offspring_id and archetype_id is null;
    assert_true(v_value = 1, 'Dual-schema offspring has no archetype');
    read_morphology(v_offspring_id, v_hetero_gene_code);
    assert_true(v_trait_count = 18, 'Offspring morphology cursor returns 18 traits', 'actual=' || v_trait_count);
    assert_true(v_target_allele1 <> v_target_allele2, 'Offspring cursor exposes both heterozygous alleles');
    v_hetero_expected := pkg_genetics_game.get_dominant_allele(v_offspring_id, v_hetero_gene_id);
    assert_true(v_target_expressed = v_hetero_expected, 'Morphology expression uses canonical dominance semantics', 'actual=' || v_target_expressed);

    select min(creature_id)
      into v_legacy_id
      from creatures
     where lab_id = v_lab_id
       and species_type = 1;
    delete from genotypes gt
     where gt.creature_id = v_legacy_id
       and exists (
            select 1 from genes g
             where g.gene_id = gt.gene_id
               and g.species_type = 0
               and g.gene_type = 'morphology'
       );
    read_morphology(v_legacy_id);
    assert_true(v_trait_count = 0, 'Legacy-only creature returns an empty morphology cursor');

    select min(creature_id)
      into v_partial_id
      from creatures
     where lab_id = v_lab_id
       and species_type = 2;
    delete from genotypes
     where genotype_id = (
            select genotype_id
              from (
                    select gt.genotype_id
                      from genotypes gt
                      join genes g on g.gene_id = gt.gene_id
                     where gt.creature_id = v_partial_id
                       and g.species_type = 0
                       and g.gene_type = 'morphology'
                     order by gt.gene_id
              )
             where rownum = 1
       );
    begin
        read_morphology(v_partial_id);
        fail_test('Partial morphology genotype is rejected', 'no error was raised');
    exception
        when others then
            v_partial_error_code := sqlcode;
    end;
    assert_true(v_partial_error_code = -20083, 'Partial morphology genotype is rejected', 'sqlcode=' || v_partial_error_code);

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
        raise_application_error(-20992, 'Morphology phenotype API smoke test had ' || v_failed_tests || ' failure(s).');
    end if;
exception
    when others then
        cleanup_test_data;
        raise;
end;
/
