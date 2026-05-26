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
            -20030: "Genotype data for the selected gene is missing in one or both parents.",
            -20031: "Both source creatures must be selected.",
            -20032: "Source creatures must be different.",
            -20033: "Result creature name cannot be empty.",
            -20034: "Source creature A not found in selected lab.",
            -20035: "Source creature B not found in selected lab.",
            -20036: "Crossbreeding is allowed only for creatures of the same species type.",
            -20037: "Selected creatures have no common genes for crossbreeding.",
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
