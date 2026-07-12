from __future__ import annotations

import unittest

from web_client.services.display_service import creature_visual


def visual(species: str, summary: str) -> dict[str, str]:
    return creature_visual({"species_type": species, "phenotype_summary": summary})


class CreatureVisualTests(unittest.TestCase):
    def test_all_six_species_have_distinct_classes(self) -> None:
        expected = {
            "cartilaginous_fish": "species-cartilaginous-fish",
            "bony_fish": "species-bony-fish",
            "crustacean": "species-crustacean",
            "mollusk": "species-mollusk",
            "turtle": "species-turtle",
            "mammal": "species-mammal",
        }
        for species, species_class in expected.items():
            with self.subTest(species=species):
                self.assertEqual(
                    visual(species, "color=green_color; size=medium_size")["species_class"],
                    species_class,
                )

    def test_multiple_feature_classes_are_preserved(self) -> None:
        result = visual(
            "crustacean",
            "claw_form=hooked_claws; shell_armor=ridged_armor; size=large_size",
        )
        classes = set(result["feature_classes"].split())
        self.assertIn("feature-hooked-claws", classes)
        self.assertIn("feature-ridged-armor", classes)

    def test_solid_and_mixed_colors(self) -> None:
        solid = visual("bony_fish", "color=blue_color")
        mixed = visual("bony_fish", "color=orange_color/purple_color")
        self.assertEqual(solid["tone_class"], "tone-blue")
        self.assertEqual(solid["tone_mode_class"], "tone-solid")
        self.assertEqual(solid["tone_style"], "")
        self.assertEqual(mixed["tone_mode_class"], "tone-mixed")
        self.assertIn("--creature-tone:", mixed["tone_style"])
        self.assertIn("--creature-tone-secondary:", mixed["tone_style"])

    def test_medium_large_and_intermediate_sizes(self) -> None:
        self.assertEqual(visual("turtle", "size=medium_size")["size_class"], "size-medium")
        self.assertEqual(visual("turtle", "size=large_size")["size_class"], "size-large")
        self.assertEqual(
            visual("turtle", "size=intermediate(medium_size/large_size)")["size_class"],
            "size-intermediate-medium-large",
        )
        self.assertEqual(
            visual("turtle", "size=intermediate(compact_size/medium_size)")["size_class"],
            "size-intermediate-compact-medium",
        )

    def test_wings_present_and_absent(self) -> None:
        self.assertEqual(visual("mammal", "has_wings=wings")["wings_class"], "has-wings")
        self.assertEqual(visual("mammal", "has_wings=no_wings")["wings_class"], "no-wings")

    def test_three_nutrition_modes(self) -> None:
        self.assertEqual(visual("mollusk", "nutrition_type=herbivore")["nutrition_class"], "nutrition-herbivore")
        self.assertEqual(visual("mollusk", "nutrition_type=carnivore")["nutrition_class"], "nutrition-carnivore")
        self.assertEqual(
            visual("mollusk", "nutrition_type=herbivore/carnivore")["nutrition_class"],
            "nutrition-mixed",
        )


if __name__ == "__main__":
    unittest.main()
