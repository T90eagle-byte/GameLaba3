-- Приёмочная проверка полного цикла v3 с подключением к Oracle. Все тестовые данные удаляются полностью.

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests              number := 0;
    v_passed_tests              number := 0;
    v_value                     number;
    v_error_code                number;
    v_user_id                   number;
    v_lab_id                    number;
    v_token                     varchar2(128);
    v_login                     varchar2(30) := 'e2e_' || lower(substr(rawtohex(sys_guid()), 1, 16));
    v_password                  varchar2(100) := 'acceptance_v3_123';
    v_parent1_id                number;
    v_parent2_id                number;
    v_other_species_id          number;
    v_cross_child_id            number;
    v_mutagen_child_id          number;
    v_combined_child_id         number;
    v_hybrid_id                 number;
    v_task_id                   number;
    v_mutation_id               number;
    v_body_color_gene_id        number;
    v_target_allele_id          number;
    v_legacy_signature_before   varchar2(4000);
    v_legacy_signature_after    varchar2(4000);
    v_rating_before_hybrid      number;
    v_rating_after_hybrid       number;
    v_wallet_before_task        number;
    v_wallet_after_task         number;
    v_rating_before_task        number;
    v_rating_after_task         number;
    v_completed                 number;
    v_unused_wallet             number;
    v_unused_rating             number;
    v_morphology_cursor         sys_refcursor;
    v_gene_code                 varchar2(100);
    v_gene_display_name         varchar2(255);
    v_allele1_code              varchar2(255);
    v_allele2_code              varchar2(255);
    v_expressed_code            varchar2(4000);
    v_allele1_display_name      varchar2(255);
    v_allele2_display_name      varchar2(255);
    v_expressed_display_name    varchar2(4000);
    v_morphology_rows           number := 0;

    v_baseline_labs             number;
    v_baseline_creatures        number;
    v_baseline_genotypes        number;
    v_baseline_lab_tasks        number;
    v_baseline_tasks            number;
    v_baseline_experiments      number;
    v_baseline_lab_mutations    number;
    v_baseline_rating_events    number;

    procedure pass_test(p_name in varchar2) is
    begin
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_name);
    end pass_test;

    procedure fail_test(p_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end fail_test;

    procedure assert_true(p_condition in boolean, p_name in varchar2, p_detail in varchar2 default null) is
    begin
        if p_condition then
            pass_test(p_name);
        else
            fail_test(p_name, p_detail);
        end if;
    end assert_true;

    procedure snapshot_baseline is
    begin
        select count(*) into v_baseline_labs from labs;
        select count(*) into v_baseline_creatures from creatures;
        select count(*) into v_baseline_genotypes from genotypes;
        select count(*) into v_baseline_lab_tasks from lab_tasks;
        select count(*) into v_baseline_tasks from tasks;
        select count(*) into v_baseline_experiments from experiments;
        select count(*) into v_baseline_lab_mutations from lab_mutations;
        select count(*) into v_baseline_rating_events from rating_events;
    end snapshot_baseline;

    procedure cleanup is
    begin
        if v_lab_id is not null then
            delete from rating_events where lab_id = v_lab_id;
            delete from experiments where lab_id = v_lab_id;
            delete from lab_mutations where lab_id = v_lab_id;
            delete from lab_tasks where lab_id = v_lab_id;
            delete from genotypes where creature_id in (select creature_id from creatures where lab_id = v_lab_id);
            delete from creatures where lab_id = v_lab_id;
            delete from labs where lab_id = v_lab_id;
        end if;

        if v_mutation_id is not null then
            delete from mutation_rules where mutation_id = v_mutation_id;
            delete from mutations where mutation_id = v_mutation_id;
        end if;

        begin
            if v_token is not null then
                pkg_genetics_game.logout_user(v_token);
            end if;
        exception
            when others then null;
        end;

        if v_user_id is not null then
            delete from sessions where user_id = v_user_id;
            delete from users where user_id = v_user_id;
        else
            delete from sessions where user_id in (select user_id from users where login = v_login);
            delete from users where login = v_login;
        end if;
    end cleanup;
begin
    snapshot_baseline;
    dbms_output.put_line('--- V3 END-TO-END ACCEPTANCE TEST ---');

    pkg_genetics_game.register_user('V3 acceptance fixture', v_login, v_password, v_user_id);
    v_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.start_new_lab(v_token, 'Временная лаборатория v3 acceptance', v_lab_id);

    select genetics_version into v_value from labs where lab_id = v_lab_id;
    assert_true(v_value = 3, 'v3 laboratory is created');
    select count(*) into v_value from creatures where lab_id = v_lab_id;
    assert_true(v_value = 30, 'v3 starters are generated', 'actual=' || v_value);
    select count(*) into v_value from creatures where lab_id = v_lab_id and archetype_id is not null;
    assert_true(v_value = 30, 'v3 starters have archetypes', 'actual=' || v_value);
    select count(*) into v_value
      from (
            select c.creature_id
              from creatures c
              left join genotypes gt on gt.creature_id = c.creature_id
              left join genes g on g.gene_id = gt.gene_id
             where c.lab_id = v_lab_id
             group by c.creature_id
            having count(case when g.species_type = 0 and g.gene_type = 'morphology' then 1 end) <> 18
           );
    assert_true(v_value = 0, 'v3 starters have complete morphology', 'mismatches=' || v_value);
    select count(*) into v_value
      from lab_tasks lt
      join tasks t on t.task_id = lt.task_id
     where lt.lab_id = v_lab_id
       and lt.task_status = 'ACTIVE'
       and t.genetics_version = 3;
    assert_true(v_value = 3, 'active v3 tasks are assigned', 'actual=' || v_value);

    select min(species_type) into v_value from (select species_type from creatures where lab_id = v_lab_id group by species_type having count(*) >= 2);
    select min(creature_id), max(creature_id)
      into v_parent1_id, v_parent2_id
      from creatures
     where lab_id = v_lab_id
       and species_type = v_value;
    select min(creature_id) into v_other_species_id from creatures where lab_id = v_lab_id and species_type <> v_value;

    pkg_genetics_game.crossbreed(v_lab_id, v_parent1_id, v_parent2_id, 'Acceptance cross', v_cross_child_id);
    select count(*) into v_value from experiments where lab_id = v_lab_id and offspring_id = v_cross_child_id and experiment_type = 'CROSS';
    assert_true(v_value = 1, 'CROSS creates one history row');
    select count(*) into v_value
      from genotypes gt
      join ref_genetics_model_genes rmg
        on rmg.genetics_version = 3
       and rmg.gene_id = gt.gene_id
     where gt.creature_id = v_cross_child_id;
    assert_true(v_value = 19, 'crossbred v3 offspring has 19 canonical genes', 'actual=' || v_value);
    select count(*) into v_value from genotypes gt join genes g on g.gene_id = gt.gene_id where gt.creature_id = v_cross_child_id and g.species_type = 0 and g.gene_type = 'morphology';
    assert_true(v_value = 18, 'crossbred offspring keeps morphology', 'actual=' || v_value);

    select g.gene_id into v_body_color_gene_id from genes g where g.gene_name = 'body_color' and g.species_type = 0;
    select min(a.allele_id)
      into v_target_allele_id
      from alleles a
     where a.gene_id = v_body_color_gene_id
       and a.allele_id not in (
            select gt.allele1_id from genotypes gt where gt.creature_id = v_cross_child_id and gt.gene_id = v_body_color_gene_id
            union
            select gt.allele2_id from genotypes gt where gt.creature_id = v_cross_child_id and gt.gene_id = v_body_color_gene_id
       );
    select mutations_seq.nextval into v_mutation_id from dual;
    insert into mutations (mutation_id, mutation_name, mutation_type, description, cost, rating_effect, created_at)
    values (v_mutation_id, 'acceptance_v3_color_' || lower(substr(rawtohex(sys_guid()), 1, 12)), null, 'Temporary acceptance mutation.', 0, 0, systimestamp);
    insert into mutation_rules (mutation_rule_id, mutation_id, gene_id, target_allele_id, target_slot, created_at)
    values (mutation_rules_seq.nextval, v_mutation_id, v_body_color_gene_id, v_target_allele_id, '1', systimestamp);
    assert_true(pkg_genetics_game.mutation_rules_match_genetics_version(v_mutation_id, 3) = 1, 'v3 mutation fixture targets allowed morphology');
    assert_true(pkg_genetics_game.buy_mutation(v_lab_id, v_mutation_id) = 1, 'v3 mutation is purchased');
    select nvl(listagg(gt.gene_id || ':' || gt.allele1_id || ':' || gt.allele2_id, '|') within group (order by gt.gene_id), 'none')
      into v_legacy_signature_before
      from genotypes gt
     where gt.creature_id = v_cross_child_id
       and not exists (
            select 1
              from ref_genetics_model_genes rmg
             where rmg.genetics_version = 3
               and rmg.gene_id = gt.gene_id
       );
    pkg_genetics_game.apply_mutation(v_cross_child_id, v_mutation_id);
    select count(*) into v_value from experiments where lab_id = v_lab_id and parent1_id = v_cross_child_id and mutation_id = v_mutation_id and experiment_type = 'MUTATION';
    assert_true(v_value = 1, 'v3 mutation is recorded');
    select nvl(listagg(gt.gene_id || ':' || gt.allele1_id || ':' || gt.allele2_id, '|') within group (order by gt.gene_id), 'none')
      into v_legacy_signature_after
      from genotypes gt
     where gt.creature_id = v_cross_child_id
       and not exists (
            select 1
              from ref_genetics_model_genes rmg
             where rmg.genetics_version = 3
               and rmg.gene_id = gt.gene_id
       );
    assert_true(v_legacy_signature_after = v_legacy_signature_before, 'v3 mutation leaves legacy genes unchanged');

    pkg_genetics_game.apply_mutagen(v_cross_child_id, 'CHEMICAL', v_mutagen_child_id);
    select count(*) into v_value from experiments where lab_id = v_lab_id and offspring_id = v_mutagen_child_id and experiment_type = 'MUTAGEN' and mutagen_type = 'CHEMICAL';
    assert_true(v_value = 1, 'v3 mutagen succeeds and is recorded');
    select count(*) into v_value
      from genotypes gt
      join ref_genetics_model_genes rmg
        on rmg.genetics_version = 3
       and rmg.gene_id = gt.gene_id
     where gt.creature_id = v_mutagen_child_id;
    assert_true(v_value = 19, 'v3 mutagen child keeps canonical genes', 'actual=' || v_value);

    pkg_genetics_game.make_experiment(v_lab_id, v_parent1_id, v_parent2_id, 'RADIATION', 'Acceptance combined', v_combined_child_id);
    select count(*) into v_value from experiments where lab_id = v_lab_id and offspring_id = v_combined_child_id and experiment_type = 'CROSSBREED_MUTAGEN' and mutagen_type = 'RADIATION';
    assert_true(v_value = 1, 'combined experiment has one logical history row');
    select count(*) into v_value from experiments where lab_id = v_lab_id and offspring_id = v_combined_child_id and experiment_type in ('CROSS', 'MUTAGEN');
    assert_true(v_value = 0, 'combined experiment has no intermediate history');

    update labs set rating = 100 where lab_id = v_lab_id;
    select rating into v_rating_before_hybrid from labs where lab_id = v_lab_id;
    pkg_genetics_game.hybridize(v_lab_id, v_parent1_id, v_other_species_id, 'RADIATION', 'Acceptance hybrid', v_hybrid_id);
    select rating into v_rating_after_hybrid from labs where lab_id = v_lab_id;
    select count(*) into v_value from creatures where creature_id = v_hybrid_id and species_type = 7 and archetype_id is null;
    assert_true(v_value = 1, 'hybrid has species=7 and NULL archetype');
    select count(*) into v_value from genotypes gt join ref_genetics_model_genes rmg on rmg.genetics_version = 3 and rmg.gene_id = gt.gene_id where gt.creature_id = v_hybrid_id;
    assert_true(v_value = 19, 'hybrid has exactly 19 canonical genes', 'actual=' || v_value);
    select count(*) into v_value from experiments where lab_id = v_lab_id and offspring_id = v_hybrid_id and experiment_type = 'HYBRIDIZATION' and mutagen_type = 'RADIATION';
    assert_true(v_value = 1, 'hybridization has one history row');
    assert_true(v_rating_after_hybrid = v_rating_before_hybrid - 50, 'configured hybridization penalty is applied');

    v_morphology_cursor := pkg_genetics_game.get_morphology_cursor(v_hybrid_id);
    loop
        fetch v_morphology_cursor into v_gene_code, v_gene_display_name, v_allele1_code, v_allele2_code, v_expressed_code, v_allele1_display_name, v_allele2_display_name, v_expressed_display_name;
        exit when v_morphology_cursor%notfound;
        v_morphology_rows := v_morphology_rows + 1;
    end loop;
    close v_morphology_cursor;
    assert_true(v_morphology_rows = 18, 'hybrid morphology cursor returns 18 rows', 'actual=' || v_morphology_rows);

    assert_true(pkg_genetics_game.buy_mutation(v_lab_id, v_mutation_id) = 1, 'v3 mutation can be repurchased for hybrid');
    pkg_genetics_game.apply_mutation(v_hybrid_id, v_mutation_id);
    select count(*) into v_value from experiments where lab_id = v_lab_id and parent1_id = v_hybrid_id and mutation_id = v_mutation_id and experiment_type = 'MUTATION';
    assert_true(v_value = 1, 'v3 mutation works for hybrid');
    begin
        pkg_genetics_game.crossbreed(v_lab_id, v_hybrid_id, v_parent1_id, 'Rejected hybrid parent', v_value);
        fail_test('hybrid breeding is rejected', 'call unexpectedly succeeded');
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20091, 'hybrid breeding is rejected', 'actual=' || v_error_code);
    end;

    select min(task_id) into v_task_id from lab_tasks where lab_id = v_lab_id and task_status = 'ACTIVE';
    for marker in (
        select a.gene_id, tm.allele_id
          from task_markers tm
          join alleles a on a.allele_id = tm.allele_id
         where tm.task_id = v_task_id
    ) loop
        update genotypes
           set allele1_id = marker.allele_id,
               allele2_id = marker.allele_id
         where creature_id = v_parent1_id
           and gene_id = marker.gene_id;
    end loop;
    select wallet, rating into v_wallet_before_task, v_rating_before_task from labs where lab_id = v_lab_id;
    v_completed := pkg_genetics_game.check_task(v_lab_id, v_task_id, v_parent1_id);
    assert_true(v_completed = 1, 'controlled v3 task is expressed by fixture creature');
    pkg_genetics_game.complete_task(v_lab_id, v_task_id, v_parent1_id, v_completed, v_unused_wallet, v_unused_rating);
    select wallet, rating into v_wallet_after_task, v_rating_after_task from labs where lab_id = v_lab_id;
    assert_true(v_wallet_after_task > v_wallet_before_task and v_rating_after_task > v_rating_before_task, 'v3 task reward changes economy');
    select count(*) into v_value from rating_events where lab_id = v_lab_id and task_id = v_task_id and event_type = 'TASK_REWARD';
    assert_true(v_value = 1, 'v3 task reward is recorded once');

    select count(*) into v_value from user_objects where object_name = 'PKG_GENETICS_GAME' and object_type in ('PACKAGE', 'PACKAGE BODY') and status = 'VALID';
    assert_true(v_value = 2, 'PACKAGE and PACKAGE BODY are VALID');
    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME' and type in ('PACKAGE', 'PACKAGE BODY');
    assert_true(v_value = 0, 'PKG_GENETICS_GAME USER_ERRORS are clean');

    cleanup;
    commit;
    select count(*) into v_value from labs;
    assert_true(v_value = v_baseline_labs, 'cleanup restores LABS baseline', 'actual=' || v_value);
    select count(*) into v_value from creatures;
    assert_true(v_value = v_baseline_creatures, 'cleanup restores CREATURES baseline', 'actual=' || v_value);
    select count(*) into v_value from genotypes;
    assert_true(v_value = v_baseline_genotypes, 'cleanup restores GENOTYPES baseline', 'actual=' || v_value);
    select count(*) into v_value from lab_tasks;
    assert_true(v_value = v_baseline_lab_tasks, 'cleanup restores LAB_TASKS baseline', 'actual=' || v_value);
    select count(*) into v_value from tasks;
    assert_true(v_value = v_baseline_tasks, 'cleanup restores TASKS baseline', 'actual=' || v_value);
    select count(*) into v_value from experiments;
    assert_true(v_value = v_baseline_experiments, 'cleanup restores EXPERIMENTS baseline', 'actual=' || v_value);
    select count(*) into v_value from lab_mutations;
    assert_true(v_value = v_baseline_lab_mutations, 'cleanup restores LAB_MUTATIONS baseline', 'actual=' || v_value);
    select count(*) into v_value from rating_events;
    assert_true(v_value = v_baseline_rating_events, 'cleanup restores RATING_EVENTS baseline', 'actual=' || v_value);

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20999, 'V3 end-to-end acceptance smoke test failed.');
    end if;
exception
    when others then
        dbms_output.put_line('[ERROR] ' || sqlcode || ' / ' || sqlerrm);
        begin
            cleanup;
            commit;
        exception
            when others then null;
        end;
        raise;
end;
/
