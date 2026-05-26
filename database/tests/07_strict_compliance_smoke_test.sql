set serveroutput on size unlimited;
set verify off;

declare
    v_user1_id                      number;
    v_user2_id                      number;
    v_lab1_id                       number;
    v_lab2_id                       number;
    v_login1                        varchar2(20);
    v_login2                        varchar2(20);
    v_username1                     varchar2(255);
    v_username2                     varchar2(255);
    v_password1                     varchar2(100) := 'strict_user1_123';
    v_password2                     varchar2(100) := 'strict_user2_123';
    v_session1_token                varchar2(128);
    v_session1_token_relogin        varchar2(128);
    v_session2_token                varchar2(128);

    v_wallet                        number;
    v_rating                        number;
    v_creature_count                number;
    v_active_task_count             number;
    v_completed_task_count          number;
    v_experiment_count              number;

    v_lab1_creature_id              number;
    v_lab2_creature_id              number;

    v_rc                            sys_refcursor;
    v_dummy_num                     number;

    v_suffix                        varchar2(16);
    v_inc_gene_id                   number;
    v_inc_a_low_id                  number;
    v_inc_a_mid_id                  number;
    v_inc_a_high_id                 number;
    v_codom_gene_id                 number;
    v_codom_a_id                    number;
    v_codom_b_id                    number;
    v_summary                       varchar2(1000);

    v_mut_chemical_creature_id      number;
    v_mut_radiation_creature_id     number;
    v_diff_chemical                 number;
    v_diff_radiation                number;

    v_mutation_id                   number;
    v_target_creature_id            number;
    v_marker_allele_id              number;
    v_buy_result                    number;
    v_wallet_before_auto            number;
    v_rating_before_auto            number;
    v_wallet_after_buy              number;
    v_rating_after_buy              number;
    v_wallet_after_auto             number;
    v_rating_after_auto             number;

    v_custom_task_id                number;
    v_custom_lab_task_id            number;
    v_custom_status                 varchar2(20);

    v_tasks_pool_count              number;
    v_assigned_before_auto          number;
    v_assigned_after_auto           number;
    v_active_before_auto            number;
    v_active_after_auto             number;
    v_distinct_assigned_after_auto  number;

    v_failed_tests                  number := 0;
    v_passed_tests                  number := 0;

    v_unhandled_sqlcode             number;
    v_unhandled_sqlerrm             varchar2(4000);

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

    procedure cleanup_test_data is
        procedure cleanup_lab_via_package(
            p_label         in varchar2,
            p_session_token in varchar2,
            p_lab_id        in number
        ) is
        begin
            if p_session_token is null or p_lab_id is null then
                return;
            end if;

            begin
                pkg_genetics_game.delete_lab(
                    p_session_token => p_session_token,
                    p_lab_id        => p_lab_id
                );
                dbms_output.put_line('[INFO] cleanup delete ' || p_label || ' via package done');
            exception
                when others then
                    if sqlcode in (-20020, -20021) then
                        dbms_output.put_line('[INFO] cleanup delete ' || p_label || ' via package skipped: ' || sqlcode || ' / ' || sqlerrm);
                    else
                        dbms_output.put_line('[WARN] cleanup delete ' || p_label || ' via package: ' || sqlcode || ' / ' || sqlerrm);
                    end if;
            end;
        end cleanup_lab_via_package;

        procedure cleanup_lab_direct(
            p_label  in varchar2,
            p_lab_id in number
        ) is
        begin
            if p_lab_id is null then
                return;
            end if;

            begin
                delete from lab_tasks lt
                 where lt.lab_id = p_lab_id;

                delete from lab_mutations lm
                 where lm.lab_id = p_lab_id;

                delete from experiments e
                 where e.lab_id = p_lab_id;

                delete from genotypes g
                 where g.creature_id in (
                        select c.creature_id
                          from creatures c
                         where c.lab_id = p_lab_id
                 );

                delete from creatures c
                 where c.lab_id = p_lab_id;

                delete from labs l
                 where l.lab_id = p_lab_id;

                dbms_output.put_line('[INFO] cleanup delete ' || p_label || ' direct done');
            exception
                when others then
                    dbms_output.put_line('[WARN] cleanup delete ' || p_label || ' direct: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end cleanup_lab_direct;

        procedure safe_logout(
            p_label in varchar2,
            p_token in varchar2
        ) is
        begin
            if p_token is null then
                return;
            end if;

            begin
                pkg_genetics_game.logout_user(p_token);
                dbms_output.put_line('[INFO] cleanup logout ' || p_label || ' done');
            exception
                when others then
                    if sqlcode in (-20020, -20021) then
                        dbms_output.put_line('[INFO] cleanup logout ' || p_label || ' skipped: ' || sqlcode || ' / ' || sqlerrm);
                    else
                        dbms_output.put_line('[WARN] cleanup logout ' || p_label || ': ' || sqlcode || ' / ' || sqlerrm);
                    end if;
            end;
        end safe_logout;
    begin
        cleanup_lab_via_package('lab2', v_session2_token, v_lab2_id);
        cleanup_lab_via_package('lab1', v_session1_token_relogin, v_lab1_id);
        cleanup_lab_via_package('lab1', v_session1_token, v_lab1_id);

        cleanup_lab_direct('lab2', v_lab2_id);
        cleanup_lab_direct('lab1', v_lab1_id);

        begin
            if v_custom_task_id is not null then
                delete from task_markers tm
                 where tm.task_id = v_custom_task_id;

                delete from lab_tasks lt
                 where lt.task_id = v_custom_task_id;

                delete from tasks t
                 where t.task_id = v_custom_task_id;
            end if;

            if v_inc_gene_id is not null then
                delete from mutation_rules mr
                 where mr.gene_id = v_inc_gene_id;

                delete from genotypes gt
                 where gt.gene_id = v_inc_gene_id;

                delete from alleles a
                 where a.gene_id = v_inc_gene_id;

                delete from genes g
                 where g.gene_id = v_inc_gene_id;
            end if;

            if v_codom_gene_id is not null then
                delete from mutation_rules mr
                 where mr.gene_id = v_codom_gene_id;

                delete from genotypes gt
                 where gt.gene_id = v_codom_gene_id;

                delete from alleles a
                 where a.gene_id = v_codom_gene_id;

                delete from genes g
                 where g.gene_id = v_codom_gene_id;
            end if;
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup custom genes/tasks: ' || sqlcode || ' / ' || sqlerrm);
        end;

        safe_logout('user2', v_session2_token);
        safe_logout('user1 relogin', v_session1_token_relogin);
        safe_logout('user1', v_session1_token);

        begin
            delete from lab_tasks lt
             where lt.lab_id in (
                    select l.lab_id
                      from labs l
                     where l.user_id in (v_user1_id, v_user2_id)
             );

            delete from lab_mutations lm
             where lm.lab_id in (
                    select l.lab_id
                      from labs l
                     where l.user_id in (v_user1_id, v_user2_id)
             );

            delete from experiments e
             where e.lab_id in (
                    select l.lab_id
                      from labs l
                     where l.user_id in (v_user1_id, v_user2_id)
             );

            delete from genotypes g
             where g.creature_id in (
                    select c.creature_id
                      from creatures c
                      join labs l
                        on l.lab_id = c.lab_id
                     where l.user_id in (v_user1_id, v_user2_id)
             );

            delete from creatures c
             where c.lab_id in (
                    select l.lab_id
                      from labs l
                     where l.user_id in (v_user1_id, v_user2_id)
             );

            delete from labs l
             where l.user_id in (v_user1_id, v_user2_id);
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup residual lab data: ' || sqlcode || ' / ' || sqlerrm);
        end;

        begin
            delete from sessions s
             where s.user_id in (v_user1_id, v_user2_id)
                or s.user_id in (
                    select u.user_id
                      from users u
                     where u.login in (v_login1, v_login2)
                );

            delete from users u
             where u.user_id in (v_user1_id, v_user2_id)
                or u.login in (v_login1, v_login2);
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup users/sessions: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end cleanup_test_data;
begin
    v_login1 := 'u' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_login2 := 'u' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_username1 := 'strict_u1_' || substr(v_login1, 2, 6);
    v_username2 := 'strict_u2_' || substr(v_login2, 2, 6);
    v_suffix := lower(substr(rawtohex(sys_guid()), 1, 8));

    dbms_output.put_line('--- STRICT COMPLIANCE SMOKE TEST ---');
    dbms_output.put_line('user1=' || v_login1 || ', user2=' || v_login2);

    pkg_genetics_game.register_user(v_username1, v_login1, v_password1, v_user1_id);
    v_session1_token := pkg_genetics_game.login_user(v_login1, v_password1);
    assert_true(v_session1_token is not null, 'user1 login');

    pkg_genetics_game.start_new_lab(v_session1_token, v_lab1_id);
    pkg_genetics_game.get_lab_stats(
        p_lab_id               => v_lab1_id,
        p_wallet               => v_wallet,
        p_rating               => v_rating,
        p_creature_count       => v_creature_count,
        p_active_task_count    => v_active_task_count,
        p_completed_task_count => v_completed_task_count,
        p_experiment_count     => v_experiment_count
    );
    assert_true(v_creature_count = 30, 'start_new_lab creates 30 creatures', 'actual=' || v_creature_count);
    assert_true(v_active_task_count = 3, 'start_new_lab assigns 3 ACTIVE tasks', 'actual=' || v_active_task_count);

    select min(c.creature_id)
      into v_lab1_creature_id
      from creatures c
     where c.lab_id = v_lab1_id;

    pkg_genetics_game.register_user(v_username2, v_login2, v_password2, v_user2_id);
    v_session2_token := pkg_genetics_game.login_user(v_login2, v_password2);
    assert_true(v_session2_token is not null, 'user2 login');

    pkg_genetics_game.start_new_lab(v_session2_token, v_lab2_id);
    select min(c.creature_id)
      into v_lab2_creature_id
      from creatures c
     where c.lab_id = v_lab2_id;

    begin
        v_rc := pkg_genetics_game.get_creatures_cursor(v_lab1_id);
        if v_rc%isopen then
            close v_rc;
        end if;
        fail_test('foreign lab access blocked (get_creatures_cursor)', 'expected -20068');
    exception
        when others then
            if v_rc%isopen then
                close v_rc;
            end if;
            if sqlcode = -20068 then
                pass_test('foreign lab access blocked (get_creatures_cursor)');
            else
                fail_test('foreign lab access blocked (get_creatures_cursor)', 'unexpected sqlcode=' || sqlcode || ' ' || sqlerrm);
            end if;
    end;

    begin
        v_rc := pkg_genetics_game.get_genotype_cursor(v_lab1_creature_id);
        if v_rc%isopen then
            close v_rc;
        end if;
        fail_test('foreign creature access blocked (get_genotype_cursor)', 'expected -20069');
    exception
        when others then
            if v_rc%isopen then
                close v_rc;
            end if;
            if sqlcode = -20069 then
                pass_test('foreign creature access blocked (get_genotype_cursor)');
            else
                fail_test('foreign creature access blocked (get_genotype_cursor)', 'unexpected sqlcode=' || sqlcode || ' ' || sqlerrm);
            end if;
    end;

    v_session1_token_relogin := pkg_genetics_game.login_user(v_login1, v_password1);
    assert_true(v_session1_token_relogin is not null, 'user1 relogin for own context');

    v_inc_gene_id := genes_seq.nextval;
    insert into genes (gene_id, gene_name, gene_type, species_type, dominance_type, linkage_group, created_at)
    values (v_inc_gene_id, 'strict_inc_' || v_suffix, 'strict_test', 0, 'INCOMPLETE', null, systimestamp);

    v_inc_a_low_id := alleles_seq.nextval;
    insert into alleles (allele_id, gene_id, dominance, trait_value, description, created_at)
    values (v_inc_a_low_id, v_inc_gene_id, 1, 0, 'strict_inc_low_' || v_suffix, systimestamp);

    v_inc_a_mid_id := alleles_seq.nextval;
    insert into alleles (allele_id, gene_id, dominance, trait_value, description, created_at)
    values (v_inc_a_mid_id, v_inc_gene_id, 1, 1, 'strict_inc_mid_' || v_suffix, systimestamp);

    v_inc_a_high_id := alleles_seq.nextval;
    insert into alleles (allele_id, gene_id, dominance, trait_value, description, created_at)
    values (v_inc_a_high_id, v_inc_gene_id, 1, 2, 'strict_inc_high_' || v_suffix, systimestamp);

    v_codom_gene_id := genes_seq.nextval;
    insert into genes (gene_id, gene_name, gene_type, species_type, dominance_type, linkage_group, created_at)
    values (v_codom_gene_id, 'strict_codom_' || v_suffix, 'strict_test', 0, 'CODOMINANT', null, systimestamp);

    v_codom_a_id := alleles_seq.nextval;
    insert into alleles (allele_id, gene_id, dominance, trait_value, description, created_at)
    values (v_codom_a_id, v_codom_gene_id, 5, 10, 'strict_cod_a_' || v_suffix, systimestamp);

    v_codom_b_id := alleles_seq.nextval;
    insert into alleles (allele_id, gene_id, dominance, trait_value, description, created_at)
    values (v_codom_b_id, v_codom_gene_id, 1, 20, 'strict_cod_b_' || v_suffix, systimestamp);

    insert into genotypes (genotype_id, creature_id, gene_id, allele1_id, allele2_id, created_at)
    values (genotypes_seq.nextval, v_lab1_creature_id, v_inc_gene_id, v_inc_a_low_id, v_inc_a_high_id, systimestamp);

    insert into genotypes (genotype_id, creature_id, gene_id, allele1_id, allele2_id, created_at)
    values (genotypes_seq.nextval, v_lab1_creature_id, v_codom_gene_id, v_codom_a_id, v_codom_b_id, systimestamp);

    v_summary := pkg_genetics_game.get_phenotype(v_lab1_creature_id);
    assert_true(instr(lower(v_summary), lower('strict_inc_' || v_suffix || '=' || 'strict_inc_mid_' || v_suffix)) > 0,
        'INCOMPLETE dominance produces intermediate phenotype', v_summary);
    assert_true(instr(lower(v_summary), lower('strict_codom_' || v_suffix || '=' || 'strict_cod_a_' || v_suffix || '/' || 'strict_cod_b_' || v_suffix)) > 0,
        'CODOMINANT dominance shows both traits', v_summary);

    pkg_genetics_game.apply_mutagen(
        p_creature_id     => v_lab1_creature_id,
        p_mutagen_type    => 'CHEMICAL',
        p_new_creature_id => v_mut_chemical_creature_id
    );
    pkg_genetics_game.apply_mutagen(
        p_creature_id     => v_lab1_creature_id,
        p_mutagen_type    => 'RADIATION',
        p_new_creature_id => v_mut_radiation_creature_id
    );

    select sum(
               case when src.allele1_id <> dst.allele1_id then 1 else 0 end
             + case when src.allele2_id <> dst.allele2_id then 1 else 0 end
           )
      into v_diff_chemical
      from genotypes src
      join genotypes dst
        on dst.gene_id = src.gene_id
     where src.creature_id = v_lab1_creature_id
       and dst.creature_id = v_mut_chemical_creature_id;

    select sum(
               case when src.allele1_id <> dst.allele1_id then 1 else 0 end
             + case when src.allele2_id <> dst.allele2_id then 1 else 0 end
           )
      into v_diff_radiation
      from genotypes src
      join genotypes dst
        on dst.gene_id = src.gene_id
     where src.creature_id = v_lab1_creature_id
       and dst.creature_id = v_mut_radiation_creature_id;

    assert_true(v_diff_chemical = 1, 'CHEMICAL mutagen makes controlled single change', 'diff=' || v_diff_chemical);
    assert_true(v_diff_radiation >= 1, 'RADIATION mutagen makes at least one change', 'diff=' || v_diff_radiation);

    begin
        pkg_genetics_game.apply_mutagen(
            p_creature_id     => v_lab1_creature_id,
            p_mutagen_type    => 'UNKNOWN_TYPE',
            p_new_creature_id => v_dummy_num
        );
        fail_test('unknown mutagen type rejected', 'expected -20070');
    exception
        when others then
            if sqlcode = -20070 then
                pass_test('unknown mutagen type rejected');
            else
                fail_test('unknown mutagen type rejected', 'unexpected sqlcode=' || sqlcode || ' ' || sqlerrm);
            end if;
    end;

    begin
        select x.mutation_id, x.creature_id, x.target_allele_id
          into v_mutation_id, v_target_creature_id, v_marker_allele_id
          from (
                select mr.mutation_id, c.creature_id, mr.target_allele_id
                  from mutation_rules mr
                  join genotypes g
                    on g.gene_id = mr.gene_id
                  join creatures c
                    on c.creature_id = g.creature_id
                   and c.lab_id = v_lab1_id
                 order by mr.mutation_id, c.creature_id, mr.mutation_rule_id
          ) x
         where rownum = 1;
    exception
        when no_data_found then
            fail_test('prepare auto-task mutation candidate', 'no mutation_rules candidate found for lab1');
    end;

    if v_mutation_id is not null then
        select l.wallet, l.rating
          into v_wallet_before_auto, v_rating_before_auto
          from labs l
         where l.lab_id = v_lab1_id;

        select count(*)
          into v_tasks_pool_count
          from tasks t;

        select count(*)
          into v_assigned_before_auto
          from lab_tasks lt
         where lt.lab_id = v_lab1_id;

        select count(*)
          into v_active_before_auto
          from lab_tasks lt
         where lt.lab_id = v_lab1_id
           and lt.task_status = 'ACTIVE';

        v_custom_task_id := tasks_seq.nextval;
        insert into tasks (
            task_id, task_name, description, money_reward, rating_reward, created_at
        ) values (
            v_custom_task_id,
            'strict_auto_task_' || v_suffix,
            'Auto-complete task for strict test ' || v_suffix,
            11,
            5,
            systimestamp
        );

        v_custom_lab_task_id := lab_tasks_seq.nextval;
        insert into lab_tasks (
            lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at
        ) values (
            v_custom_lab_task_id,
            v_lab1_id,
            v_custom_task_id,
            'ACTIVE',
            systimestamp,
            null
        );

        insert into task_markers (
            task_marker_id, task_id, allele_id
        ) values (
            task_markers_seq.nextval,
            v_custom_task_id,
            v_marker_allele_id
        );

        v_buy_result := pkg_genetics_game.buy_mutation(v_lab1_id, v_mutation_id);
        if v_buy_result = 0 then
            fail_test('buy_mutation for auto-task scenario', 'insufficient wallet');
        else
            pass_test('buy_mutation for auto-task scenario');

            select l.wallet, l.rating
              into v_wallet_after_buy, v_rating_after_buy
              from labs l
             where l.lab_id = v_lab1_id;

            pkg_genetics_game.apply_mutation(v_target_creature_id, v_mutation_id);

            select lt.task_status
              into v_custom_status
              from lab_tasks lt
             where lt.lab_id = v_lab1_id
               and lt.task_id = v_custom_task_id;

            select l.wallet, l.rating
              into v_wallet_after_auto, v_rating_after_auto
              from labs l
             where l.lab_id = v_lab1_id;

            select count(*)
              into v_assigned_after_auto
              from lab_tasks lt
             where lt.lab_id = v_lab1_id;

            select count(*)
              into v_active_after_auto
              from lab_tasks lt
             where lt.lab_id = v_lab1_id
               and lt.task_status = 'ACTIVE';

            select count(distinct lt.task_id)
              into v_distinct_assigned_after_auto
              from lab_tasks lt
             where lt.lab_id = v_lab1_id;

            assert_true(v_custom_status = 'COMPLETED', 'auto task check after apply_mutation completes task', 'status=' || v_custom_status);
            assert_true(v_wallet_after_auto >= v_wallet_after_buy + 11, 'auto task reward money applied');
            assert_true(v_rating_after_auto >= v_rating_after_buy + 5, 'auto task reward rating applied');
            assert_true(
                v_assigned_after_auto = v_distinct_assigned_after_auto,
                'task refill does not create duplicate task_id assignments',
                'total=' || v_assigned_after_auto || ', distinct=' || v_distinct_assigned_after_auto
            );
            assert_true(
                v_assigned_after_auto <= v_tasks_pool_count,
                'assigned tasks remain within tasks pool size',
                'assigned=' || v_assigned_after_auto || ', pool=' || v_tasks_pool_count
            );

            if v_assigned_before_auto < v_tasks_pool_count then
                assert_true(
                    v_assigned_after_auto > v_assigned_before_auto,
                    'auto-complete flow triggers task refill when pool is available',
                    'before=' || v_assigned_before_auto || ', after=' || v_assigned_after_auto || ', pool=' || v_tasks_pool_count
                );
            else
                pass_test('auto-complete flow keeps stable assignment count when pool is exhausted');
            end if;

            assert_true(
                v_active_after_auto <= 3,
                'active tasks after auto-complete stay capped at 3',
                'before_active=' || v_active_before_auto || ', after_active=' || v_active_after_auto
            );
        end if;
    end if;

    cleanup_test_data;
    commit;

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    if v_failed_tests > 0 then
        raise_application_error(-20700, 'Strict compliance smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
exception
    when others then
        v_unhandled_sqlcode := sqlcode;
        v_unhandled_sqlerrm := sqlerrm;

        dbms_output.put_line(
            '[ERROR] Unhandled exception in 07_strict_compliance_smoke_test: '
            || v_unhandled_sqlcode
            || ' / '
            || v_unhandled_sqlerrm
        );

        begin
            cleanup_test_data;
            commit;
        exception
            when others then
                dbms_output.put_line('[WARN] Cleanup after error failed: ' || sqlcode || ' / ' || sqlerrm);
        end;

        raise_application_error(
            -20700,
            'Strict compliance smoke-test failed. Root error: '
            || to_char(v_unhandled_sqlcode)
            || ' / '
            || substr(v_unhandled_sqlerrm, 1, 1400)
        );
end;
/
