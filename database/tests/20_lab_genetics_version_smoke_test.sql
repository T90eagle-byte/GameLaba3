-- Validates the explicit legacy/v3 laboratory boundary without backfilling creatures.
-- The test creates one pre-migration laboratory and removes only its own data.

@@../packages/spec/pkg_genetics_game.pks
@@../migrations/04_add_creature_archetypes.sql
@@../migrations/05_add_universal_morphology.sql
@@../migrations/06_add_archetype_templates.sql
@@../migrations/07_add_creature_archetype.sql
@@../migrations/08_add_allele_display_names.sql

set serveroutput on size unlimited;
set verify off;

declare
    v_user_id          number;
    v_lab_id           number;
    v_creature_id      number;
    v_session_token    varchar2(128);
    v_login            varchar2(20) := 'v' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password         varchar2(100) := 'genetics_version_123';
    v_lab_count        number;
    v_creature_count   number;
    v_genotype_count   number;
    v_fingerprint      number;
    v_version_column_count number;
    v_existing_v3_count    number;
begin
    select count(*)
      into v_version_column_count
      from user_tab_columns
     where table_name = 'LABS'
       and column_name = 'GENETICS_VERSION';

    if v_version_column_count = 1 then
        select count(*) into v_existing_v3_count from labs where genetics_version = 3;
    else
        v_existing_v3_count := 0;
    end if;

    pkg_genetics_game.register_user('Pre-migration version smoke', v_login, v_password, v_user_id);
    v_session_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.start_new_lab(v_session_token, v_lab_id);

    if v_version_column_count = 1 then
        -- A rerun against an already-upgraded schema uses an explicit legacy
        -- fixture; this preserves the real pre-09 backfill test on a fresh schema.
        update labs
           set genetics_version = 1
         where lab_id = v_lab_id;
    end if;

    select min(creature_id)
      into v_creature_id
      from creatures
     where lab_id = v_lab_id;

    select count(*) into v_lab_count from labs;
    select count(*) into v_creature_count from creatures;
    select count(*) into v_genotype_count from genotypes;
    select ora_hash(
               c.creature_id || '|' || c.lab_id || '|' || c.species_type || '|' ||
               nvl(to_char(c.archetype_id), '<null>') || '|' || c.creature_name || '|' ||
               nvl(c.phenotype_summary, '<null>')
           )
      into v_fingerprint
      from creatures c
     where c.creature_id = v_creature_id;

    dbms_application_info.set_client_info(
        'v20:' || v_lab_id || ':' || v_creature_id || ':' || v_lab_count || ':' ||
        v_creature_count || ':' || v_genotype_count || ':' || v_fingerprint || ':' ||
        v_version_column_count || ':' || v_existing_v3_count
    );

    pkg_genetics_game.exit_lab(v_lab_id);
    pkg_genetics_game.logout_user(v_session_token);
    commit;
end;
/

@@../migrations/09_add_lab_genetics_version.sql

begin
    dbms_session.reset_package;
end;
/

begin
    dbms_output.enable(null);
end;
/

declare
    v_failed_tests         number := 0;
    v_passed_tests         number := 0;
    v_value                number;
    v_snapshot             varchar2(64);
    v_pre_lab_id           number;
    v_pre_creature_id      number;
    v_pre_lab_count        number;
    v_pre_creature_count   number;
    v_pre_genotype_count   number;
    v_pre_fingerprint      number;
    v_pre_version_column_count number;
    v_pre_existing_v3_count    number;
    v_user_id              number;
    v_login                varchar2(100);
    v_password             varchar2(100) := 'genetics_version_123';
    v_session_token        varchar2(128);
    v_new_lab_id           number;
    v_legacy_lab_id        number;
    v_error_code           number;
    v_fingerprint          number;

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

    procedure assert_rejected_version(p_version in number, p_expected_code in number, p_test_name in varchar2) is
        v_attempt_lab_id number;
    begin
        savepoint invalid_version;
        begin
            v_attempt_lab_id := labs_seq.nextval;
            insert into labs (lab_id, user_id, lab_name, genetics_version)
            values (v_attempt_lab_id, v_user_id, 'Invalid version fixture', p_version);
            fail_test(p_test_name, 'insert unexpectedly succeeded');
            rollback to invalid_version;
        exception
            when others then
                v_error_code := sqlcode;
                rollback to invalid_version;
                assert_true(v_error_code = p_expected_code, p_test_name, 'sqlcode=' || v_error_code);
        end;
    end assert_rejected_version;

