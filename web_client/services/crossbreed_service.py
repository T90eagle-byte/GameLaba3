from __future__ import annotations

from typing import Any

import oracledb

from services.oracle import rows_from_refcursor, run_db


PREVIEW_CANDIDATE_LIMIT = 10


def preview_genotype_key(row: dict[str, Any]) -> str:
    """Return the package-provided inherited state used to deduplicate samples."""
    genotype = " ".join(str(row.get("genotype_summary") or "").split()).lower()
    if genotype:
        return genotype
    return "|".join(
        " ".join(str(row.get(field) or "").split()).lower()
        for field in ("species_type", "phenotype_summary")
    )


def unique_preview_rows(rows: list[dict[str, Any]], limit: int = 3) -> list[dict[str, Any]]:
    """Keep at most ``limit`` distinct package samples without changing genetics."""
    unique_rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for row in rows:
        key = preview_genotype_key(row)
        if key in seen:
            continue
        seen.add(key)
        unique_rows.append({**row, "option_no": len(unique_rows) + 1})
        if len(unique_rows) >= limit:
            break
    return unique_rows


def preview_offspring_options(
    session_token: str,
    lab_id: int,
    parent1_id: int,
    parent2_id: int,
    options_count: int = 3,
) -> list[dict[str, Any]]:
    requested_count = max(1, min(options_count, 3))
    candidate_count = max(requested_count, PREVIEW_CANDIDATE_LIMIT)

    def action(connection: oracledb.Connection) -> list[dict[str, Any]]:
        with connection.cursor() as cursor:
            ref_cursor = cursor.callfunc(
                "pkg_genetics_game.preview_offspring_options",
                oracledb.DB_TYPE_CURSOR,
                [session_token, lab_id, parent1_id, parent2_id, candidate_count],
            )
            try:
                return rows_from_refcursor(ref_cursor)
            finally:
                ref_cursor.close()

    return unique_preview_rows(run_db(action), limit=requested_count)


def crossbreed(
    session_token: str,
    lab_id: int,
    parent1_id: int,
    parent2_id: int,
    offspring_name: str,
) -> int:
    def action(connection: oracledb.Connection) -> int:
        with connection.cursor() as cursor:
            cursor.callproc("pkg_genetics_game.load_lab", [session_token, lab_id])
            out_offspring_id = cursor.var(oracledb.DB_TYPE_NUMBER)
            cursor.callproc(
                "pkg_genetics_game.crossbreed",
                [lab_id, parent1_id, parent2_id, offspring_name, out_offspring_id],
            )
            value = out_offspring_id.getvalue()
            return 0 if value is None else int(value)

    return run_db(action)
