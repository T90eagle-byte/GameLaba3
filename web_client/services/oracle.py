from __future__ import annotations

from collections.abc import Callable
from typing import Any, TypeVar

import oracledb

from config import OracleSettings, load_config


T = TypeVar("T")


class ServiceError(RuntimeError):
    """User-facing service error safe to show in templates."""


def make_dsn(settings: OracleSettings) -> str:
    dsn_kwargs: dict[str, object] = {"host": settings.host, "port": settings.port}
    if settings.service_name:
        dsn_kwargs["service_name"] = settings.service_name
    else:
        dsn_kwargs["sid"] = settings.sid
    return oracledb.makedsn(**dsn_kwargs)


def get_connection() -> oracledb.Connection:
    settings = load_config().oracle
    if not settings.password:
        raise ServiceError("Пароль Oracle не задан. Проверьте python_client/.env.")
    if not settings.service_name and not settings.sid:
        raise ServiceError("В .env должен быть задан ORACLE_SERVICE или ORACLE_SID.")

    connection = oracledb.connect(
        user=settings.user,
        password=settings.password,
        dsn=make_dsn(settings),
    )
    connection.autocommit = True
    return connection


def check_connection() -> dict[str, Any]:
    try:
        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("select 1 from dual")
                value = cursor.fetchone()[0]
        return {"ok": value == 1, "message": "Oracle доступен"}
    except Exception as exc:  # noqa: BLE001 - convert to user-safe health result
        return {"ok": False, "message": map_oracle_error(exc)}


def rows_from_refcursor(ref_cursor: oracledb.Cursor) -> list[dict[str, Any]]:
    columns = [desc[0].lower() for desc in ref_cursor.description or []]
    return [dict(zip(columns, row)) for row in ref_cursor.fetchall()]


def run_db(action: Callable[[oracledb.Connection], T]) -> T:
    try:
        with get_connection() as connection:
            return action(connection)
    except ServiceError:
        raise
    except Exception as exc:  # noqa: BLE001 - display-layer mapping
        raise ServiceError(map_oracle_error(exc)) from exc


def map_oracle_error(exc: Exception) -> str:
    if isinstance(exc, oracledb.DatabaseError):
        payload = exc.args[0]
        code = getattr(payload, "code", None)
        message = getattr(payload, "message", str(exc))
        normalized_code: int | None = None
        if code is not None:
            try:
                normalized_code = -abs(int(code))
            except (TypeError, ValueError):
                normalized_code = None

        custom = {
            -1017: "Неверный логин или пароль для подключения к Oracle.",
            -12154: "Не удалось разрешить адрес Oracle. Проверьте host/service.",
            -12514: "Сервис Oracle не найден. Проверьте ORACLE_SERVICE.",
            -12541: "Нет соединения с Oracle Listener. Проверьте host/port и доступность БД.",
            -20003: "Некорректный формат логина.",
            -20004: "Пароль не может быть пустым.",
            -20005: "Пользователь с таким логином уже существует.",
            -20020: "Сессия не активна. Выполните вход заново.",
            -20021: "Сессия уже закрыта или не найдена.",
            -20023: "Лаборатория не найдена или доступ запрещен.",
            -20024: "Лаборатория не найдена.",
            -20025: "Лаборатория не найдена или доступ запрещен.",
            -20031: "Выберите двух родителей для скрещивания.",
            -20032: "Для скрещивания нужны два разных существа.",
            -20033: "Введите имя потомка.",
            -20034: "Первый родитель не найден в выбранной лаборатории.",
            -20035: "Второй родитель не найден в выбранной лаборатории.",
            -20036: "Эти родители несовместимы: в текущей версии скрещиваются только существа одного вида.",
            -20037: "У родителей нет общих генов для скрещивания.",
            -20041: "Мутация не найдена.",
            -20043: "Эта мутация не куплена для текущей лаборатории.",
            -20044: "Запас выбранной мутации равен нулю.",
            -20045: "Существо несовместимо с правилом выбранной мутации.",
            -20046: "Для выбранной мутации не найдены правила применения.",
            -20047: "Не удалось списать мутацию из инвентаря лаборатории.",
            -20048: "Тип мутагена не задан.",
            -20049: "Исходное существо для мутагена не найдено.",
            -20050: "У исходного существа нет генотипа для мутагена.",
            -20051: "Не удалось выбрать ген для химического мутагена.",
            -20056: "Мутация не найдена.",
            -20057: "Лаборатория не найдена.",
            -20063: "Существо не подходит под требования заказа. Выберите другое существо или сначала получите нужные признаки через скрещивание/мутации.",
            -20070: "Поддерживаются только мутагены RADIATION и CHEMICAL.",
            -20071: "Недостаточно средств для выбранного мутагена.",
            -20066: "Контекст сессии не инициализирован. Выполните вход.",
            -20067: "Сессия истекла. Выполните вход заново.",
            -20068: "Нет доступа к выбранной лаборатории.",
            -20072: "Лаборатория уже открыта в другой сессии. Закройте активную лабораторию или продолжите работу с уже открытой.",
            -20073: "Выбранная лаборатория не активна в текущей сессии.",
        }
        for lookup_code in (normalized_code, code):
            if lookup_code in custom:
                return custom[lookup_code]

        return "Произошла ошибка базы данных. Действие не выполнено; проверьте выбранные данные и попробуйте ещё раз."

    text = str(exc).strip()
    return text or "Произошла непредвиденная ошибка."
