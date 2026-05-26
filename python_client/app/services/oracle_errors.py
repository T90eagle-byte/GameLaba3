from __future__ import annotations

import oracledb


def map_oracle_error(exc: Exception) -> str:
    if isinstance(exc, oracledb.DatabaseError):
        payload = exc.args[0]
        code = getattr(payload, "code", None)
        message = getattr(payload, "message", str(exc))

        custom = {
            -20003: "Invalid login format.",
            -20004: "Password cannot be empty.",
            -20005: "Login already exists.",
            -20020: "Session is not active. Please login again.",
            -20021: "Session already closed or not found.",
            -20023: "Lab not found or access denied.",
            -20024: "Lab not found.",
            -20025: "Lab not found or access denied.",
            -20057: "Lab not found.",
            -20058: "Task not found.",
            -20059: "Creature not found.",
            -20060: "Creature does not belong to selected lab.",
            -20066: "Session context is not initialized. Login is required.",
            -20067: "Session expired. Please login again.",
            -20068: "Access denied for selected lab.",
            -20069: "Access denied for selected creature.",
            -20070: "Unsupported mutagen type.",
        }

        if code in custom:
            return custom[code]

        if code is not None:
            return f"Oracle error {code}: {message}"

        return f"Oracle error: {message}"

    return str(exc)