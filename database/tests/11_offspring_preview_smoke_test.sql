set serveroutput on size unlimited;
set verify off;

DECLARE
    v_user_id1                  number;
    v_user_id2                  number;
    v_lab_id1                   number;
    v_lab_id2                   number;
    v_login1                    varchar2(30);
    v_login2                    varchar2(30);
    v_username1                 varchar2(255);
    v_username2                 varchar2(255);
    v_password                  varchar2(100) := 'offspring_preview_123';
    v_token1                    varchar2(128);
    v_token2                    varchar2(128);

    v_parent1_id                number;
    v_parent2_id                number;
    v_offspring_id              number;

    v_creatures_before          number;
    v_creatures_after           number;
    v_experiments_before        number;
    v_experiments_after         number;
    v_wallet_before             number;
    v_wallet_after              number;
    v_rating_before             number;
    v_rating_after              number;

    v_cursor                    sys_refcursor;
    v_option_no                 number;
    v_species_type              number;
    v_species_label             varchar2(4000);
    v_probability               number;
    v_phenotype_summary         varchar2(4000);
    v_genotype_summary          varchar2(4000);
    v_source_note               varchar2(100);
    v_row_count                 number;
    v_bad_rows                  number;

    v_failed_tests              number := 0;
    v_passed_tests              number := 0;

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

    PROCEDURE close_preview_cursor IS
    BEGIN
        IF v_cursor%isopen THEN
            close v_cursor;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END close_preview_cursor;

    PROCEDURE cleanup_test_data IS
    BEGIN
        close_preview_cursor;

        BEGIN
            IF v_token1 IS NOT NULL AND v_lab_id1 IS NOT NULL THEN
                pkg_genetics_game.delete_lab(
                    p_session_token => v_token1,
                    p_lab_id        => v_lab_id1
                );
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('[INFO] cleanup lab1 skipped: ' || sqlcode || ' / ' || sqlerrm);
        END;

        BEGIN
            IF v_token2 IS NOT NULL AND v_lab_id2 IS NOT NULL THEN
                pkg_genetics_game.delete_lab(
                    p_session_token => v_token2,
                    p_lab_id        => v_lab_id2
                );
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('[INFO] cleanup lab2 skipped: ' || sqlcode || ' / ' || sqlerrm);
        END;

        BEGIN
            IF v_token1 IS NOT NULL THEN
                pkg_genetics_game.logout_user(v_token1);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('[INFO] cleanup logout1 skipped: ' || sqlcode || ' / ' || sqlerrm);
        END;

        BEGIN
            IF v_token2 IS NOT NULL THEN
                pkg_genetics_game.logout_user(v_token2);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('[INFO] cleanup logout2 skipped: ' || sqlcode || ' / ' || sqlerrm);
        END;
    END cleanup_test_data;

    PROCEDURE fetch_preview_and_assert(
        p_options_count  in number,
        p_expected_rows  in number,
        p_test_prefix    in varchar2
    ) IS
    BEGIN
        v_row_count := 0;
        v_bad_rows := 0;

        v_cursor := pkg_genetics_game.preview_offspring_options(
            p_session_token => v_token1,
            p_lab_id        => v_lab_id1,
            p_parent1_id    => v_parent1_id,
            p_parent2_id    => v_parent2_id,
            p_options_count => p_options_count
        );

        LOOP
            FETCH v_cursor INTO
                v_option_no,
                v_species_type,
                v_species_label,
                v_probability,
                v_phenotype_summary,
                v_genotype_summary,
                v_source_note;
            EXIT WHEN v_cursor%notfound;

            v_row_count := v_row_count + 1;

            IF v_option_no IS NULL
               OR v_species_type IS NULL
               OR v_species_label IS NULL
               OR v_probability IS NULL
               OR v_phenotype_summary IS NULL
               OR v_genotype_summary IS NULL
               OR v_source_note <> 'PREVIEW_ONLY' THEN
                v_bad_rows := v_bad_rows + 1;
            END IF;
        END LOOP;

        close v_cursor;

        assert_true(v_row_count = p_expected_rows, p_test_prefix || ' returns expected row count', 'actual=' || v_row_count || ', expected=' || p_expected_rows);
        assert_true(v_bad_rows = 0, p_test_prefix || ' rows contain required fields', 'bad_rows=' || v_bad_rows);
    EXCEPTION
        WHEN OTHERS THEN
            close_preview_cursor;
            fail_test(p_test_prefix || ' cursor fetch', sqlerrm);
    END fetch_preview_and_assert;
