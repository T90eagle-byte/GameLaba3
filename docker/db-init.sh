#!/usr/bin/env bash
set -Eeuo pipefail

ORACLE_HOST="${ORACLE_HOST:-db}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
ORACLE_SERVICE="${ORACLE_SERVICE:-FREEPDB1}"
APP_USER="${ORACLE_USER:-biosborka}"
APP_PASSWORD="${ORACLE_PASSWORD:-}"
SYS_PASSWORD="${ORACLE_SYS_PASSWORD:-}"
CONNECT_TARGET="//${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE}"
CURRENT_SCHEMA_VERSION=2

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

validate_schema() {
    local validation_output validation_line
    if ! validation_output="$(app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off
select
    (select count(*)
       from user_objects
      where object_name = 'PKG_GENETICS_GAME'
        and object_type in ('PACKAGE', 'PACKAGE BODY')
        and status = 'VALID') || ':' ||
    (select count(*)
       from user_errors
      where name = 'PKG_GENETICS_GAME'
        and type in ('PACKAGE', 'PACKAGE BODY')) || ':' ||
    (select count(*)
       from user_procedures
      where object_name = 'PKG_GENETICS_GAME'
        and procedure_name = 'RECOVER_LAB_ACCESS') || ':' ||
    (select count(*)
       from tasks
      where description is null
         or instr(lower(description), 'носительств') = 0) || ':' ||
    (select count(*)
       from mutations m
      where not exists (
          select 1 from mutation_rules mr where mr.mutation_id = m.mutation_id
      )) || ':' ||
    (select count(*)
       from tasks t
      where not exists (
          select 1 from task_markers tm where tm.task_id = t.task_id
      ))
  from dual;
exit
SQL
)"; then
        fail "Schema validation query failed. The installation was not marked as current."
    fi

    validation_line="$(sed '/^[[:space:]]*$/d' <<<"${validation_output}" | tail -n 1 | tr -d '[:space:]')"
    if [[ ! "${validation_line}" =~ ^[0-9]+:[0-9]+:[0-9]+:[0-9]+:[0-9]+:[0-9]+$ ]]; then
        fail "Schema validation returned an unexpected result. The installation was not marked as current."
    fi

    IFS=':' read -r valid_count error_count recovery_count legacy_task_count mutation_rule_gap task_marker_gap <<<"${validation_line}"
    [[ "${valid_count}" == "2" && "${error_count}" == "0" && "${recovery_count}" == "1" \
        && "${legacy_task_count}" == "0" && "${mutation_rule_gap}" == "0" && "${task_marker_gap}" == "0" ]] \
        || fail "Schema validation failed (valid=${valid_count}, errors=${error_count}, recover_lab_access=${recovery_count}, legacy_tasks=${legacy_task_count}, mutation_rule_gaps=${mutation_rule_gap}, task_marker_gaps=${task_marker_gap})."
}

apply_current_schema_files() {
    app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode rollback
set define off serveroutput on size unlimited verify off
@/workspace/database/migrations/01_release_lab_session_bindings.sql
@/workspace/database/migrations/02_add_lab_names.sql
@/workspace/database/seeds/01_seed_core_game_data.sql
@/workspace/database/migrations/03_align_task_requirement_descriptions.sql
@/workspace/database/packages/spec/pkg_genetics_game.pks
@/workspace/database/packages/body/pkg_genetics_game.pkb
exit
SQL
}

log "Waiting for Oracle credentials and FREEPDB1 to become ready."
wait_for_sys_login \
    || fail "Oracle did not accept the configured SYS password within 5 minutes. Check ORACLE_SYS_PASSWORD and the volume."

log "Checking schema state at ${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE}."
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
        fail "Schema user exists but ORACLE_PASSWORD does not match the persisted database. Restore the original .env. Refusing to modify the existing schema."
    fi

    if ! marker_output="$(app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off
select to_char(install_version)
  from app_install_state
 where install_key = 'schema';
exit
SQL
)"; then
        fail "Schema user exists but the BioSborka install marker is missing or unreadable. Refusing to alter or delete an existing schema."
    fi
    install_version="$(sed '/^[[:space:]]*$/d' <<<"${marker_output}" | tail -n 1 | tr -d '[:space:]')"
    [[ "${install_version}" =~ ^[0-9]+$ ]] \
        || fail "Schema user exists but the BioSborka install version is invalid. Refusing to alter or delete an existing schema."

    if (( install_version > CURRENT_SCHEMA_VERSION )); then
        fail "Schema install version ${install_version} is newer than supported version ${CURRENT_SCHEMA_VERSION}. Refusing to alter the existing schema."
    fi
    if (( install_version == CURRENT_SCHEMA_VERSION )); then
        validate_schema
        log "Schema is already at version ${CURRENT_SCHEMA_VERSION} and passed validation."
        exit 0
    fi
    if (( install_version != 1 )); then
        fail "Schema install version ${install_version} has no supported upgrade path. Refusing to alter the existing schema."
    fi

    log "Upgrading recognized BioSborka schema from version ${install_version} to ${CURRENT_SCHEMA_VERSION}."
    apply_current_schema_files
    validate_schema
    app_sqlplus <<SQL
whenever sqlerror exit sql.sqlcode rollback
update app_install_state
   set install_version = ${CURRENT_SCHEMA_VERSION},
       installed_at = systimestamp
 where install_key = 'schema'
   and install_version = ${install_version};

declare
    v_updated number := sql%rowcount;
begin
    if v_updated <> 1 then
        raise_application_error(-20991, 'Install version marker changed during upgrade.');
    end if;
end;
/
commit;
exit
SQL
    log "Schema upgrade to version ${CURRENT_SCHEMA_VERSION} completed successfully."
    exit 0
fi

sys_sqlplus <<SQL
whenever sqlerror exit sql.sqlcode
set serveroutput on verify off
create user ${APP_USER} identified by "${APP_PASSWORD}";
grant create session, create table, create sequence, create procedure, create trigger, create view to ${APP_USER};
grant unlimited tablespace to ${APP_USER};
exit
SQL

log "Installing tables, migrations, seed data and package at version ${CURRENT_SCHEMA_VERSION}."
app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode rollback
set define off serveroutput on size unlimited verify off
@/workspace/database/ddl/01_create_tables.sql
@/workspace/database/migrations/01_release_lab_session_bindings.sql
@/workspace/database/migrations/02_add_lab_names.sql
@/workspace/database/seeds/01_seed_core_game_data.sql
@/workspace/database/migrations/03_align_task_requirement_descriptions.sql
@/workspace/database/packages/spec/pkg_genetics_game.pks
@/workspace/database/packages/body/pkg_genetics_game.pkb

create table app_install_state (
    install_key      varchar2(30 char) not null,
    install_version  number not null,
    installed_at     timestamp default systimestamp not null,
    constraint pk_app_install_state primary key (install_key)
);

insert into app_install_state (install_key, install_version)
values ('schema', 2);

commit;
exit
SQL

validate_schema

log "Schema installation completed successfully at version ${CURRENT_SCHEMA_VERSION}."
