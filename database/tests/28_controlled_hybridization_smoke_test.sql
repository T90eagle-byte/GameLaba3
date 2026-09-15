-- Controlled hybridization runtime smoke test.
-- All gameplay fixtures are isolated and removed before completion.

@@../migrations/13_add_controlled_hybridization.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests            number := 0;
    v_passed_tests            number := 0;
    v_value                   number;
    v_error_code              number;
    v_user_id                 number;
    v_lab_id                  number;
    v_other_lab_id            number;
    v_token                   varchar2(128);
    v_login                   varchar2(20) := 'h' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password                varchar2(100) := 'hybrid_task21_123';
    v_parent1_id              number;
    v_parent1_peer_id         number;
    v_parent2_id              number;
    v_other_lab_parent1_id    number;
    v_other_lab_parent2_id    number;
    v_hybrid_high_id          number;
    v_hybrid_low_id           number;
    v_trial_child_id          number;
    v_mutagen_clone_id        number;
    v_mutation_id             number;
    v_mutation_gene_id        number;
    v_mutation_allele_id      number;
    v_completed_fixture_tasks number;
    v_changed_genes           number;
    v_morphology_rows         number := 0;
    v_cursor                  sys_refcursor;
    v_cursor_gene_code        varchar2(100);
    v_cursor_gene_display     varchar2(4000);
    v_cursor_allele1          varchar2(4000);
    v_cursor_allele2          varchar2(4000);
    v_cursor_expressed        varchar2(4000);
    v_cursor_allele1_display  varchar2(4000);
    v_cursor_allele2_display  varchar2(4000);
    v_cursor_expressed_display varchar2(4000);
    v_baseline_labs           number;
    v_baseline_creatures      number;
    v_baseline_genotypes      number;
    v_baseline_lab_tasks      number;
    v_baseline_tasks          number;
    v_baseline_experiments    number;
    v_baseline_lab_mutations  number;
    v_baseline_rating_events  number;
    v_before_creatures        number;
    v_before_genotypes        number;
    v_before_experiments      number;
    v_before_lab_tasks        number;
    v_before_rating_events    number;

    procedure pass_test(p_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end pass_test;

    procedure fail_test(p_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(p_condition in boolean, p_name in varchar2, p_detail in varchar2 default null) is
    begin
        if p_condition then pass_test(p_name, p_detail); else fail_test(p_name, p_detail); end if;
    end assert_true;

    procedure expect_error(p_expected in number, p_name in varchar2, p_action in varchar2) is
    begin
        execute immediate p_action;
        fail_test(p_name, 'call unexpectedly succeeded');
    exception
        when others then
            assert_true(sqlcode = p_expected, p_name, 'actual=' || sqlcode);
    end expect_error;

    procedure load_primary_lab is
    begin
        pkg_genetics_game.load_lab(v_token, v_lab_id);
    end load_primary_lab;

    procedure snapshot_lab_counts is
    begin
        select count(*) into v_before_creatures from creatures where lab_id = v_lab_id;
        select count(*) into v_before_genotypes from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab_id);
        select count(*) into v_before_experiments from experiments where lab_id = v_lab_id;
        select count(*) into v_before_lab_tasks from lab_tasks where lab_id = v_lab_id;
        select count(*) into v_before_rating_events from rating_events where lab_id = v_lab_id;
    end snapshot_lab_counts;

    procedure cleanup is
    begin
        for lab_rec in (select lab_id from labs where user_id = v_user_id) loop
            delete from rating_events where lab_id = lab_rec.lab_id;
            delete from experiments where lab_id = lab_rec.lab_id;
            delete from lab_mutations where lab_id = lab_rec.lab_id;
            delete from lab_tasks where lab_id = lab_rec.lab_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = lab_rec.lab_id);
            delete from creatures where lab_id = lab_rec.lab_id;
            delete from labs where lab_id = lab_rec.lab_id;
        end loop;
        delete from task_markers where task_id in (select task_id from tasks where task_name like 'task28_hybrid_%');
        delete from tasks where task_name like 'task28_hybrid_%';
        if v_mutation_id is not null then
            delete from mutation_rules where mutation_id = v_mutation_id;
            delete from mutations where mutation_id = v_mutation_id;
        end if;
        delete from sessions where user_id = v_user_id or user_id in (select user_id from users where login = v_login);
        delete from users where user_id = v_user_id or login = v_login;
        commit;
    exception
        when others then
            rollback;
            raise;
    end cleanup;

