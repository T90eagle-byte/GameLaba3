set serveroutput on size unlimited;
set verify off;

declare
    v_passed number := 0;
    v_failed number := 0;

    v_suffix varchar2(32) := to_char(systimestamp, 'YYYYMMDDHH24MISSFF3');
    v_login1 varchar2(20) := 'u' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_login2 varchar2(20) := 'v' || lower(substr(rawtohex(sys_guid()), 1, 19));

    v_user1_id number;
    v_user2_id number;
    v_lab1_id number;
    v_lab2_id number;
    v_creature1_id number;
    v_creature2_id number;
    v_task1_id number;
    v_mutation_id number;

    v_session1 varchar2(128);
    v_session1b varchar2(128);
    v_session1c varchar2(128);
    v_session2 varchar2(128);

    v_wallet number;
    v_rating number;
    v_creature_count number;
    v_active_task_count number;
    v_completed_task_count number;
    v_experiment_count number;

    v_tmp number;
    v_tmp2 number;
    v_tmp3 number;

    v_cursor sys_refcursor;
    v_new_creature_id number;

    procedure pass_test(p_name in varchar2) is
    begin
        v_passed := v_passed + 1;
        dbms_output.put_line('[PASS] ' || p_name);
    end;

    procedure fail_test(p_name in varchar2, p_detail in varchar2 default null) is
    begin
        v_failed := v_failed + 1;
        dbms_output.put_line('[FAIL] ' || p_name || case when p_detail is null then '' else ' -> ' || p_detail end);
    end;

    procedure assert_true(p_cond in boolean, p_name in varchar2, p_detail in varchar2 default null) is
    begin
        if p_cond then
            pass_test(p_name);
        else
            fail_test(p_name, p_detail);
        end if;
    end;

    procedure expect_error(p_name in varchar2, p_sqlcode1 in number, p_sqlcode2 in number default null) is
    begin
        fail_test(p_name, 'Expected error ' || p_sqlcode1 || case when p_sqlcode2 is null then '' else ' or ' || p_sqlcode2 end || ', but call succeeded');
    exception
        when others then
            if sqlcode = p_sqlcode1 or (p_sqlcode2 is not null and sqlcode = p_sqlcode2) then
                pass_test(p_name);
            else
                fail_test(p_name, 'Unexpected error: ' || sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    procedure safe_close_cursor is
    begin
        if v_cursor%isopen then
            close v_cursor;
        end if;
    exception
        when others then
            null;
    end;

    procedure safe_logout(p_token in varchar2) is
    begin
        if p_token is null then
            return;
        end if;

        begin
            pkg_genetics_game.logout_user(p_token);
        exception
            when others then
                if sqlcode not in (-20020, -20021) then
                    dbms_output.put_line('[WARN] cleanup logout: ' || sqlcode || ' / ' || sqlerrm);
                end if;
        end;
    end;

    procedure safe_delete_lab(p_token in varchar2, p_lab_id in number) is
    begin
        if p_token is null or p_lab_id is null then
            return;
        end if;

        begin
            pkg_genetics_game.delete_lab(
                p_session_token => p_token,
                p_lab_id        => p_lab_id
            );
        exception
            when others then
                dbms_output.put_line('[INFO] cleanup delete via package skipped: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end;

    procedure direct_cleanup is
    begin
        begin
            delete from rating_events where lab_id in (v_lab1_id, v_lab2_id);
            delete from lab_tasks where lab_id in (v_lab1_id, v_lab2_id);
            delete from lab_mutations where lab_id in (v_lab1_id, v_lab2_id);
            delete from experiments where lab_id in (v_lab1_id, v_lab2_id);

            delete from genotypes
             where creature_id in (
                    select c.creature_id
                      from creatures c
                     where c.lab_id in (v_lab1_id, v_lab2_id)
             );

            delete from creatures where lab_id in (v_lab1_id, v_lab2_id);
            delete from labs where lab_id in (v_lab1_id, v_lab2_id);

            delete from sessions where user_id in (v_user1_id, v_user2_id);
            delete from users where user_id in (v_user1_id, v_user2_id);
        exception
            when others then
                dbms_output.put_line('[WARN] direct cleanup: ' || sqlcode || ' / ' || sqlerrm);
        end;
    end;

begin
    -- bootstrap users/sessions/labs
    pkg_genetics_game.register_user(
        p_username => 'multi_user1_' || v_suffix,
        p_login    => v_login1,
        p_password => 'Multi_user1_123',
        p_user_id  => v_user1_id
    );
    assert_true(v_user1_id is not null, 'register user1');

    v_session1 := pkg_genetics_game.login_user(
        p_login    => v_login1,
        p_password => 'Multi_user1_123'
    );
    assert_true(v_session1 is not null, 'login user1 session1');

    pkg_genetics_game.start_new_lab(
        p_session_token => v_session1,
        p_lab_id        => v_lab1_id
    );
    assert_true(v_lab1_id is not null, 'user1 start_new_lab');

    select min(c.creature_id)
      into v_creature1_id
      from creatures c
     where c.lab_id = v_lab1_id;

    select min(lt.task_id)
      into v_task1_id
      from lab_tasks lt
     where lt.lab_id = v_lab1_id
       and lt.task_status = 'ACTIVE';

    pkg_genetics_game.register_user(
        p_username => 'multi_user2_' || v_suffix,
        p_login    => v_login2,
        p_password => 'Multi_user2_123',
        p_user_id  => v_user2_id
    );
    assert_true(v_user2_id is not null, 'register user2');

    v_session2 := pkg_genetics_game.login_user(
        p_login    => v_login2,
        p_password => 'Multi_user2_123'
    );
    assert_true(v_session2 is not null, 'login user2 session');

    pkg_genetics_game.start_new_lab(
        p_session_token => v_session2,
        p_lab_id        => v_lab2_id
    );
    assert_true(v_lab2_id is not null, 'user2 start_new_lab');

    select min(c.creature_id)
      into v_creature2_id
      from creatures c
     where c.lab_id = v_lab2_id;

    select min(m.mutation_id)
      into v_mutation_id
      from mutations m;

    -- user2 cannot open user1 lab
    begin
        pkg_genetics_game.load_lab(v_session2, v_lab1_id);
        expect_error('user2 load_lab user1 lab blocked', -20023);
    exception
        when others then
            if sqlcode = -20023 then
                pass_test('user2 load_lab user1 lab blocked');
            else
                fail_test('user2 load_lab user1 lab blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    begin
        pkg_genetics_game.switch_lab(v_session2, v_lab1_id);
        expect_error('user2 switch_lab user1 lab blocked', -20023);
    exception
        when others then
            if sqlcode = -20023 then
                pass_test('user2 switch_lab user1 lab blocked');
            else
                fail_test('user2 switch_lab user1 lab blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    -- user2 cannot read foreign lab
    begin
        v_cursor := pkg_genetics_game.get_creatures_cursor(v_lab1_id);
        safe_close_cursor;
        expect_error('user2 get_creatures foreign lab blocked', -20068);
    exception
        when others then
            safe_close_cursor;
            if sqlcode = -20068 then
                pass_test('user2 get_creatures foreign lab blocked');
            else
                fail_test('user2 get_creatures foreign lab blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    begin
        v_cursor := pkg_genetics_game.get_tasks_cursor(v_lab1_id);
        safe_close_cursor;
        expect_error('user2 get_tasks foreign lab blocked', -20068);
    exception
        when others then
            safe_close_cursor;
            if sqlcode = -20068 then
                pass_test('user2 get_tasks foreign lab blocked');
            else
                fail_test('user2 get_tasks foreign lab blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    begin
        v_cursor := pkg_genetics_game.get_experiment_history(v_lab1_id, null);
        safe_close_cursor;
        expect_error('user2 get_history foreign lab blocked', -20068);
    exception
        when others then
            safe_close_cursor;
            if sqlcode = -20068 then
                pass_test('user2 get_history foreign lab blocked');
            else
                fail_test('user2 get_history foreign lab blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    -- user2 cannot run gameplay on foreign objects
    begin
        v_tmp := pkg_genetics_game.buy_mutation(v_lab1_id, v_mutation_id);
        expect_error('user2 buy_mutation foreign lab blocked', -20068);
    exception
        when others then
            if sqlcode = -20068 then
                pass_test('user2 buy_mutation foreign lab blocked');
            else
                fail_test('user2 buy_mutation foreign lab blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    begin
        pkg_genetics_game.apply_mutation(v_creature1_id, v_mutation_id);
        expect_error('user2 apply_mutation foreign creature blocked', -20069);
    exception
        when others then
            if sqlcode = -20069 then
                pass_test('user2 apply_mutation foreign creature blocked');
            else
                fail_test('user2 apply_mutation foreign creature blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    begin
        pkg_genetics_game.apply_mutagen(v_creature1_id, 'CHEMICAL', v_new_creature_id);
        expect_error('user2 apply_mutagen foreign creature blocked', -20069);
    exception
        when others then
            if sqlcode = -20069 then
                pass_test('user2 apply_mutagen foreign creature blocked');
            else
                fail_test('user2 apply_mutagen foreign creature blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    begin
        pkg_genetics_game.crossbreed(
            p_lab_id         => v_lab1_id,
            p_parent1_id     => v_creature1_id,
            p_parent2_id     => v_creature2_id,
            p_offspring_name => 'illegal_cross_' || v_suffix,
            p_offspring_id   => v_tmp
        );
        expect_error('user2 crossbreed foreign objects blocked', -20068, -20069);
    exception
        when others then
            if sqlcode in (-20068, -20069) then
                pass_test('user2 crossbreed foreign objects blocked');
            else
                fail_test('user2 crossbreed foreign objects blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    begin
        pkg_genetics_game.complete_task(
            p_lab_id       => v_lab1_id,
            p_task_id      => v_task1_id,
            p_creature_id  => v_creature1_id,
            p_is_completed => v_tmp,
            p_wallet_after => v_tmp2,
            p_rating_after => v_tmp3
        );
        expect_error('user2 complete_task foreign lab blocked', -20068);
    exception
        when others then
            if sqlcode = -20068 then
                pass_test('user2 complete_task foreign lab blocked');
            else
                fail_test('user2 complete_task foreign lab blocked', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    -- same user, second active session lock
    v_session1b := pkg_genetics_game.login_user(
        p_login    => v_login1,
        p_password => 'Multi_user1_123'
    );
    assert_true(v_session1b is not null, 'login user1 session2');

    begin
        pkg_genetics_game.load_lab(v_session1b, v_lab1_id);
        expect_error('same lab blocked in second active session', -20072);
    exception
        when others then
            if sqlcode = -20072 then
                pass_test('same lab blocked in second active session');
            else
                fail_test('same lab blocked in second active session', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    pkg_genetics_game.load_lab(v_session1, v_lab1_id);
    pkg_genetics_game.exit_lab(v_lab1_id);

    select count(*)
      into v_tmp
      from labs l
     where l.lab_id = v_lab1_id
       and l.session_id is null;
    assert_true(v_tmp = 1, 'exit_lab releases persistent lab session binding');

    pkg_genetics_game.load_lab(v_session1b, v_lab1_id);
    pass_test('session2 can open lab after exit_lab');
    pkg_genetics_game.exit_lab(v_lab1_id);

    pkg_genetics_game.load_lab(v_session1, v_lab1_id);
    pkg_genetics_game.logout_user(v_session1);
    pass_test('logout user1 session1');

    select count(*)
      into v_tmp
      from labs l
     where l.lab_id = v_lab1_id
       and l.session_id is null;
    assert_true(v_tmp = 1, 'logout_user releases held laboratories');

    pkg_genetics_game.load_lab(v_session1b, v_lab1_id);
    pass_test('session2 can open lab after session1 logout');

    v_session1c := pkg_genetics_game.login_user(
        p_login    => v_login1,
        p_password => 'Multi_user1_123'
    );
    assert_true(v_session1c is not null, 'login user1 recovery session');

    pkg_genetics_game.reset_other_user_sessions(v_session1c);
    pass_test('reset other user sessions');

    select count(*)
      into v_tmp
      from sessions s
     where s.session_token = v_session1b
       and s.status = 'CLOSED';
    assert_true(v_tmp = 1, 'reset closes another active session of same user');

    select count(*)
      into v_tmp
      from sessions s
     where s.session_token = v_session1c
       and s.status = 'ACTIVE';
    assert_true(v_tmp = 1, 'reset keeps current session active');

    select count(*)
      into v_tmp
      from sessions s
     where s.session_token = v_session2
       and s.status = 'ACTIVE';
    assert_true(v_tmp = 1, 'reset does not close another user session');

    select count(*)
      into v_tmp
      from labs l
     where l.lab_id = v_lab1_id
       and l.session_id is null;
    assert_true(v_tmp = 1, 'reset releases labs held by old sessions');

    pkg_genetics_game.load_lab(v_session1c, v_lab1_id);
    pass_test('current session can load released lab after reset');

    pkg_genetics_game.get_lab_stats(
        p_lab_id               => v_lab1_id,
        p_wallet               => v_wallet,
        p_rating               => v_rating,
        p_creature_count       => v_creature_count,
        p_active_task_count    => v_active_task_count,
        p_completed_task_count => v_completed_task_count,
        p_experiment_count     => v_experiment_count
    );
    pass_test('gameplay works in current session after reset');

    begin
        pkg_genetics_game.load_lab(v_session1b, v_lab1_id);
        expect_error('reset old session cannot reopen lab', -20020);
    exception
        when others then
            if sqlcode = -20020 then
                pass_test('reset old session cannot reopen lab');
            else
                fail_test('reset old session cannot reopen lab', sqlcode || ' / ' || sqlerrm);
            end if;
    end;

    dbms_output.put_line('----------------------------------------------------');
    dbms_output.put_line('Passed: ' || v_passed);
    dbms_output.put_line('Failed: ' || v_failed);

    safe_delete_lab(v_session1c, v_lab1_id);
    safe_delete_lab(v_session2, v_lab2_id);
    safe_logout(v_session1b);
    safe_logout(v_session1c);
    safe_logout(v_session2);
    direct_cleanup;

    if v_failed > 0 then
        raise_application_error(-20800, '08_multiuser_sessions_smoke_test failed. See DBMS_OUTPUT for details.');
    end if;
exception
    when others then
        dbms_output.put_line('[ERROR] Unhandled exception in 08_multiuser_sessions_smoke_test: ' || sqlcode || ' / ' || sqlerrm);

        safe_delete_lab(v_session1c, v_lab1_id);
        safe_delete_lab(v_session2, v_lab2_id);
        safe_logout(v_session1);
        safe_logout(v_session1b);
        safe_logout(v_session1c);
        safe_logout(v_session2);
        direct_cleanup;

        raise;
end;
/

