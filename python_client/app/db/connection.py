from __future__ import annotations

import oracledb

from app.config import OracleConfig


def create_connection(config: OracleConfig) -> oracledb.Connection:
    dsn = oracledb.makedsn(config.host, config.port, service_name=config.service)
    connection = oracledb.connect(
        user=config.user,
        password=config.password,
        dsn=dsn,
    )
    connection.autocommit = True

    with connection.cursor() as cursor:
        cursor.execute("select 1 from dual")
        cursor.fetchone()

    return connection


def close_connection(connection: oracledb.Connection | None) -> None:
    if connection is None:
        return

    try:
        connection.close()
    except oracledb.Error:
        pass