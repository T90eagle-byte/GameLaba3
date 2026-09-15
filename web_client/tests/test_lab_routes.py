from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


WEB_ROOT = Path(__file__).resolve().parents[1]
if str(WEB_ROOT) not in sys.path:
    sys.path.insert(0, str(WEB_ROOT))

import app as app_module  # noqa: E402
from services import lab_service  # noqa: E402
from services.oracle import LAB_SESSION_CONFLICT_MESSAGE, ServiceError  # noqa: E402


def v3_creature() -> dict[str, object]:
    return {
        "creature_id": 17,
        "lab_id": 7,
        "creature_name": "Дельфин",
        "species_type": "mammal",
        "genetics_version": 3,
        "archetype_id": None,
    }


def v3_morphology_rows() -> list[dict[str, str]]:
    values = {
        "body_shape": "cetacean", "body_proportion": "fusiform", "body_size": "large",
        "body_cover": "smooth_skin", "body_color": "blue", "mouth_type": "filter_feeding",
        "snout_type": "blunt", "eye_type": "lateral", "front_appendage_count": "two",
        "front_appendage_type": "flipper", "front_appendage_size": "large", "rear_appendage_count": "zero",
        "rear_appendage_type": "none", "rear_appendage_size": "none", "tail_type": "cetacean",
        "tail_size": "large", "dorsal_type": "dorsal_fin", "dorsal_size": "medium",
    }
    return [
        {"creature_id": 17, "gene_code": code, "gene_display_name": code,
         "expressed_allele_code": value, "expressed_display_name": value}
        for code, value in values.items()
    ]


class FakeVariable:
    def __init__(self, value: int) -> None:
        self.value = value

    def getvalue(self) -> int:
        return self.value


class FakeCursor:
    def __init__(self) -> None:
        self.calls: list[tuple[str, list[object]]] = []

    def __enter__(self) -> "FakeCursor":
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def var(self, _type: object) -> FakeVariable:
        return FakeVariable(321)

    def callproc(self, name: str, args: list[object]) -> None:
        self.calls.append((name, args))


class FakeConnection:
    def __init__(self, cursor: FakeCursor) -> None:
        self._cursor = cursor

    def cursor(self) -> FakeCursor:
        return self._cursor


class LabServiceTests(unittest.TestCase):
    def test_named_create_and_rename_use_package_api(self) -> None:
        cursor = FakeCursor()
        connection = FakeConnection(cursor)

        with patch.object(lab_service, "run_db", side_effect=lambda action: action(connection)):
            lab_id = lab_service.start_new_lab("token", "Морская мастерская")
            lab_service.rename_lab("token", lab_id, "Новая мастерская")

        self.assertEqual(lab_id, 321)
        self.assertEqual(cursor.calls[0][0], "pkg_genetics_game.start_new_lab")
        self.assertEqual(cursor.calls[0][1][:2], ["token", "Морская мастерская"])
        self.assertEqual(
            cursor.calls[1],
            ("pkg_genetics_game.rename_lab", ["token", 321, "Новая мастерская"]),
        )

    def test_recover_lab_access_uses_selected_package_operation(self) -> None:
        cursor = FakeCursor()
        connection = FakeConnection(cursor)

        with patch.object(lab_service, "run_db", side_effect=lambda action: action(connection)):
            lab_service.recover_lab_access("token", 42)

        self.assertEqual(
            cursor.calls,
            [("pkg_genetics_game.recover_lab_access", ["token", 42])],
        )


class LabRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.app = app_module.create_app()
        self.app.config.update(TESTING=True, SECRET_KEY="test-secret")
        self.client = self.app.test_client()
        with self.client.session_transaction() as flask_session:
            flask_session["session_token"] = "current-token"
            flask_session["login"] = "tester"

    @patch.object(app_module.creature_service, "get_lab_morphology", return_value=v3_morphology_rows())
    @patch.object(app_module.creature_service, "get_creatures", return_value=[v3_creature()])
    def test_creature_list_uses_one_batch_morphology_read_for_v3_cards(
        self,
        get_creatures: Mock,
        get_lab_morphology: Mock,
    ) -> None:
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/creatures")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"morphology-svg", response.data)
        self.assertIn(b'data-shape="cetacean"', response.data)
        get_creatures.assert_called_once_with("current-token", 7)
        get_lab_morphology.assert_called_once_with("current-token", 7)

    @patch.object(app_module.creature_service, "get_lab_morphology", return_value=v3_morphology_rows())
    @patch.object(app_module.creature_service, "get_creatures", return_value=[v3_creature()])
    def test_crossbreed_parent_card_uses_the_same_batched_v3_read(
        self,
        get_creatures: Mock,
        get_lab_morphology: Mock,
    ) -> None:
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/crossbreed")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"morphology-svg", response.data)
        self.assertIn(b'data-tail-type="cetacean"', response.data)
        get_creatures.assert_called_once_with("current-token", 7)
        get_lab_morphology.assert_called_once_with("current-token", 7)

    @staticmethod
    def conflict() -> ServiceError:
        return ServiceError(LAB_SESSION_CONFLICT_MESSAGE)

    @patch.object(app_module.lab_service, "load_lab")
    def test_open_conflict_does_not_close_or_retry_other_sessions(self, load_lab: Mock) -> None:
        load_lab.side_effect = self.conflict()
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.post(
            "/labs",
            data={"action": "open", "lab_id": "42"},
        )

        self.assertEqual(response.status_code, 302)
        load_lab.assert_called_once_with("current-token", 42)
        with self.client.session_transaction() as flask_session:
            self.assertEqual(flask_session["current_lab_id"], 7)
            self.assertEqual(flask_session["pending_recovery_lab_id"], 42)

    @patch.object(app_module.lab_service, "list_user_labs")
    @patch.object(app_module.lab_service, "load_lab")
    def test_conflict_page_offers_recovery_for_selected_lab_only(
        self,
        load_lab: Mock,
        list_user_labs: Mock,
    ) -> None:
        load_lab.side_effect = self.conflict()
        list_user_labs.return_value = [
            {"lab_id": 42, "lab_name": "Занятая лаборатория"},
            {"lab_id": 43, "lab_name": "Другая лаборатория"},
        ]

        response = self.client.post(
            "/labs",
            data={"action": "open", "lab_id": "42"},
            follow_redirects=True,
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data.count("Восстановить доступ".encode()), 1)
        self.assertIn(b'name="lab_id" value="42"', response.data)

    @patch.object(app_module.lab_service, "list_user_labs", return_value=[])
    @patch.object(app_module.lab_service, "load_lab")
    def test_inactive_session_error_is_not_treated_as_lab_conflict(
        self,
        load_lab: Mock,
        _list_user_labs: Mock,
    ) -> None:
        load_lab.side_effect = ServiceError("Сессия не активна. Выполните вход заново.")

        response = self.client.post(
            "/labs",
            data={"action": "open", "lab_id": "42"},
        )

        self.assertEqual(response.status_code, 200)
        load_lab.assert_called_once_with("current-token", 42)
        self.assertIn("Сессия не активна".encode(), response.data)
        with self.client.session_transaction() as flask_session:
            self.assertNotIn("pending_recovery_lab_id", flask_session)

    @patch.object(app_module.lab_service, "recover_lab_access")
    def test_explicit_recovery_transfers_only_selected_lab(
        self,
        recover_lab_access: Mock,
    ) -> None:
        response = self.client.post(
            "/labs",
            data={
                "action": "recover",
                "lab_id": "42",
                "confirm_recovery": "yes",
            },
        )

        self.assertEqual(response.status_code, 302)
        recover_lab_access.assert_called_once_with("current-token", 42)
        with self.client.session_transaction() as flask_session:
            self.assertEqual(flask_session["current_lab_id"], 42)
            self.assertNotIn("pending_recovery_lab_id", flask_session)

    @patch.object(app_module.lab_service, "recover_lab_access")
    def test_recovery_requires_explicit_confirmation(self, recover_lab_access: Mock) -> None:
        response = self.client.post(
            "/labs",
            data={"action": "recover", "lab_id": "42"},
        )

        self.assertEqual(response.status_code, 302)
        recover_lab_access.assert_not_called()

    @patch.object(app_module.lab_service, "delete_lab")
    def test_delete_conflict_requires_selected_recovery(self, delete_lab: Mock) -> None:
        delete_lab.side_effect = self.conflict()

        response = self.client.post(
            "/labs",
            data={"action": "delete", "lab_id": "51"},
        )

        self.assertEqual(response.status_code, 302)
        delete_lab.assert_called_once_with("current-token", 51)
        with self.client.session_transaction() as flask_session:
            self.assertEqual(flask_session["pending_recovery_lab_id"], 51)

    @patch.object(app_module.lab_service, "list_user_labs", return_value=[])
    @patch.object(app_module.lab_service, "recover_lab_access")
    def test_recovery_surfaces_its_own_error_without_retry(
        self,
        recover_lab_access: Mock,
        _list_labs: Mock,
    ) -> None:
        recover_lab_access.side_effect = ServiceError("Не удалось передать лабораторию.")

        response = self.client.post(
            "/labs",
            data={
                "action": "recover",
                "lab_id": "42",
                "confirm_recovery": "yes",
            },
        )

        self.assertEqual(response.status_code, 200)
        recover_lab_access.assert_called_once_with("current-token", 42)
        self.assertIn("Не удалось передать лабораторию".encode(), response.data)

    @patch.object(app_module.lab_service, "rename_lab")
    def test_rename_keeps_flask_selection_in_sync_with_package(self, rename_lab: Mock) -> None:
        response = self.client.post(
            "/labs",
            data={"action": "rename", "lab_id": "42", "lab_name": "Новое имя"},
        )

        self.assertEqual(response.status_code, 302)
        rename_lab.assert_called_once_with("current-token", 42, "Новое имя")
        with self.client.session_transaction() as flask_session:
            self.assertEqual(flask_session["current_lab_id"], 42)

    @patch.object(app_module.lab_service, "list_user_labs")
    def test_labs_page_displays_package_backed_name(self, list_labs: Mock) -> None:
        list_labs.return_value = [{"lab_id": 7, "lab_name": "Прибрежная станция"}]

        response = self.client.get("/labs")

        self.assertEqual(response.status_code, 200)
        self.assertIn("Прибрежная станция".encode(), response.data)

    @patch.object(app_module.lab_service, "find_user_lab")
    @patch.object(app_module.lab_service, "get_lab_stats")
    def test_dashboard_displays_current_package_backed_name(
        self,
        get_stats: Mock,
        find_lab: Mock,
    ) -> None:
        get_stats.return_value = {
            "wallet": 1000,
            "rating": 0,
            "creature_count": 30,
            "active_task_count": 3,
            "completed_task_count": 0,
            "experiment_count": 0,
        }
        find_lab.return_value = {"lab_id": 7, "lab_name": "Прибрежная станция"}
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/dashboard")

        self.assertEqual(response.status_code, 200)
        self.assertIn("Прибрежная станция".encode(), response.data)

    @patch.object(app_module.mutation_service, "buy_mutation", return_value=0)
    def test_failed_mutation_purchase_does_not_flash_success(self, buy_mutation: Mock) -> None:
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.post(
            "/mutations",
            data={"action": "buy_mutation", "mutation_id": "5"},
        )

        self.assertEqual(response.status_code, 302)
        buy_mutation.assert_called_once_with("current-token", 7, 5)
        with self.client.session_transaction() as flask_session:
            self.assertIn(
                ("warning", "Покупка мутации не выполнена: недостаточно монет."),
                flask_session["_flashes"],
            )

    @patch.object(app_module.rating_service, "get_rating_events", return_value=[])
    @patch.object(app_module.mutation_service, "get_mutation_shop", return_value=[])
    @patch.object(app_module.creature_service, "get_creatures")
    @patch.object(app_module.lab_service, "get_lab_stats", return_value={"wallet": 1000, "rating": 0})
    def test_mutation_query_preselects_current_lab_creature_and_portrait(
        self,
        _get_stats: Mock,
        get_creatures: Mock,
        _get_shop: Mock,
        _get_events: Mock,
    ) -> None:
        get_creatures.return_value = [{
            "creature_id": 17,
            "creature_name": "Рыба-исследователь",
            "species_type": "cartilaginous_fish",
            "phenotype_summary": "color=blue_color; has_wings=no_wings; nutrition_type=herbivore; size=medium_size",
        }]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/mutations?creature_id=17")
        markup = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("Выбранное существо".encode(), response.data)
        self.assertIn(b"mutation-selected-17", response.data)
        self.assertIn('id="mutation-creature-select"', markup)
        self.assertIn('value="17" data-creature-name="#17', markup)
        self.assertIn('value="17" selected', markup)

    @patch.object(app_module.rating_service, "get_rating_events", return_value=[])
    @patch.object(app_module.mutation_service, "get_mutation_shop", return_value=[])
    @patch.object(app_module.creature_service, "get_creatures", return_value=[])
    @patch.object(app_module.lab_service, "get_lab_stats", return_value={"wallet": 1000, "rating": 0})
    def test_foreign_or_invalid_mutation_creature_is_safe(
        self,
        _get_stats: Mock,
        _get_creatures: Mock,
        _get_shop: Mock,
        _get_events: Mock,
    ) -> None:
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/mutations?creature_id=999")

        self.assertEqual(response.status_code, 200)
        self.assertIn("Выбранное существо недоступно в текущей лаборатории".encode(), response.data)
        self.assertNotIn(b"mutation-selected-999", response.data)

    @patch.object(app_module.task_service, "complete_task", return_value={"is_completed": 1, "wallet_after": 1300, "rating_after": 35})
    @patch.object(app_module.task_service, "get_tasks", return_value=[{
        "task_id": 5,
        "task_name": "task_armored_crustacean",
        "task_status": "ACTIVE",
        "reward_money": 300,
        "reward_rating": 35,
    }])
    def test_manual_task_completion_shows_actual_reward_delta(
        self,
        _get_tasks: Mock,
        _complete_task: Mock,
    ) -> None:
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.post(
            "/tasks",
            data={"action": "complete", "task_id": "5", "creature_id": "17"},
            follow_redirects=True,
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("Задание выполнено: Бронированный ракообразный.".encode(), response.data)
        self.assertIn("Получено: +300 монет, +35 рейтинга.".encode(), response.data)

    @patch.object(app_module.lab_service, "get_lab_stats", side_effect=[{"wallet": 1000, "rating": 0}, {"wallet": 1900, "rating": 30}])
    @patch.object(app_module.task_service, "get_tasks", side_effect=[
        [{"task_id": 181, "task_name": "task_v3_brown_cetacean", "task_status": "ACTIVE", "reward_money": 900, "reward_rating": 30}],
        [{"task_id": 181, "task_name": "task_v3_brown_cetacean", "task_status": "COMPLETED", "reward_money": 900, "reward_rating": 30}],
    ])
    @patch.object(app_module.creature_service, "get_morphology")
    @patch.object(app_module.creature_service, "get_creature_detail", return_value=v3_creature())
    @patch.object(app_module.creature_service, "get_genotype")
    @patch.object(app_module.mutation_service, "apply_mutation")
    def test_v3_mutation_feedback_uses_oracle_morphology_and_new_task_delta(
        self,
        _apply_mutation: Mock,
        get_genotype: Mock,
        _get_detail: Mock,
        get_morphology: Mock,
        _get_tasks: Mock,
        _get_stats: Mock,
    ) -> None:
        before_morphology = v3_morphology_rows()
        after_morphology = [dict(row) for row in before_morphology]
        for row in before_morphology:
            if row["gene_code"] == "body_color":
                row["gene_display_name"] = "Цвет тела"
                row["expressed_display_name"] = "Синий"
        for row in after_morphology:
            if row["gene_code"] == "body_color":
                row["gene_display_name"] = "Цвет тела"
                row["expressed_display_name"] = "Красный"
                row["expressed_allele_code"] = "red"
        get_morphology.side_effect = [before_morphology, after_morphology]
        get_genotype.side_effect = [
            [{"gene_id": 1, "gene_name": "body_color", "allele1_id": 10, "allele2_id": 20}],
            [{"gene_id": 1, "gene_name": "body_color", "allele1_id": 30, "allele2_id": 20}],
        ]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.post("/mutations", data={"action": "apply_mutation", "creature_id": "17", "mutation_id": "5"})

        self.assertEqual(response.status_code, 302)
        with self.client.session_transaction() as flask_session:
            feedback = flask_session["action_feedback"]
        self.assertEqual(feedback["morphology_changes"], [{"label": "Цвет тела", "before": "Синий", "after": "Красный"}])
        self.assertEqual(feedback["completed_tasks"][0]["name"], "Специальное задание")
        self.assertEqual(feedback["wallet_delta_label"], "+900")
        self.assertEqual(feedback["rating_delta_label"], "+30")

    @patch.object(app_module.creature_service, "get_morphology")
    @patch.object(app_module.creature_service, "get_genotype", return_value=[])
    @patch.object(app_module.creature_service, "get_creature_detail")
    def test_v3_action_result_shows_russian_trait_and_task_rewards(
        self,
        get_detail: Mock,
        _get_genotype: Mock,
        get_morphology: Mock,
    ) -> None:
        get_detail.return_value = v3_creature()
        get_morphology.return_value = v3_morphology_rows()
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7
            flask_session["action_feedback"] = {
                "kind": "mutation",
                "result_creature_id": 17,
                "morphology_observed": True,
                "morphology_changes": [{"label": "Цвет тела", "before": "Синий", "after": "Красный"}],
                "has_hidden_morphology_change": False,
                "completed_tasks": [{"name": "Дискообразный пилонос", "money_label": "+900", "rating_label": "+30"}],
                "has_balance_delta": True,
                "wallet_delta_label": "+900",
                "rating_delta_label": "+30",
            }

        response = self.client.get("/creatures/17")
        markup = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("Мутация применена".encode(), response.data)
        self.assertIn("Цвет тела".encode(), response.data)
        self.assertIn("Синий → Красный".encode(), response.data)
        self.assertIn("Дискообразный пилонос".encode(), response.data)
        self.assertIn("+900 монет".encode(), response.data)
        feedback_markup = markup.split("action-result-panel", 1)[1].split("</section>", 1)[0]
        self.assertNotIn("body_color", feedback_markup)
        self.assertNotIn("task_v3_", feedback_markup)

        refreshed = self.client.get("/creatures/17")
        self.assertNotIn(b"action-result-panel", refreshed.data)

    @patch.object(app_module.creature_service, "get_morphology", return_value=v3_morphology_rows())
    @patch.object(app_module.creature_service, "get_genotype", return_value=[])
    @patch.object(app_module.creature_service, "get_creature_detail")
    def test_hidden_v3_mutation_does_not_claim_visible_change(
        self,
        get_detail: Mock,
        _get_genotype: Mock,
        _get_morphology: Mock,
    ) -> None:
        get_detail.return_value = {**v3_creature(), "creature_name": "Скат"}
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7
            flask_session["action_feedback"] = {
                "kind": "mutation",
                "result_creature_id": 17,
                "morphology_observed": True,
                "morphology_changes": [],
                "has_hidden_morphology_change": True,
                "completed_tasks": [],
                "has_balance_delta": False,
            }

        response = self.client.get("/creatures/17")

        self.assertEqual(response.status_code, 200)
        self.assertIn("Мутация произошла, но проявившийся признак не изменился.".encode(), response.data)

    @patch.object(app_module.history_service, "get_experiment_history")
    def test_experiments_links_to_offspring_id_from_history_cursor(self, get_history: Mock) -> None:
        get_history.return_value = [{
            "experiment_type": "CROSS",
            "offspring_id": 73,
            "created_at": None,
        }]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/experiments")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b'href="/creatures/73"', response.data)

    def test_mutagen_buttons_use_russian_player_labels(self) -> None:
        markup = (WEB_ROOT / "templates" / "mutations.html").read_text(encoding="utf-8")
        self.assertIn("Применить облучение", markup)
        self.assertIn("Применить химический мутаген", markup)
        self.assertNotIn(">Применить RADIATION<", markup)
        self.assertNotIn(">Применить CHEMICAL<", markup)

    @patch.object(app_module.creature_service, "get_genotype")
    @patch.object(app_module.creature_service, "get_creature_detail")
    def test_creature_detail_hides_technical_values_and_keeps_backend_result(
        self,
        get_detail: Mock,
        get_genotype: Mock,
    ) -> None:
        get_detail.return_value = {
            "creature_id": 17,
            "creature_name": "crustacean #1",
            "species_type": "crustacean",
            "phenotype_summary": "color=green_color; size=large_size",
        }
        get_genotype.return_value = [{
            "gene_name": "color",
            "dominance_type": "FULL",
            "allele1_display_name": "green_color",
            "allele1_trait_value": 10,
            "allele2_display_name": "blue_color",
            "allele2_trait_value": 20,
        }]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/creatures/17")

        self.assertEqual(response.status_code, 200)
        self.assertIn("Аллели:".encode(), response.data)
        self.assertIn("зелёный".encode(), response.data)
        self.assertIn("синий".encode(), response.data)
        self.assertIn("Результат".encode(), response.data)
        self.assertIn("зелёный".encode(), response.data)
        self.assertNotIn("Технические значения".encode(), response.data)
        self.assertNotIn(b">10 / 20<", response.data)

    @patch.object(app_module.creature_service, "get_morphology")
    @patch.object(app_module.creature_service, "get_genotype")
    @patch.object(app_module.creature_service, "get_creature_detail")
    def test_v3_creature_detail_renders_oracle_morphology_not_legacy_fields(
        self,
        get_detail: Mock,
        get_genotype: Mock,
        get_morphology: Mock,
    ) -> None:
        morphology_codes = (
            "body_shape", "body_proportion", "body_size", "body_cover", "body_color", "mouth_type", "snout_type", "eye_type",
            "front_appendage_count", "front_appendage_type", "front_appendage_size", "rear_appendage_count", "rear_appendage_type", "rear_appendage_size",
            "tail_type", "tail_size", "dorsal_type", "dorsal_size",
        )
        get_detail.return_value = {
            "creature_id": 18,
            "creature_name": "mammal #18",
            "species_type": "mammal",
            "genetics_version": 3,
            "archetype_id": 5,
            "archetype_code": "whale",
            "archetype_display_name": "Кит",
            "phenotype_summary": "color=legacy_green; size=legacy_small; has_wings=wings",
        }
        get_morphology.return_value = [
            {
                "gene_code": code,
                "gene_display_name": f"Признак {index + 1}",
                "expressed_allele_code": "blue" if code == "body_color" else "medium",
                "expressed_display_name": "Синий" if code == "body_color" else "Средний",
            }
            for index, code in enumerate(morphology_codes)
        ]
        get_genotype.return_value = [{
            "gene_name": "body_color",
            "gene_display_name": "Цвет тела",
            "dominance_type": "FULL",
            "allele1_display_name": "blue",
            "allele2_display_name": "blue",
        }]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/creatures/18")

        self.assertEqual(response.status_code, 200)
        get_morphology.assert_called_once_with("current-token", 18, 7)
        self.assertIn("Морфология".encode(), response.data)
        self.assertIn("Синий".encode(), response.data)
        self.assertIn(b'href="/crossbreed?parent_id=18"', response.data)
        self.assertIn(b'href="/mutations?creature_id=18"', response.data)
        self.assertNotIn(b"legacy_green", response.data)
        self.assertNotIn(b"legacy_small", response.data)

    @patch.object(app_module.creature_service, "get_genotype")
    @patch.object(app_module.creature_service, "get_creature_detail")
    def test_mutation_highlight_marks_only_changed_allele_and_is_one_time(
        self,
        get_detail: Mock,
        get_genotype: Mock,
    ) -> None:
        get_detail.return_value = {
            "creature_id": 17,
            "creature_name": "turtle #1",
            "species_type": "turtle",
            "phenotype_summary": "shell_armor=spiked_shell; size=medium_size",
        }
        get_genotype.return_value = [{
            "gene_id": 9,
            "gene_name": "shell_armor",
            "dominance_type": "FULL",
            "allele1_id": 10,
            "allele1_display_name": "smooth_shell",
            "allele2_id": 20,
            "allele2_display_name": "spiked_shell",
        }]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7
            flask_session["genotype_highlight"] = {
                "creature_id": 17,
                "changed_slots": {"shell_armor": ["allele2"]},
            }

        highlighted = self.client.get("/creatures/17")
        ordinary = self.client.get("/creatures/17")

        self.assertIn(b"gene-card-changed", highlighted.data)
        self.assertEqual(highlighted.data.count(b"allele-changed"), 1)
        self.assertIn("шипастый панцирь".encode(), highlighted.data)
        self.assertNotIn(b"gene-card-changed", ordinary.data)
        self.assertNotIn(b"allele-changed", ordinary.data)

    @patch.object(app_module.lab_service, "get_lab_stats", return_value={"wallet": 1000, "rating": 0})
    @patch.object(app_module.task_service, "get_tasks", return_value=[])
    @patch.object(app_module.creature_service, "get_creature_detail", return_value={"creature_id": 17, "genetics_version": 1})
    @patch.object(app_module.creature_service, "get_genotype")
    @patch.object(app_module.mutation_service, "apply_mutation")
    def test_apply_mutation_records_actual_genotype_diff_for_next_detail(
        self,
        apply_mutation: Mock,
        get_genotype: Mock,
        _get_creature_detail: Mock,
        _get_tasks: Mock,
        _get_stats: Mock,
    ) -> None:
        get_genotype.side_effect = [
            [{"gene_id": 1, "gene_name": "color", "allele1_id": 10, "allele2_id": 20}],
            [{"gene_id": 1, "gene_name": "color", "allele1_id": 30, "allele2_id": 20}],
        ]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.post("/mutations", data={"action": "apply_mutation", "creature_id": "17", "mutation_id": "5"})

        self.assertEqual(response.status_code, 302)
        apply_mutation.assert_called_once_with("current-token", 7, 17, 5)
        with self.client.session_transaction() as flask_session:
            self.assertEqual(flask_session["genotype_highlight"], {"creature_id": 17, "changed_slots": {"color": ["allele1"]}})

    @patch.object(app_module.lab_service, "get_lab_stats", return_value={"wallet": 950, "rating": -5})
    @patch.object(app_module.task_service, "get_tasks", return_value=[])
    @patch.object(app_module.creature_service, "get_creature_detail", return_value={"creature_id": 17, "genetics_version": 1})
    @patch.object(app_module.creature_service, "get_genotype")
    @patch.object(app_module.mutation_service, "apply_mutagen", return_value=33)
    def test_apply_mutagen_records_new_creature_genotype_diff_for_next_detail(
        self,
        apply_mutagen: Mock,
        get_genotype: Mock,
        _get_creature_detail: Mock,
        _get_tasks: Mock,
        _get_stats: Mock,
    ) -> None:
        get_genotype.side_effect = [
            [{"gene_id": 2, "gene_name": "size", "allele1_id": 10, "allele2_id": 20}],
            [{"gene_id": 2, "gene_name": "size", "allele1_id": 10, "allele2_id": 30}],
        ]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.post("/mutations", data={"action": "apply_mutagen", "creature_id": "17", "mutagen_type": "RADIATION"})

        self.assertEqual(response.status_code, 302)
        apply_mutagen.assert_called_once_with("current-token", 7, 17, "RADIATION")
        with self.client.session_transaction() as flask_session:
            self.assertEqual(flask_session["genotype_highlight"], {"creature_id": 33, "changed_slots": {"size": ["allele2"]}})

    @patch.object(app_module.rating_service, "get_rating_events")
    def test_player_pages_do_not_render_known_english_display_values(self, get_rating_events: Mock) -> None:
        get_rating_events.return_value = [{"event_type": "SYSTEM_ADJUSTMENT", "description": "System adjustment"}]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/rating-events")

        self.assertEqual(response.status_code, 200)
        self.assertNotIn(b"System adjustment", response.data)
        self.assertIn("Корректировка результата".encode(), response.data)

    @patch.object(app_module.creature_service, "get_creatures", return_value=[])
    @patch.object(app_module.task_service, "get_tasks")
    def test_tasks_page_never_renders_internal_task_keys(
        self,
        get_tasks: Mock,
        _get_creatures: Mock,
    ) -> None:
        get_tasks.return_value = [
            {
                "task_id": 5,
                "task_name": "task_armored_crustacean",
                "task_display_name": "task_armored_crustacean",
                "description": "Отберите прочное ракообразное.",
                "reward_money": 300,
                "reward_rating": 35,
                "difficulty_code": "HARD",
                "task_status": "ACTIVE",
            },
            {
                "task_id": 6,
                "task_name": "task_future_unknown",
                "task_display_name": "task_future_unknown",
                "description": "Особая цель клиента.",
                "reward_money": 100,
                "reward_rating": 10,
                "difficulty_code": "EASY",
                "task_status": "ACTIVE",
            },
        ]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/tasks")

        self.assertEqual(response.status_code, 200)
        self.assertIn("Бронированный ракообразный".encode(), response.data)
        self.assertIn("Специальное задание".encode(), response.data)
        self.assertIn("Задание #5".encode(), response.data)
        self.assertIn("Монеты +300".encode(), response.data)
        self.assertNotIn(b"task_armored_crustacean", response.data)
        self.assertNotIn(b"task_future_unknown", response.data)
        self.assertNotIn("Заказ #".encode(), response.data)
        self.assertNotIn("Деньги".encode(), response.data)

    @patch.object(app_module.creature_service, "get_creatures", return_value=[])
    @patch.object(app_module.task_service, "get_tasks")
    def test_tasks_page_explains_that_orders_check_carrier_alleles(
        self,
        get_tasks: Mock,
        _get_creatures: Mock,
    ) -> None:
        get_tasks.return_value = [
            {
                "task_id": 2,
                "task_name": "task_winged_specimen",
                "task_display_name": "task_winged_specimen",
                "description": "Найдите существо с крыльями.",
                "reward_money": 120,
                "reward_rating": 12,
                "difficulty_code": "EASY",
                "task_status": "ACTIVE",
            }
        ]
        with self.client.session_transaction() as flask_session:
            flask_session["current_lab_id"] = 7

        response = self.client.get("/tasks")

        self.assertEqual(response.status_code, 200)
        markup = response.get_data(as_text=True)
        self.assertIn("Генетическое условие", markup)
        self.assertIn("внешние крылья могут не проявиться", markup.lower())
        self.assertIn("хотя бы в одной из двух копий гена", markup)


if __name__ == "__main__":
    unittest.main()
