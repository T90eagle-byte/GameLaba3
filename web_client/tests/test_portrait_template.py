from __future__ import annotations

import re
import unittest
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from web_client.services.display_service import creature_visual


TEMPLATE_DIR = Path(__file__).resolve().parents[1] / "templates"


class PortraitTemplateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        environment = Environment(loader=FileSystemLoader(TEMPLATE_DIR), autoescape=True)
        cls.macro = environment.get_template("_portrait.html").module.creature_portrait

    def render(self, species: str, summary: str, uid: str, size: str = "") -> str:
        return str(self.macro(creature_visual({"species_type": species, "phenotype_summary": summary}), size, uid))

    def test_each_portrait_has_unique_gradient_and_filter_ids(self) -> None:
        first = self.render("turtle", "color=green_color; size=large_size", "turtle-17", "large")
        second = self.render("crustacean", "color=red_color; size=compact_size", "crab-22", "mini")
        combined = first + second
        ids = re.findall(r'\bid="([^"]+)"', combined)

        self.assertEqual(len(ids), len(set(ids)))
        for uid in ("turtle-17", "crab-22"):
            self.assertIn(f'bodyTone-{uid}', ids)
            self.assertIn(f'creatureShade-{uid}', ids)
            self.assertIn(f'portraitShadow-{uid}', ids)

    def test_turtle_has_distinct_head_neck_eye_mouth_limb_and_tail_parts(self) -> None:
        markup = self.render(
            "turtle",
            "shell_armor=plated_shell; speed_level=fast_speed; has_wings=wings; nutrition_type=herbivore",
            "turtle-anatomy",
        )
        for expected in ("svg-turtle", "class=\"neck", "class=\"head", "class=\"mouth", "front-top", "rear-top", "class=\"tail"):
            self.assertIn(expected, markup)

    def test_crustacean_has_forward_anatomy_and_separate_claws(self) -> None:
        markup = self.render(
            "crustacean",
            "claw_form=hooked_claws; shell_armor=ridged_armor; nutrition_type=carnivore/herbivore",
            "crab-anatomy",
        )
        for expected in ("cephalothorax", "abdomen", "eye-stalk", "antenna", "mouth", "claw upper", "claw lower", "armor-segments"):
            self.assertIn(expected, markup)

    def test_nutrition_badge_supports_all_three_modes(self) -> None:
        cases = {
            "herbivore": "nutrition-herbivore",
            "carnivore": "nutrition-carnivore",
            "herbivore/carnivore": "nutrition-mixed",
        }
        for nutrition, expected_class in cases.items():
            with self.subTest(nutrition=nutrition):
                markup = self.render("turtle", f"nutrition_type={nutrition}", f"food-{expected_class}")
                self.assertIn(expected_class, markup)
                self.assertIn("nutrition-icons", markup)


if __name__ == "__main__":
    unittest.main()