begin
    select count(*) into v_baseline_labs from labs;
    select count(*) into v_baseline_creatures from creatures;
    select count(*) into v_baseline_genotypes from genotypes;
    select count(*) into v_baseline_lab_tasks from lab_tasks;
    select count(*) into v_baseline_tasks from tasks;
    select count(*) into v_baseline_experiments from experiments;
    select count(*) into v_baseline_lab_mutations from lab_mutations;
    select count(*) into v_baseline_rating_events from rating_events;

    select count(*) into v_value from ref_species_types where species_type = 7 and display_name = 'Гибрид';
    assert_true(v_value = 1, 'Hybrid species reference exists once');
    select count(*) into v_value from ref_experiment_types where experiment_type = 'HYBRIDIZATION';
    assert_true(v_value = 1, 'HYBRIDIZATION experiment type exists once');
    select count(*) into v_value from ref_rating_event_types where event_type = 'HYBRIDIZATION_PENALTY';
    assert_true(v_value = 1, 'Hybridization rating event type exists once');
    select count(*) into v_value from ref_experiment_economics where experiment_type = 'HYBRIDIZATION' and genetics_version = 3 and mutagen_type = 'RADIATION' and wallet_cost = 0 and rating_effect = -50 and active_flag = 'Y';
    assert_true(v_value = 1, 'Hybridization economics is configured as 0 / -50');

    pkg_genetics_game.register_user('Controlled hybrid fixture', v_login, v_password, v_user_id);
    v_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.start_new_lab(v_token, 'Task 28 hybrid lab', v_lab_id);
    update labs set wallet = 50000, rating = 100 where lab_id = v_lab_id;
    delete from lab_tasks where lab_id = v_lab_id;

    select min(creature_id) into v_parent1_id from creatures where lab_id = v_lab_id and species_type = 1;
    select max(creature_id) into v_parent1_peer_id from creatures where lab_id = v_lab_id and species_type = 1;
    select min(creature_id) into v_parent2_id from creatures where lab_id = v_lab_id and species_type = 2;

    -- Make both parents homozygous for the least-dominant allele of every canonical gene.
    -- One task per morphology gene then proves task evaluation sees the post-radiation state.
    for gene_rec in (
        select g.gene_id, g.gene_name, g.gene_type,
               min(a.allele_id) keep (dense_rank first order by a.dominance, a.allele_id) as base_allele_id
          from ref_genetics_model_genes rmg
          join genes g on g.gene_id = rmg.gene_id
          join alleles a on a.gene_id = g.gene_id
         where rmg.genetics_version = 3
         group by g.gene_id, g.gene_name, g.gene_type
         order by g.gene_id
    ) loop
        update genotypes set allele1_id = gene_rec.base_allele_id, allele2_id = gene_rec.base_allele_id
         where creature_id in (v_parent1_id, v_parent2_id) and gene_id = gene_rec.gene_id;
        assert_true(sql%rowcount = 2, 'Both parents contain canonical gene ' || gene_rec.gene_name);

        if gene_rec.gene_type = 'morphology' then
            select tasks_seq.nextval into v_value from dual;
            insert into tasks (task_id, task_name, description, rating_reward, money_reward, difficulty_code, genetics_version, created_at)
            values (v_value, 'task28_hybrid_' || gene_rec.gene_id, 'Final-state hybridization fixture.', 1, 1, 'EASY', 3, systimestamp);
            insert into task_markers (task_marker_id, task_id, allele_id)
            values (task_markers_seq.nextval, v_value, gene_rec.base_allele_id);
            insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
            values (lab_tasks_seq.nextval, v_lab_id, v_value, 'ACTIVE', systimestamp, null);
        end if;
    end loop;

    dbms_random.seed('task28-hybrid-high');
    snapshot_lab_counts;
    pkg_genetics_game.hybridize(v_lab_id, v_parent1_id, v_parent2_id, 'RADIATION', 'Task 28 hybrid high', v_hybrid_high_id);

    select count(*) into v_value from creatures where creature_id = v_hybrid_high_id and lab_id = v_lab_id and species_type = 7 and archetype_id is null;
    assert_true(v_value = 1, 'Valid input creates one hybrid with no archetype');
    select count(*) into v_value from creatures where lab_id = v_lab_id;
    assert_true(v_value = v_before_creatures + 1, 'Hybridization creates exactly one offspring');
    select count(*) into v_value from genotypes where creature_id = v_hybrid_high_id;
    assert_true(v_value = 19, 'Hybrid has exactly 19 genotype rows', 'actual=' || v_value);
    select count(*) into v_value from genotypes gt join ref_genetics_model_genes rmg on rmg.gene_id = gt.gene_id and rmg.genetics_version = 3 where gt.creature_id = v_hybrid_high_id;
    assert_true(v_value = 19, 'Hybrid genotype exactly matches v3 membership');
    select count(*) into v_value from genotypes gt join genes g on g.gene_id = gt.gene_id where gt.creature_id = v_hybrid_high_id and g.species_type = 0 and g.gene_type = 'morphology';
    assert_true(v_value = 18, 'Hybrid has all 18 morphology genes');
    select count(*) into v_value from genotypes gt join genes g on g.gene_id = gt.gene_id where gt.creature_id = v_hybrid_high_id and g.species_type = 0 and g.gene_name = 'nutrition_type';
    assert_true(v_value = 1, 'Hybrid has nutrition_type');
    select count(*) into v_value from genotypes gt join genes g on g.gene_id = gt.gene_id where gt.creature_id = v_hybrid_high_id and (g.gene_name in ('color', 'size', 'has_wings') or g.species_type between 1 and 6);
    assert_true(v_value = 0, 'Hybrid has no legacy or species-specific genes');

    select count(*) into v_changed_genes
      from genotypes child
      join genotypes p1 on p1.creature_id = v_parent1_id and p1.gene_id = child.gene_id
     where child.creature_id = v_hybrid_high_id
       and (child.allele1_id <> p1.allele1_id or child.allele2_id <> p1.allele2_id);
    assert_true(v_changed_genes between 1 and 2, 'Radiation changes one or two canonical genes', 'changed=' || v_changed_genes);
    select count(*) into v_value
      from genotypes child
      join genes g on g.gene_id = child.gene_id
      join genotypes p1 on p1.creature_id = v_parent1_id and p1.gene_id = child.gene_id
     where child.creature_id = v_hybrid_high_id
       and (child.allele1_id <> p1.allele1_id or child.allele2_id <> p1.allele2_id)
       and not (g.species_type = 0 and g.gene_type = 'morphology' and g.gene_name <> 'nutrition_type');
    assert_true(v_value = 0, 'Radiation changes only allowed morphology genes');
    select count(*) into v_value
      from genotypes child
      join genes g on g.gene_id = child.gene_id
      join genotypes p1 on p1.creature_id = v_parent1_id and p1.gene_id = child.gene_id
     where child.creature_id = v_hybrid_high_id
       and g.gene_name = 'nutrition_type'
       and child.allele1_id = p1.allele1_id
       and child.allele2_id = p1.allele2_id;
    assert_true(v_value = 1, 'Nutrition inheritance is preserved and not mutated');
    assert_true(19 - v_changed_genes >= 17, 'Unchanged genes retain parent alleles');

    select count(*) into v_value from experiments where lab_id = v_lab_id and offspring_id = v_hybrid_high_id and experiment_type = 'HYBRIDIZATION' and parent1_id = v_parent1_id and parent2_id = v_parent2_id and mutagen_type = 'RADIATION' and mutation_id is null;
    assert_true(v_value = 1, 'One HYBRIDIZATION history row contains both parents and radiation');
    select count(*) into v_value from experiments where lab_id = v_lab_id and offspring_id = v_hybrid_high_id and experiment_type in ('CROSS', 'MUTAGEN', 'CROSSBREED_MUTAGEN');
    assert_true(v_value = 0, 'Hybridization creates no auxiliary experiment rows');

    select count(*) into v_completed_fixture_tasks from lab_tasks lt join tasks t on t.task_id = lt.task_id where lt.lab_id = v_lab_id and t.task_name like 'task28_hybrid_%' and lt.task_status = 'COMPLETED';
    assert_true(v_completed_fixture_tasks between 16 and 17, 'Tasks are evaluated after radiation, not before it', 'completed=' || v_completed_fixture_tasks);
    select count(*) into v_value from rating_events re join tasks t on t.task_id = re.task_id where re.lab_id = v_lab_id and re.creature_id = v_hybrid_high_id and re.event_type = 'TASK_REWARD' and t.task_name like 'task28_hybrid_%';
    assert_true(v_value = v_completed_fixture_tasks, 'Task rewards remain distinct and traceable');
    select count(*) into v_value from rating_events where lab_id = v_lab_id and creature_id = v_hybrid_high_id and event_type = 'HYBRIDIZATION_PENALTY' and rating_delta = -50 and wallet_delta = 0;
    assert_true(v_value = 1, 'High rating receives one actual -50 hybridization penalty');
    select rating into v_value from labs where lab_id = v_lab_id;
    assert_true(v_value = 100 + v_completed_fixture_tasks - 50, 'No hidden standalone radiation -5 penalty', 'rating=' || v_value);

    delete from lab_tasks where lab_id = v_lab_id;
    update labs set rating = 20 where lab_id = v_lab_id;
    dbms_random.seed('task28-hybrid-low');
    pkg_genetics_game.hybridize(v_lab_id, v_parent1_id, v_parent2_id, 'RADIATION', 'Task 28 hybrid low', v_hybrid_low_id);
    select rating into v_value from labs where lab_id = v_lab_id;
    assert_true(v_value = 0, 'Low rating clamps to zero');
    select count(*) into v_value from rating_events where lab_id = v_lab_id and creature_id = v_hybrid_low_id and event_type = 'HYBRIDIZATION_PENALTY' and rating_delta = -20;
    assert_true(v_value = 1, 'Clamped penalty event stores actual -20 delta');

    v_cursor := pkg_genetics_game.get_morphology_cursor(v_hybrid_high_id);
    loop
        fetch v_cursor into v_cursor_gene_code, v_cursor_gene_display, v_cursor_allele1, v_cursor_allele2,
            v_cursor_expressed, v_cursor_allele1_display, v_cursor_allele2_display, v_cursor_expressed_display;
        exit when v_cursor%notfound;
        v_morphology_rows := v_morphology_rows + 1;
    end loop;
    close v_cursor;
    assert_true(v_morphology_rows = 18, 'Hybrid morphology cursor returns exactly 18 rows');

    select g.gene_id
      into v_mutation_gene_id
      from genes g
     where g.gene_name = 'body_color'
       and g.species_type = 0;
    select min(a.allele_id)
      into v_mutation_allele_id
      from alleles a
     where a.gene_id = v_mutation_gene_id
       and a.allele_id not in (
            select gt.allele1_id from genotypes gt where gt.creature_id = v_hybrid_high_id and gt.gene_id = v_mutation_gene_id
            union
            select gt.allele2_id from genotypes gt where gt.creature_id = v_hybrid_high_id and gt.gene_id = v_mutation_gene_id
       );
    select mutations_seq.nextval into v_mutation_id from dual;
    insert into mutations (mutation_id, mutation_name, mutation_type, description, cost, rating_effect, created_at)
    values (v_mutation_id, 'task28_hybrid_mutation', null, 'Тестовая мутация гибрида.', 0, 0, systimestamp);
    insert into mutation_rules (mutation_rule_id, mutation_id, gene_id, target_allele_id, target_slot, created_at)
    values (mutation_rules_seq.nextval, v_mutation_id, v_mutation_gene_id, v_mutation_allele_id, '1', systimestamp);
    update labs set wallet = 50000 where lab_id = v_lab_id;
    assert_true(pkg_genetics_game.buy_mutation(v_lab_id, v_mutation_id) = 1, 'Hybrid-compatible v3 mutation can be purchased');
    pkg_genetics_game.apply_mutation(v_hybrid_high_id, v_mutation_id);
    select count(*) into v_value from experiments where lab_id = v_lab_id and parent1_id = v_hybrid_high_id and experiment_type = 'MUTATION';
    assert_true(v_value = 1, 'V3 mutation of hybrid succeeds');
    pkg_genetics_game.apply_mutagen(v_hybrid_high_id, 'CHEMICAL', v_mutagen_clone_id);
    select count(*) into v_value from creatures where creature_id = v_mutagen_clone_id and species_type = 7 and archetype_id is null;
    assert_true(v_value = 1, 'V3 mutagen clone of hybrid remains a hybrid');
    select count(*) into v_value from genotypes where creature_id = v_mutagen_clone_id;
    assert_true(v_value = 19, 'Mutagen clone preserves the canonical 19-gene hybrid genotype');

    pkg_genetics_game.crossbreed(v_lab_id, v_parent1_id, v_parent1_peer_id, 'Task 28 ordinary child', v_trial_child_id);
    assert_true(v_trial_child_id is not null, 'Ordinary same-species crossbreed still works');

    begin
        pkg_genetics_game.crossbreed(v_lab_id, v_parent1_id, v_parent2_id, 'Task 28 mixed ordinary', v_trial_child_id);
        fail_test('Ordinary different-species crossbreed is rejected');
    exception when others then assert_true(sqlcode = -20036, 'Ordinary different-species crossbreed is rejected', 'actual=' || sqlcode); end;
    begin
        pkg_genetics_game.crossbreed(v_lab_id, v_hybrid_high_id, v_hybrid_low_id, 'Task 28 hybrid pair', v_trial_child_id);
        fail_test('Hybrid by hybrid ordinary crossbreed is rejected');
    exception when others then assert_true(sqlcode = -20091, 'Hybrid by hybrid ordinary crossbreed is rejected', 'actual=' || sqlcode); end;
    begin
        pkg_genetics_game.crossbreed(v_lab_id, v_hybrid_high_id, v_parent1_id, 'Task 28 hybrid normal', v_trial_child_id);
        fail_test('Hybrid by normal ordinary crossbreed is rejected');
    exception when others then assert_true(sqlcode = -20091, 'Hybrid by normal ordinary crossbreed is rejected', 'actual=' || sqlcode); end;
    begin
        pkg_genetics_game.crossbreed(v_lab_id, v_parent1_id, v_hybrid_high_id, 'Task 28 normal hybrid', v_trial_child_id);
        fail_test('Normal by hybrid ordinary crossbreed is rejected');
    exception when others then assert_true(sqlcode = -20091, 'Normal by hybrid ordinary crossbreed is rejected', 'actual=' || sqlcode); end;
    begin
        pkg_genetics_game.make_experiment(v_lab_id, v_hybrid_high_id, v_hybrid_low_id, 'RADIATION', 'Task 28 combined hybrid', v_trial_child_id);
        fail_test('Combined experiment rejects hybrid parents');
    exception when others then assert_true(sqlcode = -20091, 'Combined experiment rejects hybrid parents', 'actual=' || sqlcode); end;
    begin
        pkg_genetics_game.hybridize(v_lab_id, v_parent1_id, v_parent1_peer_id, 'RADIATION', 'Task 28 same species', v_trial_child_id);
        fail_test('Hybridization rejects same-species parents');
    exception when others then assert_true(sqlcode = -20093, 'Hybridization rejects same-species parents', 'actual=' || sqlcode); end;
    begin
        pkg_genetics_game.hybridize(v_lab_id, v_hybrid_high_id, v_parent2_id, 'RADIATION', 'Task 28 hybrid parent', v_trial_child_id);
        fail_test('Hybridization rejects hybrid parent');
    exception when others then assert_true(sqlcode = -20091, 'Hybridization rejects hybrid parent', 'actual=' || sqlcode); end;
    begin
        pkg_genetics_game.hybridize(v_lab_id, v_parent1_id, v_parent2_id, 'CHEMICAL', 'Task 28 chemical', v_trial_child_id);
        fail_test('Hybridization rejects CHEMICAL');
    exception when others then assert_true(sqlcode = -20094, 'Hybridization rejects CHEMICAL', 'actual=' || sqlcode); end;
    begin
        pkg_genetics_game.hybridize(v_lab_id, v_parent1_id, v_parent2_id, 'UNKNOWN', 'Task 28 unknown', v_trial_child_id);
        fail_test('Hybridization rejects unknown mutagen');
    exception when others then assert_true(sqlcode = -20094, 'Hybridization rejects unknown mutagen', 'actual=' || sqlcode); end;

    pkg_genetics_game.start_new_lab(v_token, 'Task 28 other lab', v_other_lab_id);
    select min(creature_id) into v_other_lab_parent1_id from creatures where lab_id = v_other_lab_id and species_type = 1;
    select min(creature_id) into v_other_lab_parent2_id from creatures where lab_id = v_other_lab_id and species_type = 2;
    update labs set genetics_version = 1 where lab_id = v_other_lab_id;
    begin
        pkg_genetics_game.hybridize(v_other_lab_id, v_other_lab_parent1_id, v_other_lab_parent2_id, 'RADIATION', 'Task 28 legacy', v_trial_child_id);
        fail_test('V1 laboratory rejects hybridization');
    exception when others then assert_true(sqlcode = -20092, 'V1 laboratory rejects hybridization', 'actual=' || sqlcode); end;
    load_primary_lab;
    begin
        pkg_genetics_game.hybridize(v_lab_id, v_parent1_id, v_other_lab_parent2_id, 'RADIATION', 'Task 28 foreign parent', v_trial_child_id);
        fail_test('Foreign-lab parent is rejected');
    exception when others then assert_true(sqlcode = -20073, 'Foreign-lab parent is rejected', 'actual=' || sqlcode); end;

    insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
    select lab_tasks_seq.nextval, v_lab_id, t.task_id, 'ACTIVE', systimestamp, null
      from tasks t
     where t.task_name like 'task28_hybrid_%';
    update labs set wallet = 9999999999.99 where lab_id = v_lab_id;
    snapshot_lab_counts;
    begin
        pkg_genetics_game.hybridize(v_lab_id, v_parent1_id, v_parent2_id, 'RADIATION', 'Task 28 rollback', v_trial_child_id);
        fail_test('Forced late failure propagates');
    exception when others then assert_true(sqlcode = -1438, 'Forced late failure propagates', 'actual=' || sqlcode); end;
    select count(*) into v_value from creatures where lab_id = v_lab_id;
    assert_true(v_value = v_before_creatures, 'Late failure leaves no offspring residue');
    select count(*) into v_value from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab_id);
    assert_true(v_value = v_before_genotypes, 'Late failure leaves no genotype residue');
    select count(*) into v_value from experiments where lab_id = v_lab_id;
    assert_true(v_value = v_before_experiments, 'Late failure leaves no experiment residue');
    select count(*) into v_value from lab_tasks where lab_id = v_lab_id;
    assert_true(v_value = v_before_lab_tasks, 'Late failure leaves no task residue');
    select count(*) into v_value from rating_events where lab_id = v_lab_id;
    assert_true(v_value = v_before_rating_events, 'Late failure leaves no rating event residue');

    select count(*) into v_value from user_objects where object_name = 'PKG_GENETICS_GAME' and object_type in ('PACKAGE', 'PACKAGE BODY') and status = 'VALID';
    assert_true(v_value = 2, 'Package specification and body remain VALID');
    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME';
    assert_true(v_value = 0, 'Package USER_ERRORS remains clean');

    cleanup;
    select count(*) into v_value from labs; assert_true(v_value = v_baseline_labs, 'Cleanup restores LABS baseline');
    select count(*) into v_value from creatures; assert_true(v_value = v_baseline_creatures, 'Cleanup restores CREATURES baseline');
    select count(*) into v_value from genotypes; assert_true(v_value = v_baseline_genotypes, 'Cleanup restores GENOTYPES baseline');
    select count(*) into v_value from lab_tasks; assert_true(v_value = v_baseline_lab_tasks, 'Cleanup restores LAB_TASKS baseline');
    select count(*) into v_value from tasks; assert_true(v_value = v_baseline_tasks, 'Cleanup restores TASKS baseline');
    select count(*) into v_value from experiments; assert_true(v_value = v_baseline_experiments, 'Cleanup restores EXPERIMENTS baseline');
    select count(*) into v_value from lab_mutations; assert_true(v_value = v_baseline_lab_mutations, 'Cleanup restores LAB_MUTATIONS baseline');
    select count(*) into v_value from rating_events; assert_true(v_value = v_baseline_rating_events, 'Cleanup restores RATING_EVENTS baseline');

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then raise_application_error(-20999, 'Controlled hybridization smoke test failed.'); end if;
exception
    when others then
        cleanup;
        raise;
end;
/
