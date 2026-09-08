from __future__ import annotations

import re
import unittest
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

from web_client.services.display_service import creature_visual


TEMPLATE_DIR = Path(__file__).resolve().parents[1] / "templates"
CSS_PATH = Path(__file__).resolve().parents[1] / "static" / "css" / "app.css"


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

    def test_fin_variants_and_size_classes_have_distinct_structural_hooks(self) -> None:
        crescent = self.render("cartilaginous_fish", "fin_shape=crescent_fin; size=large_size", "crescent")
        ribbon = self.render("bony_fish", "fin_shape=ribbon_fin; size=compact_size", "ribbon")

        self.assertIn("feature-crescent-fin", crescent)
        self.assertIn("crescent-fin", crescent)
        self.assertIn("size-large", crescent)
        self.assertIn("feature-ribbon-fin", ribbon)
        self.assertIn("ribbon-fin-detail", ribbon)
        self.assertIn("size-compact", ribbon)
        self.assertIn('viewBox="-18 -14 296 188"', crescent)

    def test_wings_have_a_dedicated_layer_and_no_wings_hide_it_by_class(self) -> None:
        winged = self.render("mammal", "has_wings=has_wings", "winged")
        wingless = self.render("mammal", "has_wings=no_wings", "wingless")

        self.assertIn("has-wings", winged)
        self.assertIn("no-wings", wingless)
        self.assertIn("svg-wings", winged)

    def test_all_six_species_keep_the_safe_viewbox(self) -> None:
        species = ("cartilaginous_fish", "bony_fish", "crustacean", "mollusk", "turtle", "mammal")
        for index, species_code in enumerate(species, 1):
            with self.subTest(species=species_code):
                markup = self.render(species_code, "color=green_color; size=medium_size", f"species-{index}")
                self.assertIn('viewBox="-18 -14 296 188"', markup)
                self.assertIn(f"species-{species_code.replace('_', '-')}", markup)

    def test_legacy_portrait_rules_are_limited_to_direct_children(self) -> None:
        css = CSS_PATH.read_text(encoding="utf-8")
        self.assertIn(".creature-portrait > .tail", css)
        self.assertIn(".species-turtle > .head", css)
        self.assertNotIn(".creature-portrait .tail", css)
        self.assertNotIn(".species-turtle .head", css)


if __name__ == "__main__":
    unittest.main()