begin
    v_snapshot := sys_context('USERENV', 'CLIENT_INFO');
    v_pre_lab_id := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 2));
    v_pre_creature_id := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 3));
    v_pre_lab_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 4));
    v_pre_creature_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 5));
    v_pre_genotype_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 6));
    v_pre_fingerprint := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 7));
    v_pre_version_column_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 8));
    v_pre_existing_v3_count := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 9));

    dbms_output.put_line('--- LAB GENETICS VERSION SMOKE TEST ---');

    select count(*)
      into v_value
      from user_tab_columns
     where table_name = 'LABS'
       and column_name = 'GENETICS_VERSION'
       and data_type = 'NUMBER'
       and data_precision = 2
       and nullable = 'N';
    assert_true(v_value = 1, 'LABS.GENETICS_VERSION is NUMBER(2) NOT NULL');

    select count(*)
      into v_value
      from user_constraints
     where table_name = 'LABS'
       and constraint_name = 'CK_LABS_GENETICS_VERSION'
       and constraint_type = 'C'
       and status = 'ENABLED';
    assert_true(v_value = 1, 'GENETICS_VERSION check constraint is enabled');

    if v_pre_version_column_count = 0 then
        select count(*) into v_value from labs where genetics_version = 1;
        assert_true(v_value = v_pre_lab_count, 'All pre-migration labs are legacy v1', 'actual=' || v_value);
    else
        select count(*) into v_value from labs where genetics_version = 3;
        assert_true(v_value = v_pre_existing_v3_count, 'Rerun migration preserves existing v3 labs', 'actual=' || v_value);
    end if;

    select genetics_version into v_value from labs where lab_id = v_pre_lab_id;
    assert_true(v_value = 1, 'Pre-migration laboratory is marked v1');

    select count(*) into v_value from creatures;
    assert_true(v_value = v_pre_creature_count, 'Migration preserves CREATURES count', 'actual=' || v_value);

    select count(*) into v_value from genotypes;
    assert_true(v_value = v_pre_genotype_count, 'Migration preserves GENOTYPES count', 'actual=' || v_value);

    select ora_hash(
               c.creature_id || '|' || c.lab_id || '|' || c.species_type || '|' ||
               nvl(to_char(c.archetype_id), '<null>') || '|' || c.creature_name || '|' ||
               nvl(c.phenotype_summary, '<null>')
           )
      into v_fingerprint
      from creatures c
     where c.creature_id = v_pre_creature_id;
    assert_true(v_fingerprint = v_pre_fingerprint, 'Historical creature data remains unchanged');

    select u.user_id, u.login
      into v_user_id, v_login
      from users u
      join labs l on l.user_id = u.user_id
     where l.lab_id = v_pre_lab_id;

    v_session_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.start_new_lab(v_session_token, v_new_lab_id);

    select genetics_version into v_value from labs where lab_id = v_new_lab_id;
    assert_true(v_value = 3, 'New package-created laboratory receives default v3');

    select count(*)
      into v_value
      from creatures
     where lab_id = v_new_lab_id
       and archetype_id is not null;
    assert_true(v_value = 30, 'V3 laboratory starters have archetype_id', 'actual=' || v_value);

    select count(*)
      into v_value
      from (
            select c.creature_id
              from creatures c
              left join genotypes gt
                on gt.creature_id = c.creature_id
              left join genes g
                on g.gene_id = gt.gene_id
               and g.species_type = 0
               and g.gene_type = 'morphology'
               and g.gameplay_enabled = 'N'
             where c.lab_id = v_new_lab_id
             group by c.creature_id
            having count(g.gene_id) <> 18
      );
    assert_true(v_value = 0, 'Every V3 starter has 18 hidden morphology genes', 'mismatches=' || v_value);

    v_legacy_lab_id := labs_seq.nextval;
    insert into labs (lab_id, user_id, lab_name, genetics_version)
    values (v_legacy_lab_id, v_user_id, 'Legacy version fixture', 1);
    assert_true(true, 'Explicit legacy v1 laboratory exists');

    pkg_genetics_game.load_lab(v_session_token, v_legacy_lab_id);
    begin
        pkg_genetics_game.generate_starting_creatures(v_legacy_lab_id);
        fail_test('Legacy lab cannot materialize v3 starters', 'generation unexpectedly succeeded');
    exception
        when others then
            v_error_code := sqlcode;
            assert_true(v_error_code = -20084, 'Legacy lab cannot materialize v3 starters', 'sqlcode=' || v_error_code);
    end;

    select count(*) into v_value from creatures where lab_id = v_legacy_lab_id;
    assert_true(v_value = 0, 'Rejected legacy generation creates no creatures');
    pkg_genetics_game.exit_lab(v_legacy_lab_id);

    assert_rejected_version(2, -2290, 'GENETICS_VERSION=2 is rejected');
    assert_rejected_version(null, -1400, 'GENETICS_VERSION=NULL is rejected');

    commit;

    if v_failed_tests > 0 then
        raise_application_error(-20990, 'Lab genetics-version smoke test failed before idempotency check: ' || v_failed_tests);
    end if;
