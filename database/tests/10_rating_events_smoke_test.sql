set serveroutput on size unlimited;
set verify off;

declare
    v_user1_id                   number;
    v_user2_id                   number;
    v_lab1_id                    number;
    v_lab2_id                    number;
    v_login1                     varchar2(30);
    v_login2                     varchar2(30);
    v_username1                  varchar2(255);
    v_username2                  varchar2(255);
    v_password                   varchar2(100) := 'rating_events_123';
    v_token1                     varchar2(128);
    v_token2                     varchar2(128);

    v_wallet_before              number;
    v_wallet_after_buy           number;
    v_wallet_after_task          number;
    v_wallet_after_mutagen       number;
    v_rating_before              number;
    v_rating_after_task          number;
    v_rating_after_mutagen       number;

    v_mutation_id                number;
    v_mutation_cost              number;
    v_buy_result                 number;
    v_creature_id                number;
    v_new_creature_id            number;
    v_gene_id                    number;
    v_allele_id                  number;
    v_task_id                    number;
    v_lab_task_id                number;

    v_ref_count                  number;
    v_table_count                number;
    v_event_count                number;
    v_purchase_events            number;
    v_mutagen_events             number;
    v_reward_events              number;
    v_reward_events_before       number;
    v_reward_events_after_repeat number;
    v_foreign_blocked            number := 0;
    v_event_wallet_delta         number;
    v_event_rating_delta         number;
    v_expected_wallet_delta      number;
    v_expected_rating_delta      number;

    v_rc                         sys_refcursor;
    v_re_event_id                number;
    v_re_lab_id                  number;
    v_re_creature_id             number;
    v_re_creature_name           varchar2(4000);
    v_re_task_id                 number;
    v_re_task_name               varchar2(4000);
    v_re_experiment_id           number;
    v_re_event_type              varchar2(4000);
    v_re_event_type_label        varchar2(4000);
    v_re_rating_delta            number;
    v_re_wallet_delta            number;
    v_re_description             varchar2(4000);
    v_re_created_at              timestamp;
    v_cursor_rows                number := 0;

    v_failed_tests               number := 0;
    v_passed_tests               number := 0;
    v_root_sqlcode               number;
    v_root_sqlerrm               varchar2(4000);

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

    procedure cleanup_test_data is
    begin
        begin
            if v_token2 is not null and v_lab2_id is not null then
                pkg_genetics_game.delete_lab(v_token2, v_lab2_id);
            end if;
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup delete lab2: ' || sqlcode || ' / ' || sqlerrm);
        end;

        begin
            if v_token1 is not null and v_lab1_id is not null then
                pkg_genetics_game.delete_lab(v_token1, v_lab1_id);
            end if;
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup delete lab1: ' || sqlcode || ' / ' || sqlerrm);
        end;

        begin
            if v_task_id is not null then
                delete from rating_events re where re.task_id = v_task_id;
                delete from task_markers tm where tm.task_id = v_task_id;
                delete from lab_tasks lt where lt.task_id = v_task_id;
                delete from tasks t where t.task_id = v_task_id;
            end if;
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup custom task: ' || sqlcode || ' / ' || sqlerrm);
        end;

        begin
            if v_token2 is not null then
                pkg_genetics_game.logout_user(v_token2);
            end if;
        exception
            when others then null;
        end;

        begin
            if v_token1 is not null then
                pkg_genetics_game.logout_user(v_token1);
            end if;
        exception
            when others then null;
        end;

        begin
            delete from sessions s
             where s.user_id in (v_user1_id, v_user2_id)
                or s.user_id in (
                    select u.user_id from users u where u.login in (v_login1, v_login2)
                );

            delete from users u
             where u.login in (v_login1, v_login2)
                or u.user_id in (v_user1_id, v_user2_id);
        exception
            when others then
                dbms_output.put_line('[WARN] cleanup users/sessions: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end cleanup_test_data;
begin
    v_login1 := 're1_' || lower(substr(rawtohex(sys_guid()), 1, 16));
    v_login2 := 're2_' || lower(substr(rawtohex(sys_guid()), 1, 16));
    v_username1 := 'rating_events_1_' || substr(v_login1, 5, 8);
    v_username2 := 'rating_events_2_' || substr(v_login2, 5, 8);

    dbms_output.put_line('--- RATING EVENTS SMOKE TEST ---');

    select count(*)
      into v_ref_count
      from ref_rating_event_types
     where event_type in (
        'TASK_REWARD',
        'MUTAGEN_PENALTY',
        'MUTATION_PURCHASE',
        'EXPERIMENT_COST',
        'RARE_TRAIT_BONUS',
        'SYSTEM_ADJUSTMENT'
     );
    assert_true(v_ref_count = 6, 'ref_rating_event_types contains required event types', 'count=' || v_ref_count);

    select count(*)
      into v_table_count
      from user_tables
     where table_name = 'RATING_EVENTS';
    assert_true(v_table_count = 1, 'rating_events table exists');

    pkg_genetics_game.register_user(v_username1, v_login1, v_password, v_user1_id);
    v_token1 := pkg_genetics_game.login_user(v_login1, v_password);
    pkg_genetics_game.start_new_lab(v_token1, v_lab1_id);
    assert_true(v_lab1_id is not null, 'start_new_lab for rating events');

    v_rc := pkg_genetics_game.get_rating_events_cursor(v_token1, v_lab1_id);
    loop
        fetch v_rc into
            v_re_event_id,
            v_re_lab_id,
            v_re_creature_id,
            v_re_creature_name,
            v_re_task_id,
            v_re_task_name,
            v_re_experiment_id,
            v_re_event_type,
            v_re_event_type_label,
            v_re_rating_delta,
            v_re_wallet_delta,
            v_re_description,
            v_re_created_at;
        exit when v_rc%notfound;
        v_cursor_rows := v_cursor_rows + 1;
    end loop;
    close v_rc;
    assert_true(v_cursor_rows = 0, 'new lab rating history starts empty', 'rows=' || v_cursor_rows);

    select l.wallet, l.rating
      into v_wallet_before, v_rating_before
      from labs l
     where l.lab_id = v_lab1_id;

    select m.mutation_id, m.cost
      into v_mutation_id, v_mutation_cost
      from (
            select m.mutation_id, m.cost
              from mutations m
             where m.cost > 0
             order by m.cost, m.mutation_id
      ) m
     where rownum = 1;

    v_buy_result := pkg_genetics_game.buy_mutation(v_lab1_id, v_mutation_id);
    assert_true(v_buy_result = 1, 'buy_mutation succeeds for event test');

    select l.wallet
      into v_wallet_after_buy
      from labs l
     where l.lab_id = v_lab1_id;

    select count(*), nvl(sum(wallet_delta), 0), nvl(sum(rating_delta), 0)
      into v_purchase_events, v_event_wallet_delta, v_event_rating_delta
      from rating_events re
     where re.lab_id = v_lab1_id
       and re.event_type = 'MUTATION_PURCHASE';

    assert_true(v_purchase_events = 1, 'MUTATION_PURCHASE event recorded once', 'count=' || v_purchase_events);
    assert_true(v_event_wallet_delta = v_wallet_after_buy - v_wallet_before, 'MUTATION_PURCHASE wallet delta matches aggregate');
    assert_true(v_event_wallet_delta < 0 and v_event_rating_delta = 0, 'MUTATION_PURCHASE deltas are cost-only');

    select c.creature_id
      into v_creature_id
      from creatures c
     where c.lab_id = v_lab1_id
       and rownum = 1;

    select g.gene_id, gt.allele1_id
      into v_gene_id, v_allele_id
      from genotypes gt
      join genes g
        on g.gene_id = gt.gene_id
     where gt.creature_id = v_creature_id
       and rownum = 1;

    v_task_id := tasks_seq.nextval;
    insert into tasks (
        task_id,
        task_name,
        description,
        rating_reward,
        money_reward,
        difficulty_code,
        created_at
    ) values (
        v_task_id,
        'task_rating_events_' || lower(substr(rawtohex(sys_guid()), 1, 12)),
        'Temporary rating events smoke task',
        25,
        40,
        'EASY',
        systimestamp
    );

    insert into task_markers (task_marker_id, task_id, allele_id)
    values (task_markers_seq.nextval, v_task_id, v_allele_id);

    v_lab_task_id := lab_tasks_seq.nextval;
    insert into lab_tasks (lab_task_id, lab_id, task_id, task_status, assigned_at, completed_at)
    values (v_lab_task_id, v_lab1_id, v_task_id, 'ACTIVE', systimestamp, null);

    select l.wallet, l.rating
      into v_wallet_after_buy, v_rating_before
      from labs l
     where l.lab_id = v_lab1_id;

    pkg_genetics_game.complete_task(
        p_lab_id       => v_lab1_id,
        p_task_id      => v_task_id,
        p_creature_id  => v_creature_id,
        p_is_completed => v_table_count,
        p_wallet_after => v_wallet_after_task,
        p_rating_after => v_rating_after_task
    );
    assert_true(v_table_count = 1, 'complete_task succeeds for rating event task');

    select count(*), nvl(sum(wallet_delta), 0), nvl(sum(rating_delta), 0)
      into v_reward_events, v_event_wallet_delta, v_event_rating_delta
      from rating_events re
     where re.lab_id = v_lab1_id
       and re.task_id = v_task_id
       and re.event_type = 'TASK_REWARD';

    assert_true(v_reward_events = 1, 'TASK_REWARD event recorded once', 'count=' || v_reward_events);
    assert_true(v_event_wallet_delta = v_wallet_after_task - v_wallet_after_buy, 'TASK_REWARD wallet delta matches aggregate');
    assert_true(v_event_rating_delta = v_rating_after_task - v_rating_before, 'TASK_REWARD rating delta matches aggregate');
    assert_true(v_event_wallet_delta >= 0 and v_event_rating_delta >= 0, 'TASK_REWARD deltas are non-negative');

    select count(*)
      into v_reward_events_before
      from rating_events re
     where re.lab_id = v_lab1_id
       and re.task_id = v_task_id
       and re.event_type = 'TASK_REWARD';

    begin
        pkg_genetics_game.complete_task(
            p_lab_id       => v_lab1_id,
            p_task_id      => v_task_id,
            p_creature_id  => v_creature_id,
            p_is_completed => v_table_count,
            p_wallet_after => v_wallet_after_task,
            p_rating_after => v_rating_after_task
        );
        fail_test('repeat complete_task is blocked', 'expected -20064');
    exception
        when others then
            if sqlcode = -20064 then
                pass_test('repeat complete_task is blocked');
            else
                fail_test('repeat complete_task is blocked', 'unexpected=' || sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    select count(*)
      into v_reward_events_after_repeat
      from rating_events re
     where re.lab_id = v_lab1_id
       and re.task_id = v_task_id
       and re.event_type = 'TASK_REWARD';
    assert_true(v_reward_events_after_repeat = v_reward_events_before, 'repeat complete_task does not duplicate TASK_REWARD');

    select l.wallet, l.rating
      into v_wallet_after_task, v_rating_after_task
      from labs l
     where l.lab_id = v_lab1_id;

    pkg_genetics_game.apply_mutagen(v_creature_id, 'RADIATION', v_new_creature_id);

    select l.wallet, l.rating
      into v_wallet_after_mutagen, v_rating_after_mutagen
      from labs l
     where l.lab_id = v_lab1_id;

    select count(*), nvl(sum(wallet_delta), 0), nvl(sum(rating_delta), 0)
      into v_mutagen_events, v_event_wallet_delta, v_event_rating_delta
      from rating_events re
     where re.lab_id = v_lab1_id
       and re.event_type = 'MUTAGEN_PENALTY';

    assert_true(v_mutagen_events = 1, 'MUTAGEN_PENALTY event recorded once', 'count=' || v_mutagen_events);
    assert_true(v_event_wallet_delta < 0, 'MUTAGEN_PENALTY wallet delta is negative', 'delta=' || v_event_wallet_delta);
    assert_true(v_event_rating_delta < 0, 'MUTAGEN_PENALTY rating delta is negative', 'delta=' || v_event_rating_delta);

    select nvl(sum(wallet_delta), 0), nvl(sum(rating_delta), 0)
      into v_expected_wallet_delta, v_expected_rating_delta
      from rating_events re
     where re.lab_id = v_lab1_id;

    assert_true(
        abs((v_wallet_after_mutagen - v_wallet_before) - v_expected_wallet_delta) < 0.0001,
        'rating_events wallet deltas explain aggregate change',
        'events=' || v_expected_wallet_delta || ', aggregate=' || (v_wallet_after_mutagen - v_wallet_before)
    );
    assert_true(
        abs((v_rating_after_mutagen - 0) - v_expected_rating_delta) < 0.0001,
        'rating_events rating deltas explain aggregate change',
        'events=' || v_expected_rating_delta || ', aggregate=' || v_rating_after_mutagen
    );

    v_cursor_rows := 0;
    v_rc := pkg_genetics_game.get_rating_events_cursor(v_token1, v_lab1_id);
    loop
        fetch v_rc into
            v_re_event_id,
            v_re_lab_id,
            v_re_creature_id,
            v_re_creature_name,
            v_re_task_id,
            v_re_task_name,
            v_re_experiment_id,
            v_re_event_type,
            v_re_event_type_label,
            v_re_rating_delta,
            v_re_wallet_delta,
            v_re_description,
            v_re_created_at;
        exit when v_rc%notfound;
        if v_re_lab_id = v_lab1_id and v_re_event_type_label is not null then
            v_cursor_rows := v_cursor_rows + 1;
        end if;
    end loop;
    close v_rc;
    assert_true(v_cursor_rows >= 3, 'get_rating_events_cursor returns lab event history', 'rows=' || v_cursor_rows);

    pkg_genetics_game.register_user(v_username2, v_login2, v_password, v_user2_id);
    v_token2 := pkg_genetics_game.login_user(v_login2, v_password);
    pkg_genetics_game.start_new_lab(v_token2, v_lab2_id);

    begin
        v_rc := pkg_genetics_game.get_rating_events_cursor(v_token2, v_lab1_id);
        close v_rc;
        fail_test('foreign lab rating history is blocked', 'expected access error');
    exception
        when others then
            if sqlcode in (-20023, -20068, -20073) then
                v_foreign_blocked := 1;
                pass_test('foreign lab rating history is blocked');
            else
                fail_test('foreign lab rating history is blocked', 'unexpected=' || sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    assert_true(v_foreign_blocked = 1, 'foreign access check executed');

    cleanup_test_data;
    commit;

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    if v_failed_tests > 0 then
        raise_application_error(-20999, 'Rating events smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
exception
    when others then
        v_root_sqlcode := sqlcode;
        v_root_sqlerrm := sqlerrm;
        dbms_output.put_line('[ERROR] Unhandled exception in rating events smoke-test: ' || v_root_sqlcode || ' / ' || v_root_sqlerrm);
        begin
            cleanup_test_data;
            commit;
        exception
            when others then
                dbms_output.put_line('[WARN] Cleanup after error failed: ' || sqlcode || ' / ' || sqlerrm);
        end;
        raise_application_error(-20999, 'Rating events smoke-test failed. Root error: ' || v_root_sqlcode || ' / ' || substr(v_root_sqlerrm, 1, 1400));
end;
/
