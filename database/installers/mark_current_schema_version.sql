-- Run only after university_readiness_validation.sql has succeeded.
set define off;
set serveroutput on size unlimited;
set verify off;

declare
    v_table_count number;
begin
    select count(*)
      into v_table_count
      from user_tables
     where table_name = 'APP_INSTALL_STATE';

    if v_table_count = 0 then
        execute immediate q'[
            create table app_install_state (
                install_key      varchar2(30 char) not null,
                install_version  number not null,
                installed_at     timestamp default systimestamp not null,
                constraint pk_app_install_state primary key (install_key)
            )
        ]';
    end if;

end;
/

declare
    v_current_version constant number := 14;
begin
    merge into app_install_state target
    using (
        select 'schema' as install_key,
               v_current_version as install_version
          from dual
    ) source
    on (target.install_key = source.install_key)
    when matched then update set
        target.install_version = source.install_version,
        target.installed_at = systimestamp
    when not matched then insert (install_key, install_version, installed_at)
    values (source.install_key, source.install_version, systimestamp);

    commit;
end;
/
