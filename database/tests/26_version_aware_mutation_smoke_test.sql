-- Version-aware mutation runtime smoke test.
-- Fixtures are isolated and removed before completion.

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests             number := 0;
    v_passed_tests             number := 0;
    v_value                    number;
    v_error_code               number;
    v_user_v1_id               number;
    v_user_v3_id               number;
    v_lab_v1_id                number;
    v_lab_v3_id                number;
    v_creature_v1_id           number;
    v_creature_v3_id           number;
    v_mutagen_child_id         number;
    v_token_v1                 varchar2(128);
    v_token_v3                 varchar2(128);
    v_login_v1                 varchar2(20) := 'm' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_login_v3                 varchar2(20) := 'n' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password                 varchar2(100) := 'mutation_v3_123';
    v_legacy_mutation_id       number;
    v_fixture_mutation_id      number;
    v_body_color_gene_id       number;
    v_body_shape_gene_id       number;
    v_brown_allele_id          number;
    v_other_color_allele_id    number;
    v_cetacean_allele_id       number;
    v_legacy_gene_id           number;
    v_legacy_target_allele_id  number;
    v_legacy_other_allele_id   number;
    v_nutrition_mutation_id    number;
    v_task_id                  number;
    v_before_genotype_count    number;
    v_before_experiment_count  number;
    v_before_wallet            number;
    v_before_mutation_quantity number;
    v_before_allele1_id         number;
    v_before_allele2_id         number;
    v_morphology_rows          number := 0;
    v_cursor                   sys_refcursor;
    v_cursor_gene_code         varchar2(100);
    v_cursor_gene_display      varchar2(4000);
    v_cursor_allele1           varchar2(4000);
    v_cursor_allele2           varchar2(4000);
    v_cursor_expressed         varchar2(4000);
    v_cursor_allele1_display   varchar2(4000);
    v_cursor_allele2_display   varchar2(4000);
    v_cursor_expressed_display varchar2(4000);
    v_shop_mutation_id         number;
    v_shop_mutation_name       varchar2(100);
    v_shop_mutation_type       varchar2(100);
    v_shop_mutation_type_name  varchar2(4000);
    v_shop_description         varchar2(4000);
    v_shop_price               number;
    v_shop_rating_effect       number;
    v_shop_legacy_count        number := 0;
    v_shop_nutrition_count     number := 0;
    v_shop_fixture_count       number := 0;
    v_baseline_labs            number;
    v_baseline_creatures       number;
    v_baseline_genotypes       number;
    v_baseline_lab_tasks       number;
    v_baseline_experiments     number;
    v_baseline_lab_mutations   number;
    v_baseline_rating_events   number;

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

    procedure cleanup is
    begin
        if v_lab_v1_id is not null then
            delete from rating_events where lab_id = v_lab_v1_id;
            delete from experiments where lab_id = v_lab_v1_id;
            delete from lab_mutations where lab_id = v_lab_v1_id;
            delete from lab_tasks where lab_id = v_lab_v1_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab_v1_id);
            delete from creatures where lab_id = v_lab_v1_id;
            delete from labs where lab_id = v_lab_v1_id;
        end if;

        if v_lab_v3_id is not null then
            delete from rating_events where lab_id = v_lab_v3_id;
            delete from experiments where lab_id = v_lab_v3_id;
            delete from lab_mutations where lab_id = v_lab_v3_id;
            delete from lab_tasks where lab_id = v_lab_v3_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab_v3_id);
            delete from creatures where lab_id = v_lab_v3_id;
            delete from labs where lab_id = v_lab_v3_id;
        end if;

        if v_fixture_mutation_id is not null then
            delete from mutation_rules where mutation_id = v_fixture_mutation_id;
            delete from mutations where mutation_id = v_fixture_mutation_id;
        end if;

        if v_user_v1_id is not null then
            delete from sessions where user_id = v_user_v1_id;
            delete from users where user_id = v_user_v1_id;
        end if;
        if v_user_v3_id is not null then
            delete from sessions where user_id = v_user_v3_id;
            delete from users where user_id = v_user_v3_id;
        end if;
        commit;
    end cleanup;

