#!/usr/bin/env bash
set -Eeuo pipefail

ORACLE_HOST="${ORACLE_HOST:-db}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
ORACLE_SERVICE="${ORACLE_SERVICE:-FREEPDB1}"
APP_USER="${ORACLE_USER:-biosborka}"
APP_PASSWORD="${ORACLE_PASSWORD:-}"
SYS_PASSWORD="${ORACLE_SYS_PASSWORD:-}"
CONNECT_TARGET="//${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE}"

log() {
    printf '[db-init] %s\n' "$*"
}

fail() {
    printf '[db-init] ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "${APP_USER}" =~ ^[A-Za-z][A-Za-z0-9_]{0,29}$ ]] \
    || fail "ORACLE_USER must start with a letter and contain only letters, digits or underscores."
[[ "${APP_PASSWORD}" =~ ^[A-Za-z0-9_]{12,64}$ ]] \
    || fail "ORACLE_PASSWORD must contain 12-64 Latin letters, digits or underscores."
[[ "${SYS_PASSWORD}" =~ ^[A-Za-z0-9_]{12,64}$ ]] \
    || fail "ORACLE_SYS_PASSWORD must contain 12-64 Latin letters, digits or underscores."

app_sqlplus() {
    {
        printf 'whenever oserror exit failure\nwhenever sqlerror exit sql.sqlcode\n'
        printf 'connect %s/%s@%s\n' "${APP_USER}" "${APP_PASSWORD}" "${CONNECT_TARGET}"
        cat
    } | NLS_LANG=.AL32UTF8 sqlplus -L -s /nolog "$@"
}

sys_sqlplus() {
    {
        printf 'whenever oserror exit failure\nwhenever sqlerror exit sql.sqlcode\n'
        printf 'connect sys/%s@%s as sysdba\n' "${SYS_PASSWORD}" "${CONNECT_TARGET}"
        cat
    } | sqlplus -L -s /nolog "$@"
}

wait_for_sys_login() {
    local attempt
    for attempt in $(seq 1 60); do
        if sys_sqlplus >/dev/null 2>&1 <<'SQL'
set heading off feedback off pagesize 0 verify off echo off
select 1 from dual;
exit
SQL
        then
            return 0
        fi
        sleep 5
    done
    return 1
}

log "Waiting for Oracle credentials and FREEPDB1 to become ready."
wait_for_sys_login \
    || fail "Oracle did not accept the configured SYS password within 5 minutes. Check ORACLE_SYS_PASSWORD and the volume."

log "Checking schema state at ${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE}."
if ready_output="$(app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off
select '__BIOSBORKA_READY__'
  from app_install_state
 where install_key = 'schema'
   and install_version = 1
   and exists (
       select 1
         from user_objects
        where object_name = 'PKG_GENETICS_GAME'
          and object_type = 'PACKAGE BODY'
          and status = 'VALID'
   );
exit
SQL
)" && grep -q '__BIOSBORKA_READY__' <<<"${ready_output}"; then
    log "Schema is already initialized; no SQL files were reapplied."
    exit 0
fi

if ! user_count="$(sys_sqlplus 2>&1 <<SQL
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off
select count(*) from dba_users where username = upper('${APP_USER}');
exit
SQL
)"; then
    fail "Cannot connect as SYS. Check ORACLE_SYS_PASSWORD and the existing volume. ${user_count}"
fi
user_count="$(tr -d '[:space:]' <<<"${user_count}")"

if [[ "${user_count}" == "1" ]]; then
    if ! app_sqlplus <<<'exit' >/dev/null 2>&1; then
        fail "Schema user exists but ORACLE_PASSWORD does not match the persisted database. Restore the original .env or run reset-game.cmd."
    fi
    log "Removing an incomplete schema installation before a clean retry."
fi

sys_sqlplus <<SQL
whenever sqlerror exit sql.sqlcode
set serveroutput on verify off
declare
    v_count number;
begin
    select count(*) into v_count from dba_users where username = upper('${APP_USER}');
    if v_count > 0 then
        execute immediate 'drop user ${APP_USER} cascade';
    end if;
end;
/
create user ${APP_USER} identified by "${APP_PASSWORD}";
grant create session, create table, create sequence, create procedure, create trigger, create view to ${APP_USER};
grant unlimited tablespace to ${APP_USER};
exit
SQL

log "Installing tables, migrations, seed data and package."
app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode rollback
set define off serveroutput on size unlimited verify off
@/workspace/database/ddl/01_create_tables.sql
@/workspace/database/migrations/01_release_lab_session_bindings.sql
@/workspace/database/migrations/02_add_lab_names.sql
@/workspace/database/seeds/01_seed_core_game_data.sql
@/workspace/database/packages/spec/pkg_genetics_game.pks
@/workspace/database/packages/body/pkg_genetics_game.pkb

create table app_install_state (
    install_key      varchar2(30 char) not null,
    install_version  number not null,
    installed_at     timestamp default systimestamp not null,
    constraint pk_app_install_state primary key (install_key)
);

insert into app_install_state (install_key, install_version)
values ('schema', 1);

commit;
exit
SQL

validation="$(app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off
select count(*)
  from user_objects
 where object_name = 'PKG_GENETICS_GAME'
   and object_type in ('PACKAGE', 'PACKAGE BODY')
   and status = 'VALID';
select count(*) from user_errors where name = 'PKG_GENETICS_GAME';
exit
SQL
)"
validation="$(sed '/^[[:space:]]*$/d' <<<"${validation}")"
valid_count="$(sed -n '1p' <<<"${validation}" | tr -d '[:space:]')"
error_count="$(sed -n '2p' <<<"${validation}" | tr -d '[:space:]')"
[[ "${valid_count}" == "2" && "${error_count}" == "0" ]] \
    || fail "Package validation failed (valid objects=${valid_count}, user_errors=${error_count})."

log "Schema installation completed successfully."
