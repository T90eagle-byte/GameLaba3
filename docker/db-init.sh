#!/usr/bin/env bash
set -Eeuo pipefail

ORACLE_HOST="${ORACLE_HOST:-db}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
ORACLE_SERVICE="${ORACLE_SERVICE:-FREEPDB1}"
APP_USER="${ORACLE_USER:-biosborka}"
APP_PASSWORD="${ORACLE_PASSWORD:-}"
SYS_PASSWORD="${ORACLE_SYS_PASSWORD:-}"
CONNECT_TARGET="//${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE}"
SCHEMA_VERSION_FILE="/workspace/database/installers/mark_current_schema_version.sql"
CURRENT_SCHEMA_VERSION="$(sed -nE 's/^[[:space:]]*v_current_version[[:space:]]+constant[[:space:]]+number[[:space:]]*:=[[:space:]]*([0-9]+);[[:space:]]*$/\1/p' "${SCHEMA_VERSION_FILE}")"
INSTALLER_DIR="/workspace/database/installers"

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
[[ "${CURRENT_SCHEMA_VERSION}" =~ ^[0-9]+$ ]] \
    || fail "Cannot read CURRENT_SCHEMA_VERSION from ${SCHEMA_VERSION_FILE}."

cd "${INSTALLER_DIR}"

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
    if ! app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode rollback
@/workspace/database/installers/university_readiness_validation.sql
exit
SQL
    then
        fail "Current v3 schema validation failed. The installation version was not advanced."
    fi
}

apply_current_schema_files() {
    app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode rollback
set define off serveroutput on size unlimited verify off
@/workspace/database/installers/apply_current_schema_update.sql
exit
SQL
}

mark_current_schema_version() {
    app_sqlplus <<'SQL'
whenever sqlerror exit sql.sqlcode rollback
@/workspace/database/installers/mark_current_schema_version.sql
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
        log "Schema is already at version ${CURRENT_SCHEMA_VERSION}; refreshing canonical runtime objects."
        apply_current_schema_files
        validate_schema
        log "Schema is already at version ${CURRENT_SCHEMA_VERSION}, runtime objects were refreshed, and validation passed."
        exit 0
    fi
    log "Upgrading recognized BioSborka schema from version ${install_version} to ${CURRENT_SCHEMA_VERSION}."
    apply_current_schema_files
    validate_schema
    mark_current_schema_version
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
@/workspace/database/installers/apply_current_schema_update.sql
exit
SQL

validate_schema
mark_current_schema_version

log "Schema installation completed successfully at version ${CURRENT_SCHEMA_VERSION}."
