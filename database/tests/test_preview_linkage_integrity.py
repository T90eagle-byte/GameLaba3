from __future__ import annotations

import itertools
import sys
import uuid
from pathlib import Path
from typing import Any

import oracledb


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from database.scripts.run_tests import DEFAULT_ENV_PATH, create_connection, load_oracle_settings  # noqa: E402


PASSWORD = "Preview_linkage_123"
PREVIEW_CALLS = 100
OPTIONS_PER_CALL = 10
REAL_CROSSBREEDS = 20


def parse_genotype(summary: str) -> dict[str, tuple[str, str]]:
    result: dict[str, tuple[str, str]] = {}
    for item in summary.split(";"):
        gene, alleles = item.strip().split(":", 1)
        first, second = alleles.split("/", 1)
        result[gene.strip()] = (first.strip(), second.strip())
    return result


def assert_linkage(
    genotype: dict[str, tuple[Any, Any]],
    parents: tuple[dict[str, tuple[Any, Any, int | None]], dict[str, tuple[Any, Any, int | None]]],
) -> int:
    checked = 0
    for slot, parent in enumerate(parents):
        groups: dict[int, list[set[int]]] = {}
        for gene, (first, second, group) in parent.items():
            if group is None:
                continue
            selected = genotype[gene][slot]
            matching_sides = {index for index, allele in enumerate((first, second)) if allele == selected}
            if not matching_sides:
                raise AssertionError(f"offspring allele {selected!r} is absent from parent {slot + 1} gene {gene}")
            groups.setdefault(group, []).append(matching_sides)
        for group, matching in groups.items():
            if len(matching) > 1:
                checked += 1
                if not set.intersection(*matching):
                    raise AssertionError(f"linkage group {group} mixes parental sides in slot {slot + 1}: {genotype}")
    return checked


def snapshot(cursor: oracledb.Cursor, lab_id: int) -> tuple[Any, ...]:
    cursor.execute(
        "select wallet,rating,(select count(*) from creatures where lab_id=:id),"
        "(select count(*) from experiments where lab_id=:id) from labs where lab_id=:id",
        id=lab_id,
    )
    return tuple(cursor.fetchone())


def main() -> int:
    connection = create_connection(load_oracle_settings(DEFAULT_ENV_PATH))
    login = f"v{uuid.uuid4().hex[:12]}"
    user_id: int | None = None
    lab_id: int | None = None
    token: str | None = None
    try:
        with connection.cursor() as cursor:
            out_user = cursor.var(oracledb.NUMBER)
            cursor.callproc("pkg_genetics_game.register_user", ["Preview linkage", login, PASSWORD, out_user])
            user_id = int(out_user.getvalue())
            token = str(cursor.callfunc("pkg_genetics_game.login_user", str, [login, PASSWORD]))
            out_lab = cursor.var(oracledb.NUMBER)
            cursor.callproc("pkg_genetics_game.start_new_lab", [token, "Preview linkage", out_lab])
            lab_id = int(out_lab.getvalue())

            cursor.execute(
                "select c.creature_id,c.species_type,g.gene_name,g.linkage_group,"
                "a1.description,a2.description,gt.allele1_id,gt.allele2_id "
                "from creatures c join genotypes gt on gt.creature_id=c.creature_id "
                "join genes g on g.gene_id=gt.gene_id "
                "join alleles a1 on a1.allele_id=gt.allele1_id "
                "join alleles a2 on a2.allele_id=gt.allele2_id "
                "where c.lab_id=:id order by c.creature_id,g.gene_id",
                id=lab_id,
            )
            display_parents: dict[int, dict[str, tuple[str, str, int | None]]] = {}
            id_parents: dict[int, dict[str, tuple[int, int, int | None]]] = {}
            species: dict[int, int] = {}
            for creature_id, species_type, gene, group, desc1, desc2, allele1, allele2 in cursor.fetchall():
                species[int(creature_id)] = int(species_type)
                display_parents.setdefault(int(creature_id), {})[str(gene)] = (str(desc1), str(desc2), group)
                id_parents.setdefault(int(creature_id), {})[str(gene)] = (int(allele1), int(allele2), group)

            pairs = [
                pair
                for pair in itertools.combinations(display_parents, 2)
                if species[pair[0]] == species[pair[1]]
                and any(group is not None for _a, _b, group in display_parents[pair[0]].values())
            ]
            if not pairs:
                raise AssertionError("starting population has no compatible parents with linked genes")

            before = snapshot(cursor, lab_id)
            rows_checked = 0
            linked_groups_checked = 0
            for call_no in range(PREVIEW_CALLS):
                parent1, parent2 = pairs[call_no % len(pairs)]
                ref = cursor.callfunc(
                    "pkg_genetics_game.preview_offspring_options",
                    oracledb.CURSOR,
                    [token, lab_id, parent1, parent2, OPTIONS_PER_CALL],
                )
                rows = ref.fetchall()
                ref.close()
                if len(rows) != OPTIONS_PER_CALL:
                    raise AssertionError(f"preview returned {len(rows)} rows instead of {OPTIONS_PER_CALL}")
                for row in rows:
                    if row[3] is not None:
                        raise AssertionError(f"preview probability must remain NULL, got {row[3]!r}")
                    genotype = parse_genotype(str(row[5]))
                    linked_groups_checked += assert_linkage(
                        genotype,
                        (display_parents[parent1], display_parents[parent2]),
                    )
                    rows_checked += 1

            if rows_checked < 1000 or linked_groups_checked == 0:
                raise AssertionError(f"insufficient preview coverage: rows={rows_checked}, groups={linked_groups_checked}")
            if snapshot(cursor, lab_id) != before:
                raise AssertionError("preview changed persistent laboratory state")

            # The real algorithm is intentionally unchanged; verify the same linkage invariant.
            parent1, parent2 = pairs[0]
            connection.autocommit = False
            for index in range(REAL_CROSSBREEDS):
                out_child = cursor.var(oracledb.NUMBER)
                cursor.callproc(
                    "pkg_genetics_game.crossbreed",
                    [lab_id, parent1, parent2, f"Rollback offspring {index}", out_child],
                )
                cursor.execute(
                    "select g.gene_name,gt.allele1_id,gt.allele2_id "
                    "from genotypes gt join genes g on g.gene_id=gt.gene_id where gt.creature_id=:id",
                    id=int(out_child.getvalue()),
                )
                child = {str(gene): (int(first), int(second)) for gene, first, second in cursor.fetchall()}
                assert_linkage(child, (id_parents[parent1], id_parents[parent2]))
            connection.rollback()
            connection.autocommit = True
            if snapshot(cursor, lab_id) != before:
                raise AssertionError("rolled-back real crossbreed changed persistent laboratory state")

        print(f"PASS: {rows_checked} preview samples preserved every linked parental group")
        print("PASS: preview probability stayed NULL and persistent state stayed unchanged")
        print(f"PASS: {REAL_CROSSBREEDS} real crossbreeds preserved linkage and were rolled back")
        return 0
    finally:
        connection.autocommit = True
        with connection.cursor() as cursor:
            if token and lab_id:
                try:
                    cursor.callproc("pkg_genetics_game.delete_lab", [token, lab_id])
                except oracledb.DatabaseError:
                    pass
            if token:
                try:
                    cursor.callproc("pkg_genetics_game.logout_user", [token])
                except oracledb.DatabaseError:
                    pass
            if user_id is not None:
                cursor.execute("delete from sessions where user_id=:id", id=user_id)
                cursor.execute("delete from users where user_id=:id", id=user_id)
        connection.close()


if __name__ == "__main__":
    raise SystemExit(main())
