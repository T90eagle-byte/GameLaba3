-- Проверяет курсор морфологии лаборатории только для чтения, используемый карточками v3.
-- Тест создаёт и удаляет только собственные временные лабораторию и пользователя.

set serveroutput on size unlimited;
set verify off;

declare
    v_failed_tests number := 0;
    v_passed_tests number := 0;
    v_user_id number;
    v_lab_id number;
    v_token varchar2(128);
    v_cleanup_token varchar2(128);
    v_login varchar2(30) := 'r' || lower(substr(rawtohex(sys_guid()), 1, 19));
    v_password varchar2(100) := 'renderer_read_model_123';
    v_parent1 number;
    v_parent2 number;
    v_offspring number;
    v_cursor sys_refcursor;
    v_creature_id number;
    v_gene_code varchar2(50);
    v_gene_display varchar2(255);
    v_allele1 varchar2(255);
    v_allele2 varchar2(255);
    v_expressed varchar2(4000);
    v_allele1_display varchar2(255);
    v_allele2_display varchar2(255);
    v_expressed_display varchar2(4000);
    v_rows number := 0;
    v_value number;

    procedure assert_true(p_condition boolean, p_name varchar2, p_detail varchar2 default null) is
    begin
        if p_condition then
            v_passed_tests := v_passed_tests + 1;
            dbms_output.put_line('[PASS] ' || p_name || case when p_detail is null then '' else ' -> ' || p_detail end);
        else
            v_failed_tests := v_failed_tests + 1;
            dbms_output.put_line('[FAIL] ' || p_name || case when p_detail is null then '' else ' -> ' || p_detail end);
        end if;
    end;

    procedure close_cursor is
    begin
        if v_cursor%isopen then
            close v_cursor;
        end if;
    exception when others then null;
    end;

    procedure cleanup is
    begin
        close_cursor;
        if v_lab_id is not null then
            begin
                -- Повторная аутентификация нужна, поскольку неуспешный тест может оставить
                -- этот анонимный блок после сброса состояния пакета. Восстановление
                -- ограничено только лабораторией тестовых данных.
                v_cleanup_token := pkg_genetics_game.login_user(v_login, v_password);
                pkg_genetics_game.recover_lab_access(v_cleanup_token, v_lab_id);
                pkg_genetics_game.delete_lab(v_cleanup_token, v_lab_id);
            exception when others then
                dbms_output.put_line('[WARN] cleanup lab: ' || sqlcode || ' / ' || sqlerrm);
            end;
        end if;
        delete from sessions where user_id = v_user_id or user_id in (select user_id from users where login = v_login);
        delete from users where user_id = v_user_id or login = v_login;
    exception when others then
        dbms_output.put_line('[WARN] cleanup user: ' || sqlcode || ' / ' || sqlerrm);
    end;
begin
    dbms_output.put_line('--- MORPHOLOGY RENDER READ-MODEL SMOKE TEST ---');
    pkg_genetics_game.register_user('Morphology renderer smoke', v_login, v_password, v_user_id);
    v_token := pkg_genetics_game.login_user(v_login, v_password);
    pkg_genetics_game.start_new_lab(v_token, 'Renderer read-model fixture', v_lab_id);

    select count(*) into v_value from labs where lab_id = v_lab_id and genetics_version = 3;
    assert_true(v_value = 1, 'Fixture laboratory uses v3 genetics');
    select count(*) into v_value from creatures where lab_id = v_lab_id;
    assert_true(v_value = 30, 'Fixture creates 30 starters', 'actual=' || v_value);
    select count(distinct species_type) into v_value from creatures where lab_id = v_lab_id;
    assert_true(v_value = 6, 'Fixture covers all six starter species', 'actual=' || v_value);

    v_cursor := pkg_genetics_game.get_lab_morphology_cursor(v_lab_id);
    loop
        fetch v_cursor into v_creature_id, v_gene_code, v_gene_display, v_allele1, v_allele2,
              v_expressed, v_allele1_display, v_allele2_display, v_expressed_display;
        exit when v_cursor%notfound;
        v_rows := v_rows + 1;
    end loop;
    close_cursor;
    assert_true(v_rows = 540, 'One batch cursor returns 30 x 18 morphology rows', 'actual=' || v_rows);
    select count(*) into v_value from (
        select creature_id from genotypes gt join genes g on g.gene_id = gt.gene_id
         where gt.creature_id in (select creature_id from creatures where lab_id = v_lab_id)
           and g.gene_type = 'morphology'
           and g.species_type = 0
         group by creature_id having count(*) <> 18
    );
    assert_true(v_value = 0, 'Every rendered starter has exactly 18 morphology traits', 'mismatches=' || v_value);

    select min(creature_id) into v_parent1 from creatures where lab_id = v_lab_id and species_type = 3;
    select min(creature_id) into v_parent2 from creatures where lab_id = v_lab_id and species_type = 3 and creature_id > v_parent1;
    pkg_genetics_game.crossbreed(v_lab_id, v_parent1, v_parent2, 'Renderer offspring', v_offspring);
    select count(*) into v_value from creatures where creature_id = v_offspring and archetype_id is null;
    assert_true(v_value = 1, 'Crossbred offspring has no archetype');
    select count(*) into v_value from genotypes gt join genes g on g.gene_id = gt.gene_id where gt.creature_id = v_offspring and g.gene_type = 'morphology' and g.species_type = 0;
    assert_true(v_value = 18, 'Archetype-free offspring retains 18 morphology rows', 'actual=' || v_value);

    v_rows := 0;
    v_cursor := pkg_genetics_game.get_lab_morphology_cursor(v_lab_id);
    loop
        fetch v_cursor into v_creature_id, v_gene_code, v_gene_display, v_allele1, v_allele2,
              v_expressed, v_allele1_display, v_allele2_display, v_expressed_display;
        exit when v_cursor%notfound;
        v_rows := v_rows + 1;
    end loop;
    close_cursor;
    assert_true(v_rows = 558, 'Batch cursor includes archetype-free offspring', 'actual=' || v_rows);

    select count(*) into v_value from user_objects where object_name = 'PKG_GENETICS_GAME' and object_type in ('PACKAGE', 'PACKAGE BODY') and status = 'VALID';
    assert_true(v_value = 2, 'Package and body remain VALID', 'actual=' || v_value);
    select count(*) into v_value from user_errors where name = 'PKG_GENETICS_GAME' and type in ('PACKAGE', 'PACKAGE BODY');
    assert_true(v_value = 0, 'Package USER_ERRORS remain clean', 'actual=' || v_value);
    cleanup;
    commit;
    dbms_output.put_line('Passed: ' || v_passed_tests || ', Failed: ' || v_failed_tests);
    if v_failed_tests > 0 then
        raise_application_error(-20991, 'Morphology render read-model smoke test had ' || v_failed_tests || ' failure(s).');
    end if;
exception when others then
    cleanup;
    rollback;
    raise;
end;
/
