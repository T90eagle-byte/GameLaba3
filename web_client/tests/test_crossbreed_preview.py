from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


WEB_ROOT = Path(__file__).resolve().parents[1]
if str(WEB_ROOT) not in sys.path:
    sys.path.insert(0, str(WEB_ROOT))

import app as app_module  # noqa: E402
from services import crossbreed_service, display_service  # noqa: E402


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


class PreviewParentAndDeduplicationTests(unittest.TestCase):
    def test_parent_card_uses_existing_display_values(self) -> None:
        row = creature(10)
        row["phenotype_summary"] += "; fin_shape=crescent_fin"

        view = display_service.parent_creature_view(row)

        self.assertEqual(view["display_name"], display_service.creature_name(row))
        self.assertEqual(view["species_label"], display_service.species_label(row))
        self.assertEqual([item["key"] for item in view["parent_traits"]], [
            "color", "has_wings", "nutrition_type", "size", "fin_shape",
        ])

    def test_duplicate_genotypes_are_not_rendered_as_distinct_samples(self) -> None:
        rows = [
            {**preview_row(1), "genotype_summary": "color=blue; size=medium"},
            {**preview_row(2), "genotype_summary": " color=blue;   size=medium "},
            {**preview_row(3), "genotype_summary": "color=green; size=medium"},
            {**preview_row(4), "genotype_summary": "color=red; size=large"},
        ]

        unique = crossbreed_service.unique_preview_rows(rows)

        self.assertEqual(len(unique), 3)
        self.assertEqual([row["option_no"] for row in unique], [1, 2, 3])
        self.assertEqual([row["genotype_summary"] for row in unique], [
            "color=blue; size=medium", "color=green; size=medium", "color=red; size=large",
        ])

    def test_all_duplicate_candidates_produce_one_honest_sample(self) -> None:
        rows = [{**preview_row(index), "genotype_summary": "color=blue"} for index in range(1, 11)]

        unique = crossbreed_service.unique_preview_rows(rows)

        self.assertEqual(len(unique), 1)
        self.assertEqual(unique[0]["option_no"], 1)


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
        self.assertIn("preview-section", markup)
        self.assertEqual(markup.count("source-note"), 3)
        self.assertNotIn("Вероятность:", markup)
        self.assertNotIn("33.3%", markup)
        self.assertNotIn("PREVIEW_ONLY", markup)
        preview.assert_called_once_with("preview-token", 7, 10, 11, options_count=3)

    @patch.object(app_module.creature_service, "get_creatures")
    def test_parent_cards_are_bound_to_each_parent_select(self, get_creatures) -> None:
        first = creature(10)
        second = creature(11)
        second["species_type"] = "crustacean"
        second["phenotype_summary"] += "; claw_form=hooked_claws"
        get_creatures.return_value = [first, second]

        response = self.client.get("/crossbreed")
        markup = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        for slot in ("one", "two"):
            self.assertIn(f'data-parent-select="{slot}"', markup)
            self.assertIn(f'data-parent-card="{slot}" data-creature-id="10"', markup)
            self.assertIn(f'data-parent-card="{slot}" data-creature-id="11"', markup)
        self.assertIn("updateParentCard", markup)
        svg_ids = re.findall(r'\bid="((?:portraitGlow|bodyTone|creatureShade|wingTone|portraitShadow)-[^"]+)"', markup)
        self.assertEqual(len(svg_ids), len(set(svg_ids)))


if __name__ == "__main__":
    unittest.main()
