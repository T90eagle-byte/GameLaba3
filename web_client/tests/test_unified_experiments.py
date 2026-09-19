from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch


WEB_ROOT = Path(__file__).resolve().parents[1]
if str(WEB_ROOT) not in sys.path:
    sys.path.insert(0, str(WEB_ROOT))

import app as app_module  # noqa: E402
from services.oracle import ServiceError  # noqa: E402


def creature(creature_id: int, species_type: int = 1) -> dict[str, object]:
    return {
        "creature_id": creature_id,
        "creature_name": f"Существо {creature_id}",
        "species_type": species_type,
        "genetics_version": 1,
        "phenotype_summary": "color=blue_color; has_wings=no_wings; nutrition_type=herbivore; size=medium_size",
    }


class UnifiedExperimentsRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.app = app_module.create_app()
        self.app.config.update(TESTING=True, SECRET_KEY="unified-test")
        self.client = self.app.test_client()
        with self.client.session_transaction() as flask_session:
            flask_session["session_token"] = "experiment-token"
            flask_session["login"] = "experiment-user"
            flask_session["current_lab_id"] = 7

    @patch.object(app_module.history_service, "get_experiment_history", return_value=[])
    def test_workspace_opens_with_five_russian_modes(self, _history) -> None:
        response = self.client.get("/experiments")
        markup = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        for label in ("Эксперименты", "Скрещивание", "Мутация", "Скрещивание + мутаген", "Гибридизация", "История"):
            self.assertIn(label, markup)
        self.assertNotIn("CROSSBREED_MUTAGEN", markup)

    @patch.object(app_module.creature_service, "get_creatures")
    def test_crossbreed_mode_preselects_current_lab_parent(self, get_creatures) -> None:
        get_creatures.return_value = [creature(10), creature(11)]

        response = self.client.get("/experiments?mode=crossbreed&parent_id=10")
        markup = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn('name="parent1_id"', markup)
        self.assertIn('value="10" data-species-type="1" selected', markup)
        self.assertIn('data-creature-id="10"', markup)

    @patch.object(app_module.creature_service, "get_creature_detail")
    @patch.object(app_module.crossbreed_service, "preview_offspring_options")
    @patch.object(app_module.creature_service, "get_lab_morphology", return_value=[])
    @patch.object(app_module.creature_service, "get_creatures")
    def test_v3_preview_uses_morphology_display_without_legacy_wings(
        self, get_creatures, _get_lab_morphology, preview, get_detail
    ) -> None:
        v3_parent = {**creature(10), "genetics_version": 3}
        get_creatures.return_value = [v3_parent, {**creature(11), "genetics_version": 3}]
        get_detail.return_value = v3_parent
        preview.return_value = [{
            "option_no": 1,
            "species_type": 1,
            "phenotype_summary": (
                "body_shape=shark_like; body_proportion=fusiform; body_size=large; "
                "body_cover=rough_skin; body_color=blue; mouth_type=jawed; snout_type=pointed; "
                "eye_type=lateral; front_appendage_count=two; front_appendage_type=fin; "
                "front_appendage_size=medium; rear_appendage_count=two; rear_appendage_type=fin; "
                "rear_appendage_size=medium; tail_type=fish; tail_size=large; dorsal_type=dorsal_fin; "
                "dorsal_size=large; nutrition_type=carnivore; has_wings=wings; color=Green"
            ),
        }]

        response = self.client.post(
            "/experiments",
            data={"mode": "crossbreed", "action": "preview", "parent1_id": "10", "parent2_id": "11"},
        )

        markup = response.get_data(as_text=True)
        self.assertEqual(response.status_code, 200)
        self.assertIn("morphology-svg", markup)
        self.assertIn("акулообразная форма", markup)
        self.assertIn("Питание", markup)
        self.assertIn("хищное", markup)
        self.assertNotIn("Крылья", markup)
        self.assertNotIn("Green", markup)
        preview.assert_called_once_with("experiment-token", 7, 10, 11, options_count=3)

    @patch.object(app_module.creature_service, "get_creatures")
    def test_invalid_parent_is_not_preselected(self, get_creatures) -> None:
        get_creatures.return_value = [creature(10), creature(11)]

        response = self.client.get("/experiments?mode=crossbreed_mutagen&parent_id=999")

        self.assertEqual(response.status_code, 200)
        self.assertNotIn(b'value="999" selected', response.data)

    @patch.object(app_module.creature_service, "get_creatures")
    def test_mutation_mode_redirects_to_mutations_with_creature(self, get_creatures) -> None:
        get_creatures.return_value = [creature(10)]

        response = self.client.get("/experiments?mode=mutation&creature_id=10")

        self.assertEqual(response.status_code, 302)
        self.assertTrue(response.headers["Location"].endswith("/mutations?creature_id=10"))

    @patch.object(app_module.lab_service, "get_lab_stats", side_effect=[{"wallet": 1000, "rating": 10}, {"wallet": 950, "rating": 5}])
    @patch.object(app_module.task_service, "get_tasks", side_effect=[[], []])
    @patch.object(app_module.crossbreed_service, "crossbreed_with_mutagen_details", return_value=(42, [{"gene_code": "body_size", "gene_display_name": "Размер тела", "allele_slot": 1, "old_allele_display_name": "средний", "new_allele_display_name": "крупный", "phenotype_before": "body_size=medium", "phenotype_after": "body_size=large", "phenotype_changed": "Y"}]))
    def test_combined_mode_uses_one_service_call_and_one_shot_feedback(
        self, combined, _tasks, _stats
    ) -> None:
        response = self.client.post(
            "/experiments",
            data={
                "mode": "crossbreed_mutagen",
                "action": "crossbreed_mutagen",
                "parent1_id": "10",
                "parent2_id": "11",
                "offspring_name": "Итоговый потомок",
                "mutagen_type": "RADIATION",
            },
        )

        self.assertEqual(response.status_code, 302)
        self.assertTrue(response.headers["Location"].endswith("/creatures/42"))
        combined.assert_called_once_with("experiment-token", 7, 10, 11, "RADIATION", "Итоговый потомок")
        with self.client.session_transaction() as flask_session:
            feedback = flask_session["action_feedback"]
        self.assertEqual(feedback["kind"], "combined")
        self.assertEqual(feedback["result_creature_id"], 42)
        self.assertEqual(feedback["mutagen_label"], "Облучение")

    @patch.object(app_module.crossbreed_service, "crossbreed_with_mutagen_details", side_effect=ServiceError("Эти родители несовместимы."))
    @patch.object(app_module.lab_service, "get_lab_stats", return_value={"wallet": 1000, "rating": 10})
    @patch.object(app_module.task_service, "get_tasks", return_value=[])
    @patch.object(app_module.creature_service, "get_creatures", return_value=[creature(10), creature(11, 2)])
    def test_combined_rejection_is_safe_and_creates_no_feedback(
        self, _creatures, _tasks, _stats, combined
    ) -> None:
        response = self.client.post(
            "/experiments",
            data={
                "mode": "crossbreed_mutagen",
                "action": "crossbreed_mutagen",
                "parent1_id": "10",
                "parent2_id": "11",
                "offspring_name": "Нельзя",
                "mutagen_type": "CHEMICAL",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("Эти родители несовместимы".encode(), response.data)
        with self.client.session_transaction() as flask_session:
            self.assertNotIn("action_feedback", flask_session)
        combined.assert_called_once()

    @patch.object(app_module.creature_service, "get_creatures")
    def test_hybridization_mode_shows_only_normal_parents_and_radiation(self, get_creatures) -> None:
        get_creatures.return_value = [creature(10, 1), creature(11, 2), creature(12, 7)]

        response = self.client.get("/experiments?mode=hybridization")
        markup = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("Контролируемая гибридизация", markup)
        self.assertIn("Провести гибридизацию", markup)
        self.assertIn("Облучение", markup)
        self.assertNotIn("Химический мутаген", markup)
        self.assertIn('value="10" data-species-type="1"', markup)
        self.assertIn('value="11" data-species-type="2"', markup)
        self.assertNotIn('value="12" data-species-type="7"', markup)

    @patch.object(app_module.rating_service, "get_rating_events", side_effect=[[], [{
        "rating_event_id": 90,
        "event_type": "HYBRIDIZATION_PENALTY",
        "creature_id": 42,
        "rating_delta": -20,
    }]])
    @patch.object(app_module.lab_service, "get_lab_stats", side_effect=[
        {"wallet": 1000, "rating": 20},
        {"wallet": 1200, "rating": 0},
    ])
    @patch.object(app_module.task_service, "get_tasks", side_effect=[[], [{
        "task_id": 3,
        "task_name": "task_v3_disc_saw",
        "task_display_name": "Скат с пилообразным рылом",
        "task_status": "COMPLETED",
        "reward_money": 200,
        "reward_rating": 30,
    }]])
    @patch.object(app_module.crossbreed_service, "hybridize_details", return_value=(42, [{"gene_code": "body_size", "gene_display_name": "Размер тела", "allele_slot": 1, "old_allele_display_name": "средний", "new_allele_display_name": "крупный", "phenotype_before": "body_size=medium", "phenotype_after": "body_size=large", "phenotype_changed": "Y"}]))
    def test_hybridization_uses_one_service_call_and_records_actual_penalty(
        self, hybridize, _tasks, _stats, _events
    ) -> None:
        response = self.client.post(
            "/experiments",
            data={
                "mode": "hybridization",
                "action": "hybridization",
                "parent1_id": "10",
                "parent2_id": "11",
                "offspring_name": "Первый гибрид",
            },
        )

        self.assertEqual(response.status_code, 302)
        self.assertTrue(response.headers["Location"].endswith("/creatures/42"))
        hybridize.assert_called_once_with("experiment-token", 7, 10, 11, "Первый гибрид")
        with self.client.session_transaction() as flask_session:
            feedback = flask_session["action_feedback"]
        self.assertEqual(feedback["kind"], "hybridization")
        self.assertEqual(feedback["mutagen_label"], "Облучение")
        self.assertEqual(feedback["rating_penalty_label"], "-20")
        self.assertEqual(len(feedback["completed_tasks"]), 1)

    @patch.object(app_module.crossbreed_service, "hybridize_details", side_effect=ServiceError("Для гибридизации выберите существ двух разных видов."))
    @patch.object(app_module.lab_service, "get_lab_stats", return_value={"wallet": 1000, "rating": 10})
    @patch.object(app_module.task_service, "get_tasks", return_value=[])
    @patch.object(app_module.rating_service, "get_rating_events", return_value=[])
    @patch.object(app_module.creature_service, "get_creatures", return_value=[creature(10), creature(11)])
    def test_same_species_hybridization_rejection_is_safe(
        self, _creatures, _events, _tasks, _stats, hybridize
    ) -> None:
        response = self.client.post(
            "/experiments",
            data={
                "mode": "hybridization",
                "action": "hybridization",
                "parent1_id": "10",
                "parent2_id": "11",
                "offspring_name": "Нельзя",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("Для гибридизации выберите существ двух разных видов".encode(), response.data)
        hybridize.assert_called_once()
        with self.client.session_transaction() as flask_session:
            self.assertNotIn("action_feedback", flask_session)

    @patch.object(app_module.history_service, "get_experiment_history")
    def test_combined_history_is_russian_and_links_result(self, get_history) -> None:
        get_history.return_value = [{
            "experiment_id": 1,
            "experiment_type": "CROSSBREED_MUTAGEN",
            "parent1_id": 10,
            "parent2_id": 11,
            "offspring_id": 42,
            "mutagen_type": "CHEMICAL",
            "created_at": None,
        }]

        response = self.client.get("/experiments?mode=history")
        markup = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("Скрещивание + мутаген", markup)
        self.assertIn("Химический мутаген", markup)
        self.assertIn('href="/creatures/42"', markup)
        self.assertNotIn("CROSSBREED_MUTAGEN", markup)
        self.assertNotIn("CHEMICAL", markup)

    @patch.object(app_module.history_service, "get_experiment_history")
    def test_controlled_mutation_history_keeps_mutation_reference(self, get_history) -> None:
        get_history.return_value = [{
            "experiment_id": 2,
            "experiment_type": "MUTATION",
            "parent1_id": 10,
            "offspring_id": 10,
            "mutation_id": 7,
            "created_at": None,
        }]

        response = self.client.get("/experiments?mode=history")

        self.assertEqual(response.status_code, 200)
        self.assertIn("Мутация #7", response.get_data(as_text=True))

    @patch.object(app_module.history_service, "get_experiment_history")
    def test_hybridization_history_is_russian_and_links_hybrid(self, get_history) -> None:
        get_history.return_value = [{
            "experiment_id": 3,
            "experiment_type": "HYBRIDIZATION",
            "parent1_id": 10,
            "parent2_id": 11,
            "offspring_id": 42,
            "mutagen_type": "RADIATION",
            "created_at": None,
        }]

        response = self.client.get("/experiments?mode=history")
        markup = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("Гибридизация", markup)
        self.assertIn("Облучение", markup)
        self.assertIn('href="/creatures/42"', markup)
        self.assertNotIn("HYBRIDIZATION", markup)
        self.assertNotIn("RADIATION", markup)


if __name__ == "__main__":
    unittest.main()
