set serveroutput on size unlimited;
set verify off;

DECLARE
    v_user_id                  number;
    v_lab_id                   number;
    v_login                    varchar2(30);
    v_username                 varchar2(255);
    v_password                 varchar2(100) := 'lr2compat123';
    v_session_token            varchar2(128);
    v_hash1                    varchar2(128);
    v_hash2                    varchar2(128);

    v_wallet                   number;
    v_rating                   number;
    v_creature_count           number;
    v_active_task_count        number;
    v_completed_task_count     number;
    v_experiment_count         number;

    v_creature_id              number;
    v_gene_id                  number;
    v_linkage_group            number;
    v_dominant_allele          varchar2(4000);
    v_inherited_allele_id      number;
    v_linked_allele_set        varchar2(4000);
    v_allele_exists            number;

    v_parent1_id               number;
    v_parent2_id               number;
    v_offspring_id             number;

    v_shop_cursor              sys_refcursor;
    v_shop_mutation_id         number;
    v_shop_mutation_name       varchar2(4000);
    v_shop_mutation_type       number;
    v_shop_mutation_type_label varchar2(4000);
    v_shop_description         varchar2(4000);
    v_shop_price               number;
    v_shop_rating_effect       number;
    v_shop_count               number := 0;

    v_failed_tests             number := 0;
    v_passed_tests             number := 0;

    PROCEDURE pass_test(p_test_name in varchar2) IS
    BEGIN
        v_passed_tests := v_passed_tests + 1;
        dbms_output.put_line('[PASS] ' || p_test_name);
    END pass_test;

    PROCEDURE fail_test(
        p_test_name in varchar2,
        p_detail    in varchar2 default null
    ) IS
    BEGIN
        v_failed_tests := v_failed_tests + 1;
        dbms_output.put_line('[FAIL] ' || p_test_name || CASE WHEN p_detail IS NULL THEN '' ELSE ' -> ' || p_detail END);
    END fail_test;

    PROCEDURE assert_true(
        p_condition in boolean,
        p_test_name in varchar2,
        p_detail    in varchar2 default null
    ) IS
    BEGIN
        IF p_condition THEN
            pass_test(p_test_name);
        ELSE
            fail_test(p_test_name, p_detail);
        END IF;
    END assert_true;

    PROCEDURE cleanup_test_data IS
    BEGIN
        BEGIN
            IF v_session_token IS NOT NULL AND v_lab_id IS NOT NULL THEN
                pkg_genetics_game.delete_lab(
                    p_session_token => v_session_token,
                    p_lab_id        => v_lab_id
                );
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('[INFO] cleanup delete_lab skipped: ' || sqlcode || ' / ' || sqlerrm);
        END;

        BEGIN
            IF v_session_token IS NOT NULL THEN
                pkg_genetics_game.logout_user(v_session_token);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('[INFO] cleanup logout skipped: ' || sqlcode || ' / ' || sqlerrm);
        END;
    END cleanup_test_data;
