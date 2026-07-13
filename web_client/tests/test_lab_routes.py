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


class LabRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.app = app_module.create_app()
        self.app.config.update(TESTING=True, SECRET_KEY="test-secret")
        self.client = self.app.test_client()
        with self.client.session_transaction() as flask_session:
            flask_session["session_token"] = "current-token"
            flask_session["login"] = "tester"

    @staticmethod
    def conflict() -> ServiceError:
        return ServiceError(LAB_SESSION_CONFLICT_MESSAGE)

    @patch.object(app_module.lab_service, "reset_other_user_sessions")
    @patch.object(app_module.lab_service, "load_lab")
    def test_open_recovers_once_from_old_session(self, load_lab: Mock, reset: Mock) -> None:
        load_lab.side_effect = [self.conflict(), None]

        response = self.client.post(
            "/labs",
            data={"action": "open", "lab_id": "42"},
        )

        self.assertEqual(response.status_code, 302)
        self.assertEqual(load_lab.call_count, 2)
        reset.assert_called_once_with("current-token")
        with self.client.session_transaction() as flask_session:
            self.assertEqual(flask_session["current_lab_id"], 42)

    @patch.object(app_module.lab_service, "list_user_labs", return_value=[])
    @patch.object(app_module.lab_service, "reset_other_user_sessions")
    @patch.object(app_module.lab_service, "load_lab")
    def test_open_surfaces_second_error_without_more_retries(
        self,
        load_lab: Mock,
        reset: Mock,
        _list_labs: Mock,
    ) -> None:
        load_lab.side_effect = [self.conflict(), ServiceError("Повторная ошибка открытия.")]

        response = self.client.post(
            "/labs",
            data={"action": "open", "lab_id": "42"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(load_lab.call_count, 2)
        reset.assert_called_once_with("current-token")
        self.assertIn("Повторная ошибка открытия".encode(), response.data)

    @patch.object(app_module.lab_service, "reset_other_user_sessions")
    @patch.object(app_module.lab_service, "delete_lab")
    def test_delete_recovers_once_from_old_session(self, delete_lab: Mock, reset: Mock) -> None:
        delete_lab.side_effect = [self.conflict(), None]

        response = self.client.post(
            "/labs",
            data={"action": "delete", "lab_id": "51"},
        )

        self.assertEqual(response.status_code, 302)
        self.assertEqual(delete_lab.call_count, 2)
        reset.assert_called_once_with("current-token")

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
        self.assertIn("Аллели: зелёный / синий".encode(), response.data)
        self.assertIn("Результат".encode(), response.data)
        self.assertIn("зелёный".encode(), response.data)
        self.assertNotIn("Технические значения".encode(), response.data)
        self.assertNotIn(b">10 / 20<", response.data)

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
        self.assertIn("Специальный заказ".encode(), response.data)
        self.assertNotIn(b"task_armored_crustacean", response.data)
        self.assertNotIn(b"task_future_unknown", response.data)


if __name__ == "__main__":
    unittest.main()