BEGIN
    v_login1 := 'p' || lower(substr(rawtohex(sys_guid()), 1, 12));
    v_login2 := 'q' || lower(substr(rawtohex(sys_guid()), 1, 12));
    v_username1 := 'preview_user_1_' || substr(v_login1, 2, 8);
    v_username2 := 'preview_user_2_' || substr(v_login2, 2, 8);

    dbms_output.put_line('Offspring preview smoke logins: ' || v_login1 || ', ' || v_login2);
    dbms_output.put_line('--- OFFSPRING PREVIEW SMOKE TEST ---');

    BEGIN
        pkg_genetics_game.register_user(v_username1, v_login1, v_password, v_user_id1);
        v_token1 := pkg_genetics_game.login_user(v_login1, v_password);
        pkg_genetics_game.start_new_lab(v_token1, v_lab_id1);
        assert_true(v_token1 IS NOT NULL AND v_lab_id1 IS NOT NULL, 'user1 lab created');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('user1 setup', sqlerrm);
    END;

    BEGIN
        pkg_genetics_game.register_user(v_username2, v_login2, v_password, v_user_id2);
        v_token2 := pkg_genetics_game.login_user(v_login2, v_password);
        pkg_genetics_game.start_new_lab(v_token2, v_lab_id2);
        assert_true(v_token2 IS NOT NULL AND v_lab_id2 IS NOT NULL, 'user2 lab created');
    EXCEPTION
        WHEN OTHERS THEN
            fail_test('user2 setup', sqlerrm);
    END;

    IF v_lab_id1 IS NOT NULL THEN
        BEGIN
            select parent1_id, parent2_id
              into v_parent1_id, v_parent2_id
              from (
                    select c1.creature_id as parent1_id,
                           c2.creature_id as parent2_id
                      from creatures c1
                      join creatures c2
                        on c2.lab_id = c1.lab_id
                       and c2.species_type = c1.species_type
                       and c2.creature_id > c1.creature_id
                     where c1.lab_id = v_lab_id1
                       and exists (
                            select 1
                              from genotypes gp1
                              join genotypes gp2
                                on gp2.gene_id = gp1.gene_id
                               and gp2.creature_id = c2.creature_id
                             where gp1.creature_id = c1.creature_id
                       )
                     order by c1.species_type, c1.creature_id, c2.creature_id
              )
             where rownum = 1;

            assert_true(v_parent1_id IS NOT NULL AND v_parent2_id IS NOT NULL, 'compatible parents selected');
        EXCEPTION
            WHEN OTHERS THEN
                fail_test('compatible parents selected', sqlerrm);
        END;
    END IF;

    IF v_parent1_id IS NOT NULL AND v_parent2_id IS NOT NULL THEN
        select count(*) into v_creatures_before from creatures where lab_id = v_lab_id1;
        select count(*) into v_experiments_before from experiments where lab_id = v_lab_id1;
        select wallet, rating into v_wallet_before, v_rating_before from labs where lab_id = v_lab_id1;

        fetch_preview_and_assert(null, 3, 'default preview');

        select count(*) into v_creatures_after from creatures where lab_id = v_lab_id1;
        select count(*) into v_experiments_after from experiments where lab_id = v_lab_id1;
        select wallet, rating into v_wallet_after, v_rating_after from labs where lab_id = v_lab_id1;

        assert_true(v_creatures_after = v_creatures_before, 'preview does not create creature', 'before=' || v_creatures_before || ', after=' || v_creatures_after);
        assert_true(v_experiments_after = v_experiments_before, 'preview does not create experiment', 'before=' || v_experiments_before || ', after=' || v_experiments_after);
        assert_true(v_wallet_after = v_wallet_before, 'preview does not change wallet', 'before=' || v_wallet_before || ', after=' || v_wallet_after);
        assert_true(v_rating_after = v_rating_before, 'preview does not change rating', 'before=' || v_rating_before || ', after=' || v_rating_after);

        fetch_preview_and_assert(5, 5, 'count=5 preview');
        fetch_preview_and_assert(0, 1, 'count=0 preview clamp');

        BEGIN
            pkg_genetics_game.crossbreed(
                p_lab_id         => v_lab_id1,
                p_parent1_id     => v_parent1_id,
                p_parent2_id     => v_parent2_id,
                p_offspring_name => 'preview_after_cross_' || lower(substr(rawtohex(sys_guid()), 1, 8)),
                p_offspring_id   => v_offspring_id
            );
            assert_true(v_offspring_id IS NOT NULL AND v_offspring_id > 0, 'crossbreed still works after preview');
        EXCEPTION
            WHEN OTHERS THEN
                fail_test('crossbreed still works after preview', sqlerrm);
        END;

        BEGIN
            v_cursor := pkg_genetics_game.preview_offspring_options(
                p_session_token => v_token1,
                p_lab_id        => v_lab_id1,
                p_parent1_id    => v_parent1_id,
                p_parent2_id    => v_parent1_id
            );
            close_preview_cursor;
            fail_test('same parent preview is blocked', 'expected -20032');
        EXCEPTION
            WHEN OTHERS THEN
                close_preview_cursor;
                IF sqlcode = -20032 THEN
                    pass_test('same parent preview is blocked');
                ELSE
                    fail_test('same parent preview is blocked', 'unexpected=' || sqlcode || ' / ' || sqlerrm);
                END IF;
        END;

        BEGIN
            v_cursor := pkg_genetics_game.preview_offspring_options(
                p_session_token => v_token2,
                p_lab_id        => v_lab_id1,
                p_parent1_id    => v_parent1_id,
                p_parent2_id    => v_parent2_id
            );
            close_preview_cursor;
            fail_test('foreign lab preview is blocked', 'foreign access unexpectedly allowed');
        EXCEPTION
            WHEN OTHERS THEN
                close_preview_cursor;
                IF sqlcode in (-20023, -20068, -20069, -20073) THEN
                    pass_test('foreign lab preview is blocked');
                ELSE
                    fail_test('foreign lab preview is blocked', 'unexpected=' || sqlcode || ' / ' || sqlerrm);
                END IF;
        END;
    END IF;

    cleanup_test_data;

    dbms_output.put_line('--- OFFSPRING PREVIEW SUMMARY ---');
    dbms_output.put_line('Passed: ' || v_passed_tests);
    dbms_output.put_line('Failed: ' || v_failed_tests);

    IF v_failed_tests > 0 THEN
        raise_application_error(-20999, 'Offspring preview smoke-test failed. See DBMS_OUTPUT for details.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        dbms_output.put_line('[ERROR] Unhandled exception in offspring preview smoke-test: ' || sqlcode || ' / ' || sqlerrm);
        cleanup_test_data;
        raise;
END;
/