BEGIN
    v_login := 'lr2_' || lower(substr(rawtohex(sys_guid()), 1, 16));
    v_username := 'lr2_user_' || substr(v_login, 5, 8);

    dbms_output.put_line('LR2 API smoke login: ' || v_login);
    dbms_output.put_line('--- LR2 PACKAGE API COMPAT ---');

    BEGIN
        v_hash1 := pkg_genetics_game.hash_password(v_password);
        v_hash2 := pkg_genetics_game.hash_password(v_password);
        assert_true(v_hash1 IS NOT NULL, 'hash_password returns non-null');
        assert_true(v_hash1 = v_hash2, 'hash_password is deterministic', 'hash values differ for the same password');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('hash_password', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.register_user(
            p_username => v_username,
            p_login    => v_login,
            p_password => v_password,
            p_user_id  => v_user_id
        );
        assert_true(v_user_id IS NOT NULL AND v_user_id > 0, 'register_user from LR2 API');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('register_user from LR2 API', sqlerrm);
    END;

    BEGIN
        v_session_token := pkg_genetics_game.login_user(
            p_login    => v_login,
            p_password => v_password
        );
        assert_true(v_session_token IS NOT NULL, 'login_user from LR2 API', 'session token is null');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('login_user from LR2 API', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.start_new_lab(
            p_session_token => v_session_token,
            p_lab_id        => v_lab_id
        );

        pkg_genetics_game.get_lab_stats(
            p_lab_id               => v_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );

        assert_true(v_lab_id IS NOT NULL AND v_lab_id > 0, 'start_new_lab returns lab_id');
        assert_true(v_creature_count = 30, 'start_new_lab creates 30 creatures', 'creature_count=' || v_creature_count);
        assert_true(v_active_task_count = 3, 'start_new_lab assigns 3 ACTIVE tasks', 'active_task_count=' || v_active_task_count);
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('start_new_lab / get_lab_stats', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.show_lab_stats(v_lab_id);
        pass_test('show_lab_stats executes');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('show_lab_stats executes', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.show_creatures(v_lab_id);
        pass_test('show_creatures executes');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('show_creatures executes', sqlerrm);
    END;

    BEGIN
        select c.creature_id
          into v_creature_id
          from creatures c
         where c.lab_id = v_lab_id
           and rownum = 1;

        select gt.gene_id
          into v_gene_id
          from genotypes gt
         where gt.creature_id = v_creature_id
           and rownum = 1;

        v_dominant_allele := pkg_genetics_game.get_dominant_allele(
            p_creature_id => v_creature_id,
            p_gene_id     => v_gene_id
        );
        assert_true(v_dominant_allele IS NOT NULL, 'get_dominant_allele returns value');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('get_dominant_allele returns value', sqlerrm);
    END;

    BEGIN
        v_inherited_allele_id := pkg_genetics_game.get_inherited_allele(
            p_parent_id => v_creature_id,
            p_gene_id   => v_gene_id
        );

        select count(*)
          into v_allele_exists
          from alleles a
         where a.allele_id = v_inherited_allele_id;

        assert_true(v_allele_exists = 1, 'get_inherited_allele returns existing allele_id', 'allele_id=' || v_inherited_allele_id);
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('get_inherited_allele returns existing allele_id', sqlerrm);
    END;

    BEGIN
        select g.linkage_group
          into v_linkage_group
          from genotypes gt
          join genes g
            on g.gene_id = gt.gene_id
         where gt.creature_id = v_creature_id
           and g.linkage_group is not null
           and rownum = 1;

        assert_true(v_linkage_group IS NOT NULL, 'seed contains linkage_group for LR2 helper');

        v_linked_allele_set := pkg_genetics_game.get_linked_allele_set(
            p_creature_id   => v_creature_id,
            p_linkage_group => v_linkage_group
        );
        assert_true(v_linked_allele_set IS NOT NULL, 'get_linked_allele_set returns string', 'result is null');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            fail_test('get_linked_allele_set returns string', 'no linked genes found for selected creature');
        WHEN OTHERS THEN
            fail_test('get_linked_allele_set returns string', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.show_tasks(v_lab_id);
        pass_test('show_tasks executes');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('show_tasks executes', sqlerrm);
    END;

    BEGIN
        select creature_id
          into v_parent1_id
          from (
                select c.creature_id
                  from creatures c
                 where c.lab_id = v_lab_id
                   and c.species_type = 1
                 order by c.creature_id
          )
         where rownum = 1;

        select creature_id
          into v_parent2_id
          from (
                select c.creature_id
                  from creatures c
                 where c.lab_id = v_lab_id
                   and c.species_type = 1
                   and c.creature_id <> v_parent1_id
                 order by c.creature_id
          )
         where rownum = 1;

        pkg_genetics_game.crossbreed(
            p_lab_id         => v_lab_id,
            p_parent1_id     => v_parent1_id,
            p_parent2_id     => v_parent2_id,
            p_offspring_name => 'lr2_history_offspring',
            p_offspring_id   => v_offspring_id
        );

        assert_true(v_offspring_id IS NOT NULL AND v_offspring_id > 0, 'crossbreed for history wrapper');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('crossbreed for history wrapper', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.show_mutation_history(v_lab_id);
        pass_test('show_mutation_history executes');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('show_mutation_history executes', sqlerrm);
    END;

    BEGIN
        v_shop_cursor := pkg_genetics_game.show_mutation_shop;

        loop
            fetch v_shop_cursor into
                v_shop_mutation_id,
                v_shop_mutation_name,
                v_shop_mutation_type,
                v_shop_mutation_type_label,
                v_shop_description,
                v_shop_price,
                v_shop_rating_effect;
            exit when v_shop_cursor%notfound;
            v_shop_count := v_shop_count + 1;
        end loop;

        close v_shop_cursor;
        assert_true(v_shop_count > 0, 'show_mutation_shop returns rows', 'shop_count=' || v_shop_count);
    EXCEPTION
        WHEN OTHERS THEN
            if v_shop_cursor%isopen then
                close v_shop_cursor;
            end if;
            fail_test('show_mutation_shop returns rows', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.exit_lab(v_lab_id);
        pass_test('exit_lab executes');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('exit_lab executes', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.get_lab_stats(
            p_lab_id               => v_lab_id,
            p_wallet               => v_wallet,
            p_rating               => v_rating,
            p_creature_count       => v_creature_count,
            p_active_task_count    => v_active_task_count,
            p_completed_task_count => v_completed_task_count,
            p_experiment_count     => v_experiment_count
        );
        fail_test('exit_lab clears current lab context', 'expected lab access error after exit_lab');
    EXCEPTION
        WHEN OTHERS THEN
            if sqlcode = -20073 then
                pass_test('exit_lab clears current lab context');
            else
                fail_test('exit_lab clears current lab context', 'unexpected error ' || sqlcode || ': ' || sqlerrm);
            end if;
    END;

    cleanup_test_data;

    dbms_output.put_line('--- LR2 PACKAGE API SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    IF v_failed_tests > 0 THEN
        raise_application_error(-20500, 'LR2 package API compatibility smoke-test failed. See DBMS_OUTPUT.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        cleanup_test_data;
        raise;
END;
/
