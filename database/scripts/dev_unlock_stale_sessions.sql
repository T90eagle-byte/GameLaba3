-- ============================================================================
-- DEV ONLY: unlock stale ACTIVE sessions after emergency GUI close
-- ============================================================================
-- Назначение:
--   Только для dev-восстановления, если старая версия GUI была закрыта аварийно
--   и оставила ACTIVE sessions, из-за чего лаборатории блокируются ORA-20072.
--
-- ВАЖНО:
--   - Не является игровым функционалом.
--   - Не удаляет лаборатории и игровые данные.
--   - Закрывает только ACTIVE sessions указанного login.
--
-- Использование:
--   1) Задайте login в переменной v_login ниже.
--   2) Запустите скрипт в SQL Developer / SQLcl / SQL*Plus.

set serveroutput on size unlimited;

begin
    dbms_output.put_line('=== DEV unlock stale sessions: START ===');
end;
/

declare
    v_login users.login%type := 'admin2';
    v_user_id users.user_id%type;
begin
    begin
        select u.user_id
          into v_user_id
          from users u
         where u.login = v_login;
    exception
        when no_data_found then
            dbms_output.put_line('[WARN] Пользователь не найден: ' || v_login);
            return;
    end;

    dbms_output.put_line('[INFO] login=' || v_login || ', user_id=' || v_user_id);

    dbms_output.put_line('--- BEFORE: sessions/labs ---');
    for rec in (
        select
            u.login,
            u.user_id,
            l.lab_id,
            s.session_id,
            s.status,
            s.started_at,
            s.ended_at
          from users u
          left join labs l
            on l.user_id = u.user_id
          left join sessions s
            on s.session_id = l.session_id
         where u.user_id = v_user_id
         order by l.lab_id, s.session_id
    ) loop
        dbms_output.put_line(
            'login=' || rec.login ||
            ', user_id=' || rec.user_id ||
            ', lab_id=' || nvl(to_char(rec.lab_id), 'NULL') ||
            ', session_id=' || nvl(to_char(rec.session_id), 'NULL') ||
            ', status=' || nvl(rec.status, 'NULL') ||
            ', started_at=' || nvl(to_char(rec.started_at, 'YYYY-MM-DD HH24:MI:SS'), 'NULL') ||
            ', ended_at=' || nvl(to_char(rec.ended_at, 'YYYY-MM-DD HH24:MI:SS'), 'NULL')
        );
    end loop;

    update sessions s
       set s.status = 'CLOSED',
           s.ended_at = systimestamp
     where s.user_id = v_user_id
       and s.status = 'ACTIVE';

    dbms_output.put_line('[INFO] CLOSED sessions count=' || sql%rowcount);

    commit;

    dbms_output.put_line('--- AFTER: sessions/labs ---');
    for rec in (
        select
            u.login,
            u.user_id,
            l.lab_id,
            s.session_id,
            s.status,
            s.started_at,
            s.ended_at
          from users u
          left join labs l
            on l.user_id = u.user_id
          left join sessions s
            on s.session_id = l.session_id
         where u.user_id = v_user_id
         order by l.lab_id, s.session_id
    ) loop
        dbms_output.put_line(
            'login=' || rec.login ||
            ', user_id=' || rec.user_id ||
            ', lab_id=' || nvl(to_char(rec.lab_id), 'NULL') ||
            ', session_id=' || nvl(to_char(rec.session_id), 'NULL') ||
            ', status=' || nvl(rec.status, 'NULL') ||
            ', started_at=' || nvl(to_char(rec.started_at, 'YYYY-MM-DD HH24:MI:SS'), 'NULL') ||
            ', ended_at=' || nvl(to_char(rec.ended_at, 'YYYY-MM-DD HH24:MI:SS'), 'NULL')
        );
    end loop;

    dbms_output.put_line('=== DEV unlock stale sessions: DONE ===');
end;
/
