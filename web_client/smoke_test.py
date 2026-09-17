from __future__ import annotations

import random
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app import create_app  # noqa: E402
from services import creature_service, crossbreed_service, history_service, mutation_service, rating_service, task_service  # noqa: E402
from services.oracle import ServiceError  # noqa: E402


class SmokeFailure(RuntimeError):
    pass


def ok(message: str) -> None:
    print(f"[OK] {message}")


def skip(message: str) -> None:
    print(f"[SKIP] {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SmokeFailure(message)


def get_session_values(client: Any) -> tuple[str, int]:
    with client.session_transaction() as sess:
        token = str(sess.get("session_token") or "")
        lab_id = int(sess.get("current_lab_id") or 0)
    require(bool(token), "session_token is missing after login")
    require(lab_id > 0, "current_lab_id is missing after lab creation")
    return token, lab_id


def get_value(row: dict[str, Any], *names: str, default: Any = None) -> Any:
    for name in names:
        if name in row and row[name] is not None:
            return row[name]
    return default


def first_compatible_pair(creatures: list[dict[str, Any]]) -> tuple[int, int] | None:
    by_species: dict[str, list[dict[str, Any]]] = {}
    for creature in creatures:
        species = str(get_value(creature, "species_type", "species_code", default=""))
        by_species.setdefault(species, []).append(creature)
    for rows in by_species.values():
        if len(rows) >= 2:
            return int(rows[0]["creature_id"]), int(rows[1]["creature_id"])
    return None


def first_cross_species_pair(creatures: list[dict[str, Any]]) -> tuple[int, int] | None:
    normal = [
        row for row in creatures
        if 1 <= int(get_value(row, "species_type", default=0)) <= 6
    ]
    for first in normal:
        for second in normal:
            if (
                first["creature_id"] != second["creature_id"]
                and first["species_type"] != second["species_type"]
            ):
                return int(first["creature_id"]), int(second["creature_id"])
    return None


def main() -> None:
    app = create_app()
    app.config.update(TESTING=True)
    client = app.test_client()

    login = f"w{int(time.time()) % 100000}{random.randint(100, 999)}"
    password = "SmokePass123"

    response = client.get("/health")
    require(response.status_code == 200, f"/health failed: {response.get_json(silent=True)}")
    ok("/health status=200")

    response = client.get("/login")
    require(response.status_code == 200, "/login should open")
    ok("/login opens")


    response = client.post(
        "/register",
        data={"username": "Web Smoke", "login": login, "password": password},
        follow_redirects=True,
    )
    require(response.status_code == 200, "register flow failed")
    ok("register flow")

    response = client.post(
        "/login",
        data={"login": login, "password": password},
        follow_redirects=True,
    )
    require(response.status_code == 200, "login flow failed")
    ok("login flow")

    response = client.post("/labs", data={"action": "create"}, follow_redirects=True)
    require(response.status_code == 200, "create lab flow failed")
    token, lab_id = get_session_values(client)
    ok(f"create/open lab #{lab_id}")

    for route in ("/dashboard", "/creatures", "/tasks", "/crossbreed", "/mutations", "/experiments", "/rating-events"):
        response = client.get(route)
        require(response.status_code == 200, f"{route} should open")
        ok(f"{route} opens")

    creatures = creature_service.get_creatures(token, lab_id)
    require(bool(creatures), "starting creatures were not created")
    first_creature_id = int(creatures[0]["creature_id"])
    response = client.get(f"/creatures/{first_creature_id}")
    require(response.status_code == 200, "creature detail should open")
    ok("creature detail opens")

    tasks = task_service.get_tasks(token, lab_id)
    completed = False
    for task in tasks:
        task_id = int(get_value(task, "task_id", default=0))
        if task_id <= 0:
            continue
        for creature in creatures:
            creature_id = int(creature["creature_id"])
            try:
                if task_service.check_task(token, lab_id, task_id, creature_id):
                    response = client.post(
                        "/tasks",
                        data={"action": "check", "task_id": task_id, "creature_id": creature_id},
                        follow_redirects=True,
                    )
                    require(response.status_code == 200, "task check route failed")
                    response = client.post(
                        "/tasks",
                        data={"action": "complete", "task_id": task_id, "creature_id": creature_id},
                        follow_redirects=True,
                    )
                    require(response.status_code == 200, "task complete route failed")
                    completed = True
                    ok(f"check/complete order #{task_id}")
                    break
            except ServiceError:
                continue
        if completed:
            break
    if not completed:
        skip("no immediately matching order found for current starting creatures")

    pair = first_compatible_pair(creatures)
    if pair:
        parent1_id, parent2_id = pair
        preview = crossbreed_service.preview_offspring_options(token, lab_id, parent1_id, parent2_id, 3)
        require(1 <= len(preview) <= 3, "backend preview returned an invalid number of samples")
        require(len({str(row.get("genotype_summary") or "") for row in preview}) == len(preview), "preview contains duplicate genotypes")
        before_count = len(creature_service.get_creatures(token, lab_id))
        response = client.post(
            "/crossbreed",
            data={"action": "preview", "parent1_id": parent1_id, "parent2_id": parent2_id, "offspring_name": "Smoke preview"},
            follow_redirects=True,
        )
        require(response.status_code == 200, "crossbreed preview route failed")
        preview_html = response.get_data(as_text=True)
        require("Пример возможного потомства" in preview_html, "preview is not marked as samples")
        require("Вероятность:" not in preview_html and "33.3%" not in preview_html, "preview shows a fake probability")
        after_preview_count = len(creature_service.get_creatures(token, lab_id))
        require(before_count == after_preview_count, "preview changed creature count")
        response = client.post(
            "/crossbreed",
            data={"action": "create", "parent1_id": parent1_id, "parent2_id": parent2_id, "offspring_name": "Smoke offspring"},
            follow_redirects=True,
        )
        require(response.status_code == 200, "real crossbreed route failed")
        after_create_count = len(creature_service.get_creatures(token, lab_id))
        require(after_create_count > after_preview_count, "real crossbreed did not create offspring")
        ok("crossbreed preview is stateless and real crossbreed creates offspring")

        response = client.post(
            "/experiments",
            data={
                "mode": "crossbreed_mutagen",
                "action": "crossbreed_mutagen",
                "parent1_id": parent1_id,
                "parent2_id": parent2_id,
                "offspring_name": "Smoke combined offspring",
                "mutagen_type": "RADIATION",
            },
            follow_redirects=True,
        )
        require(response.status_code == 200, "combined experiment route failed")
        combined_html = response.get_data(as_text=True)
        require("Эксперимент завершён" in combined_html, "combined experiment feedback is missing")
        require("Облучение" in combined_html, "combined experiment mutagen label is missing")
        after_combined_count = len(creature_service.get_creatures(token, lab_id))
        require(after_combined_count == after_create_count + 1, "combined experiment did not create exactly one offspring")
        ok("combined experiment route creates one in-place-mutated offspring")
    else:
        skip("no compatible parent pair found")

    hybrid_pair = first_cross_species_pair(creatures)
    if hybrid_pair:
        parent1_id, parent2_id = hybrid_pair
        before_ids = {int(row["creature_id"]) for row in creature_service.get_creatures(token, lab_id)}
        response = client.post(
            "/experiments",
            data={
                "mode": "hybridization",
                "action": "hybridization",
                "parent1_id": parent1_id,
                "parent2_id": parent2_id,
                "offspring_name": "Smoke hybrid",
            },
            follow_redirects=True,
        )
        require(response.status_code == 200, "hybridization route failed")
        hybrid_html = response.get_data(as_text=True)
        require("Гибридизация завершена" in hybrid_html, "hybridization feedback is missing")
        require("Гибрид" in hybrid_html and "Облучение" in hybrid_html, "hybrid display labels are missing")
        require(
            "Списано за гибридизацию" in hybrid_html
            or "Рейтинг уже был на нуле" in hybrid_html,
            "actual hybridization penalty is missing",
        )

        after_hybrid = creature_service.get_creatures(token, lab_id)
        created_ids = {int(row["creature_id"]) for row in after_hybrid} - before_ids
        require(len(created_ids) == 1, "hybridization did not create exactly one offspring")
        hybrid_id = created_ids.pop()
        hybrid = next(row for row in after_hybrid if int(row["creature_id"]) == hybrid_id)
        require(int(get_value(hybrid, "species_type", default=0)) == 7, "hybrid species_type is not 7")
        require(len(creature_service.get_genotype(token, hybrid_id, lab_id)) == 19, "hybrid genotype is not canonical")
        require(len(creature_service.get_morphology(token, hybrid_id, lab_id)) == 18, "hybrid morphology is incomplete")
        hybrid_history = [
            row for row in history_service.get_experiment_history(token, lab_id)
            if str(row.get("experiment_type") or "").upper() == "HYBRIDIZATION"
            and int(row.get("offspring_id") or 0) == hybrid_id
        ]
        require(len(hybrid_history) == 1, "hybridization did not create exactly one history row")
        require(str(hybrid_history[0].get("mutagen_type") or "").upper() == "RADIATION", "hybrid history lost radiation")
        ok("hybridization route creates one canonical hybrid with one history row")

        before_mutagen_ids = {int(row["creature_id"]) for row in after_hybrid}
        response = client.post(
            "/mutations",
            data={"action": "apply_mutagen", "creature_id": hybrid_id, "mutagen_type": "CHEMICAL"},
            follow_redirects=True,
        )
        require(response.status_code == 200, "hybrid mutagen route failed")
        after_mutagen = creature_service.get_creatures(token, lab_id)
        mutagen_ids = {int(row["creature_id"]) for row in after_mutagen} - before_mutagen_ids
        require(len(mutagen_ids) == 1, "hybrid mutagen did not create exactly one clone")
        hybrid_clone = next(row for row in after_mutagen if int(row["creature_id"]) in mutagen_ids)
        require(int(get_value(hybrid_clone, "species_type", default=0)) == 7, "mutagen clone lost hybrid species")
        ok("hybrid remains mutable through the existing mutagen route")

        before_rejected_count = len(after_mutagen)
        response = client.post(
            "/experiments",
            data={
                "mode": "crossbreed",
                "action": "crossbreed",
                "parent1_id": hybrid_id,
                "parent2_id": parent1_id,
                "offspring_name": "Rejected hybrid child",
            },
            follow_redirects=True,
        )
        require(response.status_code == 200, "hybrid-parent rejection route failed")
        require("Гибрид нельзя использовать в качестве родителя" in response.get_data(as_text=True), "hybrid-parent rejection is not user-facing")
        require(len(creature_service.get_creatures(token, lab_id)) == before_rejected_count, "rejected hybrid breeding created a creature")
        ok("hybrid parent is rejected without creating offspring")
    else:
        skip("no different-species parent pair found")

    try:
        shop = mutation_service.get_mutation_shop(token, lab_id)
        if shop:
            mutation_id = int(get_value(shop[0], "mutation_id", default=0))
            bought = mutation_service.buy_mutation(token, lab_id, mutation_id)
            if bought:
                compatible = mutation_service.get_compatible_creatures_for_mutation(token, lab_id, mutation_id)
                if compatible:
                    creature_id = int(compatible[0]["creature_id"])
                    response = client.post(
                        "/mutations",
                        data={"action": "apply_mutation", "mutation_id": mutation_id, "creature_id": creature_id},
                        follow_redirects=True,
                    )
                    require(response.status_code == 200, "apply mutation route failed")
                    ok("buy/apply mutation flow")
                else:
                    skip("mutation bought, but no compatible creature found")
            else:
                skip("backend refused mutation purchase")
        else:
            skip("mutation shop is empty")
    except ServiceError as exc:
        skip(f"mutation action skipped: {exc}")

    try:
        fresh_creatures = creature_service.get_creatures(token, lab_id)
        if fresh_creatures:
            creature_id = int(fresh_creatures[0]["creature_id"])
            response = client.post(
                "/mutations",
                data={"action": "apply_mutagen", "creature_id": creature_id, "mutagen_type": "RADIATION"},
                follow_redirects=True,
            )
            require(response.status_code == 200, "apply RADIATION route failed")
            ok("apply RADIATION route")
    except ServiceError as exc:
        skip(f"mutagen action skipped: {exc}")

    experiments = history_service.get_experiment_history(token, lab_id)
    events = rating_service.get_rating_events(token, lab_id)
    require(isinstance(experiments, list), "experiment history did not return a list")
    require(isinstance(events, list), "rating events did not return a list")
    ok(f"history pages backed by package rows: experiments={len(experiments)}, rating_events={len(events)}")

    response = client.get("/dashboard")
    require(response.status_code == 200, "dashboard should still open after actions")
    response = client.get("/logout", follow_redirects=True)
    require(response.status_code == 200, "logout flow failed")
    ok("logout flow")

    print("Web smoke completed")


if __name__ == "__main__":
    main()
