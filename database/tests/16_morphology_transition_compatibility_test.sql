-- Diagnostic-only lr3-v3 transition audit.
-- It creates temporary legacy and dual-schema creatures, reports real blockers,
-- and always removes its laboratory. It does not change production runtime data.

@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests            number := 0;
    v_passed_tests            number := 0;
    v_value                   number;
    v_user_id                 number;
    v_lab_id                  number;
    v_session_token           varchar2(128);
    v_login                   varchar2(20) := 't' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password                varchar2(100) := 'transition_audit_123';
    v_legacy_id               number;
    v_dual1_id                number;
    v_dual2_id                number;
    v_legacy_summary          varchar2(1000);
    v_dual_summary            varchar2(1000);
    v_legacy_cache            varchar2(1000);
    v_dual_cache              varchar2(1000);
    v_task_id                 number;
    v_task_before             number;
    v_task_after              number;
    v_preview_morph_rows      number;
    v_offspring_id            number;
    v_offspring_morph_rows    number;
    v_offspring_gene_count    number;
    v_mutation_id             number;
    v_buy_result              number;
    v_before_morph_signature  varchar2(4000);
    v_after_morph_signature   varchar2(4000);
    v_mutagen_child_id        number;
    v_radiation_attempts      number := 0;
    v_radiation_morph_changes number := 0;
    v_radiation_enabled_changes number := 0;
    v_chemical_morph_changed  number := 0;
    v_cursor                  sys_refcursor;
    v_option_no               number;
    v_species_type            number;
    v_species_label           varchar2(4000);
    v_probability             number;
    v_phenotype_summary       varchar2(4000);
    v_genotype_summary        varchar2(4000);
    v_source_note             varchar2(4000);

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

    procedure add_template_genotype(p_creature_id in number) is
    begin
        insert into genotypes (
            genotype_id, creature_id, gene_id, allele1_id, allele2_id
        )
        select
            genotypes_seq.nextval,
            p_creature_id,
            taa.gene_id,
            taa.allele1_id,
            taa.allele2_id
          from creatures c
          join ref_archetype_alleles taa
            on taa.archetype_id = c.archetype_id
         where c.creature_id = p_creature_id;

        if sql%rowcount <> 18 then
            raise_application_error(-20960, 'Expected 18 reference morphology rows, got ' || sql%rowcount || '.');
        end if;
    end add_template_genotype;

    function morphology_signature(p_creature_id in number) return varchar2 is
        v_signature varchar2(4000);
    begin
        select listagg(g.gene_name || '=' || a1.description || '/' || a2.description, '; ')
                   within group (order by g.gene_name)
          into v_signature
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
          join alleles a1
            on a1.allele_id = gt.allele1_id
          join alleles a2
            on a2.allele_id = gt.allele2_id
         where gt.creature_id = p_creature_id
           and g.gameplay_enabled = 'N';
        return v_signature;
    end morphology_signature;

    function gameplay_signature(p_creature_id in number) return varchar2 is
        v_signature varchar2(4000);
    begin
        select listagg(g.gene_name || '=' || a1.description || '/' || a2.description, '; ')
                   within group (order by g.gene_name)
          into v_signature
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
          join alleles a1
            on a1.allele_id = gt.allele1_id
          join alleles a2
            on a2.allele_id = gt.allele2_id
         where gt.creature_id = p_creature_id
           and g.gameplay_enabled = 'Y';
        return v_signature;
    end gameplay_signature;

    procedure inspect_preview(
        p_label          in varchar2,
        p_parent1_id     in number,
        p_parent2_id     in number,
        p_expect_morph   in number
    ) is
        v_rows number := 0;
        v_morph_rows number := 0;
    begin
        v_cursor := pkg_genetics_game.preview_offspring_options(
            p_session_token => v_session_token,
            p_lab_id        => v_lab_id,
            p_parent1_id    => p_parent1_id,
            p_parent2_id    => p_parent2_id,
            p_options_count => 3
        );

        loop
            fetch v_cursor into
                v_option_no,
                v_species_type,
                v_species_label,
                v_probability,
                v_phenotype_summary,
                v_genotype_summary,
                v_source_note;
            exit when v_cursor%notfound;
            v_rows := v_rows + 1;
            if instr(v_genotype_summary, 'body_shape:') > 0 then
                v_morph_rows := v_morph_rows + 1;
            end if;
        end loop;
        close v_cursor;

        assert_true(v_rows = 3, p_label || ' preview returns three samples', 'actual=' || v_rows);
        if p_expect_morph = 1 then
            assert_true(v_morph_rows = v_rows, p_label || ' preview includes all shared morphology genes', 'samples=' || v_morph_rows);
        else
            assert_true(v_morph_rows = 0, p_label || ' preview contains legacy intersection only', 'samples=' || v_morph_rows);
        end if;
    exception
        when others then
            if v_cursor%isopen then
                close v_cursor;
            end if;
            fail_test(p_label || ' preview', sqlerrm);
    end inspect_preview;

    procedure inspect_crossbreed(
        p_label          in varchar2,
        p_parent1_id     in number,
        p_parent2_id     in number,
        p_expect_morph   in number
    ) is
    begin
        pkg_genetics_game.crossbreed(
            p_lab_id         => v_lab_id,
            p_parent1_id     => p_parent1_id,
            p_parent2_id     => p_parent2_id,
            p_offspring_name => 'transition_' || lower(replace(p_label, ' ', '_')),
            p_offspring_id   => v_offspring_id
        );

        select count(*)
          into v_offspring_morph_rows
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
         where gt.creature_id = v_offspring_id
           and g.gameplay_enabled = 'N';

        select count(*)
          into v_offspring_gene_count
          from genotypes
         where creature_id = v_offspring_id;

        if p_expect_morph = 1 then
            assert_true(v_offspring_morph_rows = 18, p_label || ' offspring inherits 18 shared morphology rows', 'actual=' || v_offspring_morph_rows);
        else
            assert_true(v_offspring_morph_rows = 0, p_label || ' offspring retains legacy-only intersection', 'actual=' || v_offspring_morph_rows);
        end if;
        dbms_output.put_line('[INFO] ' || p_label || ' offspring genotype rows=' || v_offspring_gene_count || ', morphology rows=' || v_offspring_morph_rows);
    exception
        when others then
            fail_test(p_label || ' actual crossbreed', sqlerrm);
    end inspect_crossbreed;

    procedure cleanup_test_data is
    begin
        if v_session_token is not null and v_lab_id is not null then
            begin
                pkg_genetics_game.delete_lab(v_session_token, v_lab_id);
            exception when others then
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
        exception when others then
            dbms_output.put_line('[WARN] cleanup user: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end cleanup_test_data;
begin
    dbms_output.put_line('--- MORPHOLOGY TRANSITION COMPATIBILITY AUDIT ---');

    pkg_genetics_game.register_user('Transition audit', v_login, v_password, v_user_id);
    v_session_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.start_new_lab(v_session_token, v_lab_id);

    select min(creature_id), min(creature_id) + 1, min(creature_id) + 2
      into v_legacy_id, v_dual1_id, v_dual2_id
      from creatures
     where lab_id = v_lab_id
       and species_type = 1;

    v_legacy_summary := pkg_genetics_game.get_phenotype(v_dual1_id);
    select nvl(phenotype_color, '<null>') || '|' || nvl(phenotype_size, '<null>') || '|' ||
           nvl(phenotype_has_wings, '<null>') || '|' || nvl(phenotype_nutrition_type, '<null>')
      into v_legacy_cache
      from creatures
     where creature_id = v_dual1_id;

    select min(task_id)
      into v_task_id
      from lab_tasks
     where lab_id = v_lab_id
       and task_status = 'ACTIVE';
    v_task_before := pkg_genetics_game.check_task(v_lab_id, v_task_id, v_dual1_id);

    add_template_genotype(v_dual1_id);
    add_template_genotype(v_dual2_id);
    v_dual_summary := pkg_genetics_game.get_phenotype(v_dual1_id);
    select nvl(phenotype_color, '<null>') || '|' || nvl(phenotype_size, '<null>') || '|' ||
           nvl(phenotype_has_wings, '<null>') || '|' || nvl(phenotype_nutrition_type, '<null>')
      into v_dual_cache
      from creatures
     where creature_id = v_dual1_id;
    v_task_after := pkg_genetics_game.check_task(v_lab_id, v_task_id, v_dual1_id);

    assert_true(v_legacy_cache = v_dual_cache, 'PHENOTYPE LEGACY CACHED FIELDS', 'legacy fields stayed unchanged');
    dbms_output.put_line('[INFO] phenotype before morphology rows: ' || v_legacy_summary);
    dbms_output.put_line('[INFO] phenotype after morphology rows:  ' || v_dual_summary);
    assert_true(
        instr(v_dual_summary, 'body_shape=') = 0
        and v_dual_summary = v_legacy_summary,
        'PHENOTYPE LEGACY COMPATIBILITY',
        'summary ignored disabled morphology rows'
    );

    assert_true(v_task_before = v_task_after, 'TASK COMPATIBILITY', 'check_task result stayed ' || v_task_after);
    select count(*)
      into v_value
      from task_markers tm
      join alleles a
        on a.allele_id = tm.allele_id
      join genes g
        on g.gene_id = a.gene_id
     where g.gameplay_enabled = 'N';
    assert_true(v_value = 0, 'TASK MARKERS reference legacy genes only', 'reference markers=' || v_value);

    inspect_preview('LEGACY x LEGACY', v_legacy_id, v_legacy_id + 3, 0);
    inspect_preview('DUAL x DUAL', v_dual1_id, v_dual2_id, 1);
    inspect_preview('LEGACY x DUAL', v_legacy_id, v_dual1_id, 0);
    inspect_preview('DUAL x LEGACY', v_dual1_id, v_legacy_id, 0);

    inspect_crossbreed('LEGACY x LEGACY', v_legacy_id, v_legacy_id + 3, 0);
    inspect_crossbreed('DUAL x DUAL', v_dual1_id, v_dual2_id, 1);
    inspect_crossbreed('LEGACY x DUAL', v_legacy_id, v_dual1_id, 0);
    inspect_crossbreed('DUAL x LEGACY', v_dual1_id, v_legacy_id, 0);

    select count(*)
      into v_value
      from mutation_rules mr
      join genes g
        on g.gene_id = mr.gene_id
     where g.gameplay_enabled = 'N';
    assert_true(v_value = 0, 'MUTATION COMPATIBILITY: rules target no disabled morphology genes', 'reference rules=' || v_value);

    select min(mr.mutation_id)
      into v_mutation_id
      from mutation_rules mr
     where exists (
            select 1
              from genotypes gt
             where gt.creature_id = v_dual1_id
               and gt.gene_id = mr.gene_id
     );
    if v_mutation_id is not null then
        v_before_morph_signature := morphology_signature(v_dual1_id);
        v_buy_result := pkg_genetics_game.buy_mutation(v_lab_id, v_mutation_id);
        if v_buy_result = 1 then
            pkg_genetics_game.apply_mutation(v_dual1_id, v_mutation_id);
            v_after_morph_signature := morphology_signature(v_dual1_id);
            assert_true(v_before_morph_signature = v_after_morph_signature, 'MUTATION COMPATIBILITY: ordinary mutation leaves morphology rows unchanged');
        else
            fail_test('MUTATION COMPATIBILITY: test mutation purchase', 'buy_mutation returned 0');
        end if;
    else
        fail_test('MUTATION COMPATIBILITY: compatible rule lookup');
    end if;

    v_before_morph_signature := morphology_signature(v_dual1_id);
    pkg_genetics_game.apply_mutagen(v_dual1_id, 'CHEMICAL', v_mutagen_child_id);
    v_after_morph_signature := morphology_signature(v_mutagen_child_id);
    v_chemical_morph_changed := case when v_before_morph_signature = v_after_morph_signature then 0 else 1 end;
    assert_true(v_chemical_morph_changed = 0, 'MUTAGEN COMPATIBILITY: CHEMICAL preserves morphology rows for current species priority', 'changed=' || v_chemical_morph_changed);

    for attempt_no in 1 .. 8 loop
        v_radiation_attempts := v_radiation_attempts + 1;
        v_before_morph_signature := morphology_signature(v_dual1_id);
        v_legacy_summary := gameplay_signature(v_dual1_id);
        pkg_genetics_game.apply_mutagen(v_dual1_id, 'RADIATION', v_mutagen_child_id);
        if morphology_signature(v_mutagen_child_id) <> v_before_morph_signature then
            v_radiation_morph_changes := v_radiation_morph_changes + 1;
        end if;
        if gameplay_signature(v_mutagen_child_id) <> v_legacy_summary then
            v_radiation_enabled_changes := v_radiation_enabled_changes + 1;
        end if;
    end loop;

    assert_true(
        v_radiation_morph_changes = 0,
        'RADIATION MUTAGEN COMPATIBILITY: disabled morphology rows remain unchanged',
        'attempts=' || v_radiation_attempts || ', changed=' || v_radiation_morph_changes
    );
    assert_true(
        v_radiation_enabled_changes > 0,
        'RADIATION MUTAGEN COMPATIBILITY: enabled gameplay gene changed',
        'changed_attempts=' || v_radiation_enabled_changes
    );

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
        raise_application_error(-20990, 'Morphology transition compatibility audit had ' || v_failed_tests || ' unexpected test failure(s).');
    end if;
exception
    when others then
        cleanup_test_data;
        raise;
end;
/
