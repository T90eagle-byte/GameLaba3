set serveroutput on size unlimited;
set verify off;

declare
    v_user_id                 number;
    v_dup_user_id             number;
    v_lab_id                  number;
    v_login                   varchar2(20);
    v_username                varchar2(255);
    v_password                varchar2(100) := 'smokepass123';
    v_bad_password            varchar2(100) := 'smokepass123_wrong';
    v_session_token           varchar2(128);
    v_session_token_2         varchar2(128);
    v_wrong_login_token       varchar2(128);

    v_wallet                  number;
    v_rating                  number;
    v_creature_count          number;
    v_active_task_count       number;
    v_completed_task_count    number;
    v_experiment_count        number;

    v_labs_cursor             sys_refcursor;
    v_fetch_lab_id            number;
    v_fetch_user_id           number;
    v_fetch_session_id        number;
    v_fetch_wallet            number;
    v_fetch_rating            number;
    v_fetch_creature_count    number;
    v_fetch_active_task_count number;
    v_fetch_completed_count   number;
    v_fetch_experiment_count  number;
    v_fetch_created_at        timestamp;
    v_fetch_updated_at        timestamp;
    v_labs_count              number := 0;
    v_found_lab               number := 0;

    v_failed_tests            number := 0;
    v_passed_tests            number := 0;

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
begin
    v_login := 'u' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_username := 'smoke_user_' || substr(v_login, 2, 6);

    dbms_output.put_line('Smoke-test login: ' || v_login);
    dbms_output.put_line('--- AUTH / SESSION ---');

    begin
        pkg_genetics_game.register_user(
            p_username => v_username,
            p_login    => v_login,
            p_password => v_password,
            p_user_id  => v_user_id
        );
        assert_true(v_user_id is not null and v_user_id > 0, 'register_user valid', 'user_id is null or <= 0');
    exception
        when others then
            fail_test('register_user valid', sqlerrm);
    end;

    begin
        pkg_genetics_game.register_user(
            p_username => v_username || '_dup',
            p_login    => v_login,
            p_password => v_password,
            p_user_id  => v_dup_user_id
        );
        fail_test('register_user duplicate login', 'duplicate login was accepted');
    exception
        when others then
            if sqlcode in (-20005, -1) then
                pass_test('register_user duplicate login');
            else
                fail_test(
                    'register_user duplicate login',
                    'unexpected error code=' || to_char(sqlcode) || ' message=' || sqlerrm
                );
            end if;
    end;

    begin
        v_session_token := pkg_genetics_game.login_user(
            p_login    => v_login,
            p_password => v_password
        );
        assert_true(v_session_token is not null, 'login_user correct password', 'session_token is null');
    exception
        when others then
            fail_test('login_user correct password', sqlerrm);
    end;

    begin
        v_wrong_login_token := pkg_genetics_game.login_user(
            p_login    => v_login,
            p_password => v_bad_password
        );
        assert_true(v_wrong_login_token is null, 'login_user wrong password', 'expected NULL token for wrong password');
    exception
        when others then
            fail_test('login_user wrong password', sqlerrm);
    end;

    dbms_output.put_line('--- LABS ---');

    begin
        pkg_genetics_game.start_new_lab(
            p_session_token => v_session_token,
            p_lab_id        => v_lab_id
        );
        assert_true(v_lab_id is not null and v_lab_id > 0, 'start_new_lab creates lab and assigns 3 ACTIVE tasks', 'lab_id is null or <= 0');
    exception
        when others then
            fail_test('start_new_lab creates lab and assigns 3 ACTIVE tasks', sqlerrm);
    end;

    begin
        v_labs_count := 0;
        v_found_lab := 0;
        v_labs_cursor := pkg_genetics_game.list_user_labs(p_user_id => v_user_id);

        loop
            fetch v_labs_cursor into
                v_fetch_lab_id,
                v_fetch_user_id,
                v_fetch_session_id,
                v_fetch_wallet,
                v_fetch_rating,
                v_fetch_creature_count,
                v_fetch_active_task_count,
                v_fetch_completed_count,
                v_fetch_experiment_count,
                v_fetch_created_at,
                v_fetch_updated_at;
            exit when v_labs_cursor%notfound;

            v_labs_count := v_labs_count + 1;
            if v_fetch_lab_id = v_lab_id then
                v_found_lab := 1;
            end if;
        end loop;

        close v_labs_cursor;

        assert_true(v_labs_count >= 1, 'list_user_labs returns rows', 'no labs returned');
        assert_true(v_found_lab = 1, 'list_user_labs contains created lab', 'created lab not found');
    exception
        when others then
            if v_labs_cursor%isopen then
                close v_labs_cursor;
            end if;
            fail_test('list_user_labs', sqlerrm);
    end;

    begin
        pkg_genetics_game.get_lab_stats(
            p_lab_id               => v_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );

        assert_true(v_wallet = 1000, 'get_lab_stats wallet', 'expected 1000');
        assert_true(v_rating = 0, 'get_lab_stats rating', 'expected 0');
        assert_true(v_creature_count = 0, 'get_lab_stats creature_count', 'expected 0');
        assert_true(
            v_active_task_count = 3,
            'get_lab_stats active_task_count (start_new_lab creates lab and assigns 3 ACTIVE tasks)',
            'expected 3'
        );
        assert_true(v_completed_task_count = 0, 'get_lab_stats completed_task_count', 'expected 0');
        assert_true(v_experiment_count = 0, 'get_lab_stats experiment_count', 'expected 0');
    exception
        when others then
            fail_test('get_lab_stats', sqlerrm);
    end;

    begin
        pkg_genetics_game.load_lab(
            p_session_token => v_session_token,
            p_lab_id        => v_lab_id
        );
        pass_test('load_lab');
    exception
        when others then
            fail_test('load_lab', sqlerrm);
    end;

    begin
        pkg_genetics_game.switch_lab(
            p_session_token => v_session_token,
            p_new_lab_id    => v_lab_id
        );
        pass_test('switch_lab');
    exception
        when others then
            fail_test('switch_lab', sqlerrm);
    end;

    begin
        pkg_genetics_game.logout_user(
            p_session_token => v_session_token
        );
        pass_test('logout_user');
    exception
        when others then
            fail_test('logout_user', sqlerrm);
    end;

    begin
        v_session_token_2 := pkg_genetics_game.login_user(
            p_login    => v_login,
            p_password => v_password
        );
        assert_true(v_session_token_2 is not null, 'login_user after logout', 'session_token is null');
    exception
        when others then
            fail_test('login_user after logout', sqlerrm);
    end;

    begin
        pkg_genetics_game.delete_lab(
            p_session_token => v_session_token_2,
            p_lab_id        => v_lab_id
        );
        pass_test('delete_lab');
    exception
        when others then
            fail_test('delete_lab', sqlerrm);
    end;

    begin
        v_labs_count := 0;
        v_labs_cursor := pkg_genetics_game.list_user_labs(p_user_id => v_user_id);

        loop
            fetch v_labs_cursor into
                v_fetch_lab_id,
                v_fetch_user_id,
                v_fetch_session_id,
                v_fetch_wallet,
                v_fetch_rating,
                v_fetch_creature_count,
                v_fetch_active_task_count,
                v_fetch_completed_count,
                v_fetch_experiment_count,
                v_fetch_created_at,
                v_fetch_updated_at;
            exit when v_labs_cursor%notfound;
            v_labs_count := v_labs_count + 1;
        end loop;

        close v_labs_cursor;
        assert_true(v_labs_count = 0, 'list_user_labs after delete_lab', 'expected 0 labs');
    exception
        when others then
            if v_labs_cursor%isopen then
                close v_labs_cursor;
            end if;
            fail_test('list_user_labs after delete_lab', sqlerrm);
    end;

    begin
        pkg_genetics_game.logout_user(
            p_session_token => v_session_token_2
        );
        pass_test('logout_user second session');
    exception
        when others then
            fail_test('logout_user second session', sqlerrm);
    end;

    begin
        delete from sessions s
         where s.user_id = v_user_id
            or s.user_id in (
                select u.user_id
                  from users u
                 where u.login = v_login
            );

        delete from users u
         where (u.user_id = v_user_id or u.login = v_login)
           and u.login = v_login;
    exception
        when others then
            dbms_output.put_line('[WARN] Cleanup skipped: ' || sqlcode || ' / ' || sqlerrm);
    end;

    dbms_output.put_line('--- SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    if v_failed_tests > 0 then
        raise_application_error(-20100, 'Smoke-test failed. See DBMS_OUTPUT for details.');
    end if;
exception
    when others then
        dbms_output.put_line('[ERROR] Unhandled exception in smoke-test block: ' || sqlcode || ' / ' || sqlerrm);
        raise;
end;
/