end;
/

@@../migrations/09_add_lab_genetics_version.sql

begin
    dbms_session.reset_package;
end;
/

begin
    dbms_output.enable(null);
end;
/

declare
    v_failed_tests      number := 0;
    v_passed_tests      number := 0;
    v_snapshot          varchar2(64);
    v_pre_lab_id        number;
    v_user_id           number;
    v_login             varchar2(100);
    v_password          varchar2(100) := 'genetics_version_123';
    v_session_token     varchar2(128);
    v_new_lab_id        number;
    v_legacy_lab_id     number;
    v_value             number;

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

begin
    v_snapshot := sys_context('USERENV', 'CLIENT_INFO');
    v_pre_lab_id := to_number(regexp_substr(v_snapshot, '[^:]+', 1, 2));

    select u.user_id, u.login
      into v_user_id, v_login
      from users u
      join labs l on l.user_id = u.user_id
     where l.lab_id = v_pre_lab_id;

    select min(lab_id)
      into v_new_lab_id
      from labs
     where user_id = v_user_id
       and genetics_version = 3;

    select min(lab_id)
      into v_legacy_lab_id
      from labs
     where user_id = v_user_id
       and lab_name = 'Legacy version fixture';

    dbms_output.put_line('--- LAB GENETICS VERSION IDEMPOTENCY ---');

    select genetics_version into v_value from labs where lab_id = v_pre_lab_id;
    assert_true(v_value = 1, 'Repeated migration preserves legacy v1');

    select genetics_version into v_value from labs where lab_id = v_new_lab_id;
    assert_true(v_value = 3, 'Repeated migration preserves v3 laboratory');

    select count(*)
      into v_value
      from user_objects
     where object_name = 'PKG_GENETICS_GAME'
       and object_type in ('PACKAGE', 'PACKAGE BODY')
       and status = 'VALID';
    assert_true(v_value = 2, 'Package specification and body remain valid', 'actual=' || v_value);

    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME';
    assert_true(v_value = 0, 'Package user_errors remain clean', 'actual=' || v_value);

    v_session_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.delete_lab(v_session_token, v_legacy_lab_id);
    pkg_genetics_game.delete_lab(v_session_token, v_new_lab_id);
    pkg_genetics_game.delete_lab(v_session_token, v_pre_lab_id);
    pkg_genetics_game.logout_user(v_session_token);

    delete from sessions where user_id = v_user_id;
    delete from users where user_id = v_user_id;
    commit;

    dbms_output.put_line('Passed: ' || v_passed_tests || ', Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20990, 'Lab genetics-version smoke test failed: ' || v_failed_tests);
    end if;
exception
    when others then
        begin
            if v_user_id is not null then
                delete from rating_events where lab_id in (select lab_id from labs where user_id = v_user_id);
                delete from genotypes where creature_id in (select creature_id from creatures where lab_id in (select lab_id from labs where user_id = v_user_id));
                delete from experiments where lab_id in (select lab_id from labs where user_id = v_user_id);
                delete from lab_tasks where lab_id in (select lab_id from labs where user_id = v_user_id);
                delete from lab_mutations where lab_id in (select lab_id from labs where user_id = v_user_id);
                delete from creatures where lab_id in (select lab_id from labs where user_id = v_user_id);
                delete from labs where user_id = v_user_id;
                delete from sessions where user_id = v_user_id;
                delete from users where user_id = v_user_id;
                commit;
            end if;
        exception
            when others then
                null;
        end;
        raise;
end;
/
