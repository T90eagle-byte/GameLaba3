from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch


WEB_ROOT = Path(__file__).resolve().parents[1]
if str(WEB_ROOT) not in sys.path:
    sys.path.insert(0, str(WEB_ROOT))

import app as app_module  # noqa: E402
from services import display_service  # noqa: E402


def creature(creature_id: int) -> dict[str, object]:
    return {
        "creature_id": creature_id,
        "creature_name": f"Родитель {creature_id}",
        "species_type": "cartilaginous_fish",
        "phenotype_summary": "color=blue_color; has_wings=no_wings; nutrition_type=herbivore; size=medium_size",
    }


def preview_row(option_no: int) -> dict[str, object]:
    return {
        "option_no": option_no,
        "species_type": "cartilaginous_fish",
        "species_label": "Хрящевая рыба",
        # Deliberately simulate an old API payload: the UI must not expose this fake value.
        "probability": 1 / 3,
        "phenotype_summary": "color=blue_color; has_wings=no_wings; nutrition_type=herbivore; size=medium_size",
        "genotype_summary": "color=blue_color; size=medium_size",
        "source_note": "PREVIEW_ONLY",
    }


class PreviewDisplayTests(unittest.TestCase):
    def test_preview_view_does_not_turn_card_count_into_probability(self) -> None:
        view = display_service.preview_view(preview_row(1))

        self.assertNotIn("probability", view)
        self.assertNotIn("probability_label", view)
        self.assertEqual(view["source_note"], "Пример возможного потомства")


class CrossbreedPreviewRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.app = app_module.create_app()
        self.app.config.update(TESTING=True, SECRET_KEY="test-secret")
        self.client = self.app.test_client()
        with self.client.session_transaction() as flask_session:
            flask_session["session_token"] = "preview-token"
            flask_session["login"] = "preview-tester"
            flask_session["current_lab_id"] = 7

    @patch.object(app_module.crossbreed_service, "preview_offspring_options")
    @patch.object(app_module.creature_service, "get_creatures")
    def test_preview_renders_three_samples_without_fake_probability(self, get_creatures, preview) -> None:
        get_creatures.return_value = [creature(10), creature(11)]
        preview.return_value = [preview_row(1), preview_row(2), preview_row(3)]

        response = self.client.post(
            "/crossbreed",
            data={"action": "preview", "parent1_id": "10", "parent2_id": "11", "options_count": "3"},
        )

        markup = response.get_data(as_text=True)
        self.assertEqual(response.status_code, 200)
        self.assertIn("Три примера возможного потомства", markup)
        self.assertEqual(markup.count("Пример возможного потомства"), 3)
        self.assertNotIn("Вероятность:", markup)
        self.assertNotIn("33.3%", markup)
        self.assertNotIn("PREVIEW_ONLY", markup)
        preview.assert_called_once_with("preview-token", 7, 10, 11, options_count=3)


if __name__ == "__main__":
    unittest.main()