begin
    select count(*) into v_baseline_labs from labs;
    select count(*) into v_baseline_creatures from creatures;
    select count(*) into v_baseline_genotypes from genotypes;
    select count(*) into v_baseline_lab_tasks from lab_tasks;
    select count(*) into v_baseline_experiments from experiments;
    select count(*) into v_baseline_lab_mutations from lab_mutations;
    select count(*) into v_baseline_rating_events from rating_events;

    select m.mutation_id, mr.gene_id, mr.target_allele_id
      into v_legacy_mutation_id, v_legacy_gene_id, v_legacy_target_allele_id
      from mutations m
      join mutation_rules mr on mr.mutation_id = m.mutation_id
     where m.mutation_name = 'red_color_mutation';

    select min(a.allele_id)
      into v_legacy_other_allele_id
      from alleles a
     where a.gene_id = v_legacy_gene_id
       and a.allele_id <> v_legacy_target_allele_id;

    select min(mr.mutation_id)
      into v_nutrition_mutation_id
      from mutation_rules mr
      join genes g on g.gene_id = mr.gene_id
     where g.gene_name = 'nutrition_type';

    select g.gene_id into v_body_color_gene_id from genes g where g.gene_name = 'body_color' and g.species_type = 0;
    select g.gene_id into v_body_shape_gene_id from genes g where g.gene_name = 'body_shape' and g.species_type = 0;
    select a.allele_id into v_brown_allele_id from alleles a where a.gene_id = v_body_color_gene_id and a.description = 'brown';
    select a.allele_id into v_cetacean_allele_id from alleles a where a.gene_id = v_body_shape_gene_id and a.description = 'cetacean';
    select a.allele_id
      into v_other_color_allele_id
      from (
            select a.allele_id
              from alleles a
             where a.gene_id = v_body_color_gene_id
               and a.allele_id <> v_brown_allele_id
               and a.dominance < (select b.dominance from alleles b where b.allele_id = v_brown_allele_id)
             order by a.dominance desc, a.allele_id
           ) a
     where rownum = 1;
    select t.task_id into v_task_id from tasks t where t.task_name = 'task_v3_brown_cetacean' and t.genetics_version = 3;

    -- V1 keeps the existing rule-driven mutation and mutagen paths.
    pkg_genetics_game.register_user('Mutation v1 fixture', v_login_v1, v_password, v_user_v1_id);
    v_token_v1 := pkg_genetics_game.login_user(v_login_v1, v_password);
    pkg_genetics_game.start_new_lab(v_token_v1, v_lab_v1_id);
    update labs set genetics_version = 1, wallet = 10000 where lab_id = v_lab_v1_id;
    pkg_genetics_game.load_lab(v_token_v1, v_lab_v1_id);
    select min(creature_id) into v_creature_v1_id from creatures where lab_id = v_lab_v1_id;
    update genotypes
       set allele1_id = v_legacy_other_allele_id,
           allele2_id = v_legacy_other_allele_id
     where creature_id = v_creature_v1_id
       and gene_id = v_legacy_gene_id;
    assert_true(pkg_genetics_game.buy_mutation(v_lab_v1_id, v_legacy_mutation_id) = 1, 'V1 buys legacy mutation');
    pkg_genetics_game.apply_mutation(v_creature_v1_id, v_legacy_mutation_id);
    select count(*) into v_value from genotypes where creature_id = v_creature_v1_id and gene_id = v_legacy_gene_id and (allele1_id = v_legacy_target_allele_id or allele2_id = v_legacy_target_allele_id);
    assert_true(v_value = 1, 'V1 ordinary mutation keeps legacy rule path');
    v_cursor := pkg_genetics_game.show_lab_mutation_shop(v_lab_v1_id);
    loop
        fetch v_cursor into v_shop_mutation_id, v_shop_mutation_name, v_shop_mutation_type,
              v_shop_mutation_type_name, v_shop_description, v_shop_price, v_shop_rating_effect;
        exit when v_cursor%notfound;
        if v_shop_mutation_id = v_legacy_mutation_id then
            v_shop_legacy_count := v_shop_legacy_count + 1;
        end if;
    end loop;
    close v_cursor;
    assert_true(v_shop_legacy_count = 1, 'V1 catalog retains legacy directed mutation');
    v_shop_legacy_count := 0;
    pkg_genetics_game.apply_mutagen(v_creature_v1_id, 'CHEMICAL', v_mutagen_child_id);
    select count(*) into v_value from genotypes child join genotypes source on source.creature_id = v_creature_v1_id and source.gene_id = child.gene_id join genes g on g.gene_id = child.gene_id where child.creature_id = v_mutagen_child_id and g.gameplay_enabled = 'Y' and (child.allele1_id <> source.allele1_id or child.allele2_id <> source.allele2_id);
    assert_true(v_value > 0, 'V1 chemical mutagen keeps legacy candidate path', 'changed=' || v_value);

    -- V3 uses canonical membership rather than gameplay_enabled.
    pkg_genetics_game.register_user('Mutation v3 fixture', v_login_v3, v_password, v_user_v3_id);
    v_token_v3 := pkg_genetics_game.login_user(v_login_v3, v_password);
    pkg_genetics_game.start_new_lab(v_token_v3, v_lab_v3_id);
    update labs set wallet = 50000 where lab_id = v_lab_v3_id;
    select min(creature_id) into v_creature_v3_id from creatures where lab_id = v_lab_v3_id;
    delete from lab_tasks where lab_id = v_lab_v3_id;
    update genotypes set allele1_id = v_cetacean_allele_id, allele2_id = v_cetacean_allele_id where creature_id = v_creature_v3_id and gene_id = v_body_shape_gene_id;
    update genotypes set allele1_id = v_other_color_allele_id, allele2_id = v_other_color_allele_id where creature_id = v_creature_v3_id and gene_id = v_body_color_gene_id;
    insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at) values (lab_tasks_seq.nextval, v_lab_v3_id, v_task_id, 'ACTIVE', systimestamp, null);

    select mutations_seq.nextval into v_fixture_mutation_id from dual;
    insert into mutations (mutation_id, mutation_name, mutation_type, description, cost, rating_effect, created_at)
    values (v_fixture_mutation_id, 'task18_body_color_fixture', null, 'Тестовая мутация цвета тела.', 0, 0, systimestamp);
    insert into mutation_rules (mutation_rule_id, mutation_id, gene_id, target_allele_id, target_slot, created_at)
    values (mutation_rules_seq.nextval, v_fixture_mutation_id, v_body_color_gene_id, v_brown_allele_id, '1', systimestamp);
    select count(*) into v_value from mutation_rules mr join alleles a on a.allele_id = mr.target_allele_id and a.gene_id = mr.gene_id where mr.mutation_id = v_fixture_mutation_id;
    assert_true(v_value = 1, 'V3 target allele belongs to the same morphology gene');

    assert_true(pkg_genetics_game.buy_mutation(v_lab_v3_id, v_fixture_mutation_id) = 1, 'V3 buys morphology-compatible fixture mutation');
    pkg_genetics_game.apply_mutation(v_creature_v3_id, v_fixture_mutation_id);
    select count(*) into v_value from genotypes where creature_id = v_creature_v3_id and gene_id = v_body_color_gene_id and allele1_id = v_brown_allele_id and allele2_id = v_other_color_allele_id;
    assert_true(v_value = 1, 'V3 ordinary mutation changes only the canonical morphology allele');
    select count(*) into v_value from lab_tasks where lab_id = v_lab_v3_id and task_id = v_task_id and task_status = 'COMPLETED';
    assert_true(v_value = 1, 'V3 morphology mutation auto-completes matching task');
    select count(*) into v_value from rating_events where lab_id = v_lab_v3_id and task_id = v_task_id and event_type = 'TASK_REWARD';
    assert_true(v_value = 1, 'V3 auto-complete reward is recorded once');

    v_cursor := pkg_genetics_game.get_morphology_cursor(v_creature_v3_id);
    loop
        fetch v_cursor into v_cursor_gene_code, v_cursor_gene_display, v_cursor_allele1, v_cursor_allele2, v_cursor_expressed, v_cursor_allele1_display, v_cursor_allele2_display, v_cursor_expressed_display;
        exit when v_cursor%notfound;
        v_morphology_rows := v_morphology_rows + 1;
    end loop;
    close v_cursor;
    assert_true(v_morphology_rows = 18, 'V3 morphology cursor remains readable after mutation', 'rows=' || v_morphology_rows);

    v_cursor := pkg_genetics_game.get_compatible_creatures_for_mutation_cursor(v_lab_v3_id, v_legacy_mutation_id);
    fetch v_cursor into v_value;
    assert_true(v_cursor%notfound, 'V3 does not offer legacy-rule mutation as compatible');
    close v_cursor;

    assert_true(
        pkg_genetics_game.mutation_rules_match_genetics_version(v_legacy_mutation_id, 1) = 1,
        'V1 eligibility keeps legacy directed mutation'
    );
    assert_true(
        pkg_genetics_game.mutation_rules_match_genetics_version(v_legacy_mutation_id, 3) = 0,
        'V3 eligibility excludes legacy directed mutation'
    );
    assert_true(
        pkg_genetics_game.mutation_rules_match_genetics_version(v_fixture_mutation_id, 3) = 1,
        'V3 eligibility accepts morphology-compatible mutation'
    );
    assert_true(
        pkg_genetics_game.mutation_rules_match_genetics_version(v_nutrition_mutation_id, 3) = 0,
        'V3 eligibility excludes nutrition rule'
    );

    v_cursor := pkg_genetics_game.show_lab_mutation_shop(v_lab_v3_id);
    loop
        fetch v_cursor into v_shop_mutation_id, v_shop_mutation_name, v_shop_mutation_type,
              v_shop_mutation_type_name, v_shop_description, v_shop_price, v_shop_rating_effect;
        exit when v_cursor%notfound;
        if v_shop_mutation_id = v_legacy_mutation_id then
            v_shop_legacy_count := v_shop_legacy_count + 1;
        end if;
        if v_shop_mutation_id = v_nutrition_mutation_id then
            v_shop_nutrition_count := v_shop_nutrition_count + 1;
        end if;
        if v_shop_mutation_id = v_fixture_mutation_id then
            v_shop_fixture_count := v_shop_fixture_count + 1;
        end if;
    end loop;
    close v_cursor;
    assert_true(v_shop_legacy_count = 0, 'V3 catalog excludes legacy-rule mutation');
    assert_true(v_shop_nutrition_count = 0, 'V3 catalog excludes nutrition rule');
    assert_true(v_shop_fixture_count = 1, 'V3 catalog includes morphology-compatible mutation');

    select count(*) into v_before_genotype_count from genotypes where creature_id = v_creature_v3_id;
    select count(*) into v_before_experiment_count from experiments where lab_id = v_lab_v3_id;
    select wallet into v_before_wallet from labs where lab_id = v_lab_v3_id;
    select nvl(max(quantity), 0)
      into v_before_mutation_quantity
      from lab_mutations
     where lab_id = v_lab_v3_id
       and mutation_id = v_legacy_mutation_id;
    select allele1_id, allele2_id into v_before_allele1_id, v_before_allele2_id from genotypes where creature_id = v_creature_v3_id and gene_id = v_body_color_gene_id;
    begin
        v_value := pkg_genetics_game.buy_mutation(v_lab_v3_id, v_legacy_mutation_id);
        fail_test('V3 purchase of legacy-rule mutation is rejected', 'call unexpectedly returned ' || v_value);
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20088, 'V3 purchase of legacy-rule mutation is rejected', 'actual=' || v_error_code);
    end;
    select count(*) into v_value from labs where lab_id = v_lab_v3_id and wallet = v_before_wallet;
    assert_true(v_value = 1, 'Rejected V3 purchase leaves wallet unchanged');
    select nvl(sum(quantity), 0)
      into v_value
      from lab_mutations
     where lab_id = v_lab_v3_id
       and mutation_id = v_legacy_mutation_id;
    assert_true(v_value = v_before_mutation_quantity, 'Rejected V3 purchase leaves inventory unchanged');

    select nvl(max(quantity), 0)
      into v_before_mutation_quantity
      from lab_mutations
     where lab_id = v_lab_v3_id
       and mutation_id = v_nutrition_mutation_id;
    begin
        v_value := pkg_genetics_game.buy_mutation(v_lab_v3_id, v_nutrition_mutation_id);
        fail_test('V3 purchase of nutrition mutation is rejected', 'call unexpectedly returned ' || v_value);
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20088, 'V3 purchase of nutrition mutation is rejected', 'actual=' || v_error_code);
    end;
    select count(*) into v_value from labs where lab_id = v_lab_v3_id and wallet = v_before_wallet;
    assert_true(v_value = 1, 'Rejected nutrition purchase leaves wallet unchanged');
    select nvl(sum(quantity), 0)
      into v_value
      from lab_mutations
     where lab_id = v_lab_v3_id
       and mutation_id = v_nutrition_mutation_id;
    assert_true(v_value = v_before_mutation_quantity, 'Rejected nutrition purchase leaves inventory unchanged');
    select count(*) into v_value from genotypes where creature_id = v_creature_v3_id;
    assert_true(v_value = v_before_genotype_count, 'Rejected V3 mutation leaves genotype count unchanged');
    select count(*) into v_value from experiments where lab_id = v_lab_v3_id;
    assert_true(v_value = v_before_experiment_count, 'Rejected V3 mutation leaves history unchanged');
    select count(*) into v_value from genotypes where creature_id = v_creature_v3_id and gene_id = v_body_color_gene_id and allele1_id = v_before_allele1_id and allele2_id = v_before_allele2_id;
    assert_true(v_value = 1, 'Rejected V3 mutation leaves allele values unchanged');

    -- Chemical is deterministic, radiation exercises the random v3 candidate path 100 times.
    pkg_genetics_game.apply_mutagen(v_creature_v3_id, 'CHEMICAL', v_mutagen_child_id);
    select count(*) into v_value from genotypes child join genotypes source on source.creature_id = v_creature_v3_id and source.gene_id = child.gene_id join genes g on g.gene_id = child.gene_id where child.creature_id = v_mutagen_child_id and g.species_type = 0 and g.gene_type = 'morphology' and (child.allele1_id <> source.allele1_id or child.allele2_id <> source.allele2_id);
    assert_true(v_value > 0, 'V3 chemical mutagen changes canonical morphology', 'changed=' || v_value);

    for attempt_no in 1 .. 100 loop
        pkg_genetics_game.apply_mutagen(v_creature_v3_id, 'RADIATION', v_mutagen_child_id);
    end loop;

    select count(*)
      into v_value
      from experiments e
      join genotypes child on child.creature_id = e.offspring_id
      join genotypes source on source.creature_id = v_creature_v3_id and source.gene_id = child.gene_id
      join genes g on g.gene_id = child.gene_id
     where e.lab_id = v_lab_v3_id
       and e.experiment_type = 'MUTAGEN'
       and g.gameplay_enabled = 'Y'
       and (child.allele1_id <> source.allele1_id or child.allele2_id <> source.allele2_id);
    assert_true(v_value = 0, 'V3 mutagens never change legacy gameplay genes', 'changed=' || v_value);

    select count(*)
      into v_value
      from experiments e
      join genotypes child on child.creature_id = e.offspring_id
      join genotypes source on source.creature_id = v_creature_v3_id and source.gene_id = child.gene_id
      join genes g on g.gene_id = child.gene_id
     where e.lab_id = v_lab_v3_id
       and e.experiment_type = 'MUTAGEN'
       and (child.allele1_id <> source.allele1_id or child.allele2_id <> source.allele2_id)
       and not exists (
            select 1
              from ref_genetics_model_genes rmg
             where rmg.genetics_version = 3
               and rmg.gene_id = g.gene_id
       );
    assert_true(v_value = 0, 'Every changed V3 mutagen gene belongs to v3 membership', 'outside=' || v_value);

    select count(*)
      into v_value
      from experiments e
      join genotypes child on child.creature_id = e.offspring_id
      join genotypes source on source.creature_id = v_creature_v3_id and source.gene_id = child.gene_id
      join genes g on g.gene_id = child.gene_id
     where e.lab_id = v_lab_v3_id
       and e.experiment_type = 'MUTAGEN'
       and g.gene_name = 'nutrition_type'
       and (child.allele1_id <> source.allele1_id or child.allele2_id <> source.allele2_id);
    assert_true(v_value = 0, 'V3 mutagens exclude nutrition_type', 'changed=' || v_value);

    select count(*) into v_value from rating_events where lab_id = v_lab_v3_id and event_type = 'MUTAGEN_PENALTY' and description like 'Воздействие мутагена:%';
    assert_true(v_value = 101, 'V3 mutagen history uses Russian description', 'rows=' || v_value);

    select count(*) into v_value from user_objects where object_name = 'PKG_GENETICS_GAME' and object_type in ('PACKAGE', 'PACKAGE BODY') and status = 'VALID';
    assert_true(v_value = 2, 'Package specification and body remain valid', 'actual=' || v_value);
    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME';
    assert_true(v_value = 0, 'Package user_errors remain clean', 'actual=' || v_value);

    cleanup;
    select count(*) into v_value from labs;
    assert_true(v_value = v_baseline_labs, 'Cleanup restores LABS baseline', 'actual=' || v_value);
    select count(*) into v_value from creatures;
    assert_true(v_value = v_baseline_creatures, 'Cleanup restores CREATURES baseline', 'actual=' || v_value);
    select count(*) into v_value from genotypes;
    assert_true(v_value = v_baseline_genotypes, 'Cleanup restores GENOTYPES baseline', 'actual=' || v_value);
    select count(*) into v_value from lab_tasks;
    assert_true(v_value = v_baseline_lab_tasks, 'Cleanup restores LAB_TASKS baseline', 'actual=' || v_value);
    select count(*) into v_value from experiments;
    assert_true(v_value = v_baseline_experiments, 'Cleanup restores EXPERIMENTS baseline', 'actual=' || v_value);
    select count(*) into v_value from lab_mutations;
    assert_true(v_value = v_baseline_lab_mutations, 'Cleanup restores LAB_MUTATIONS baseline', 'actual=' || v_value);
    select count(*) into v_value from rating_events;
    assert_true(v_value = v_baseline_rating_events, 'Cleanup restores RATING_EVENTS baseline', 'actual=' || v_value);

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20999, 'Version-aware mutation smoke test failed.');
    end if;
exception
    when others then
        cleanup;
        raise;
end;
/
