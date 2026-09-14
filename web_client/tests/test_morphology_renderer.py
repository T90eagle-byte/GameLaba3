from __future__ import annotations

import re
import unittest

from web_client.services.display_service import MORPHOLOGY_GENE_CODES, build_creature_view
from web_client.services.morphology_renderer import VIEW_BOX, render_creature_portrait


def morphology_rows(overrides: dict[str, str] | None = None) -> list[dict[str, str]]:
    values = {
        "body_shape": "streamlined", "body_proportion": "fusiform", "body_size": "medium",
        "body_cover": "smooth_skin", "body_color": "blue", "mouth_type": "standard",
        "snout_type": "standard", "eye_type": "standard", "front_appendage_count": "two",
        "front_appendage_type": "fin", "front_appendage_size": "medium", "rear_appendage_count": "two",
        "rear_appendage_type": "fin", "rear_appendage_size": "medium", "tail_type": "fish",
        "tail_size": "medium", "dorsal_type": "dorsal_fin", "dorsal_size": "medium",
    }
    values.update(overrides or {})
    return [
        {
            "gene_code": code,
            "gene_display_name": code,
            "expressed_allele_code": values[code],
            "expressed_display_name": values[code],
        }
        for code in MORPHOLOGY_GENE_CODES
    ]


def v3_view(overrides: dict[str, str] | None = None, **row: object) -> dict[str, object]:
    return build_creature_view({"creature_id": 17, "genetics_version": 3, **row}, morphology_rows(overrides))


class MorphologyRendererTests(unittest.TestCase):
    def render(self, overrides: dict[str, str] | None = None, uid: str = "v3-17") -> str:
        portrait = render_creature_portrait(v3_view(overrides), uid, "mini")
        self.assertIsNotNone(portrait)
        return str(portrait)

    def test_v3_renderer_uses_the_normalized_oracle_visual_state_only(self) -> None:
        markup = self.render({"front_appendage_count": "zero", "front_appendage_type": "claw", "front_appendage_size": "large", "tail_type": "none", "tail_size": "large"})
        self.assertIn('data-count="zero"', markup)
        self.assertIn('data-appendage-type="none"', markup)
        self.assertIn('data-tail-type="none"', markup)
        self.assertNotIn("has-wings", markup)
        self.assertNotIn("nutrition", markup)

    def test_all_universal_value_families_have_semantic_svg_hooks(self) -> None:
        shapes = ("streamlined", "shark_like", "disc", "eel_like", "cetacean", "pinniped", "crustacean", "shrimp_like", "cephalopod", "snail_like")
        for shape in shapes:
            with self.subTest(shape=shape):
                self.assertIn(f'data-shape="{shape}"', self.render({"body_shape": shape}))
        for cover in ("smooth_skin", "scales", "rough_skin", "chitin", "hard_shell", "leathery_skin", "soft_body"):
            with self.subTest(cover=cover):
                self.assertIn(f'data-cover="{cover}"', self.render({"body_cover": cover}))
        for proportion in ("elongated", "compact", "broad", "flattened", "fusiform"):
            with self.subTest(proportion=proportion):
                self.assertIn(f'data-proportion="{proportion}"', self.render({"body_proportion": proportion}))
        for color in ("gray", "blue", "green", "brown", "red", "orange", "yellow", "black", "white"):
            with self.subTest(color=color):
                self.assertIn(f'data-color="{color}"', self.render({"body_color": color}))
        for size in ("small", "medium", "large", "giant"):
            with self.subTest(size=size):
                self.assertIn(f'data-body-size="{size}"', self.render({"body_size": size}))
        for tail in ("fish", "cetacean", "crustacean", "elongated", "paddle", "none"):
            with self.subTest(tail=tail):
                self.assertIn(f'data-tail-type="{tail}"', self.render({"tail_type": tail}))
        for dorsal in ("none", "dorsal_fin", "shell", "carapace", "ridge"):
            with self.subTest(dorsal=dorsal):
                self.assertIn(f'data-dorsal-type="{dorsal}"', self.render({"dorsal_type": dorsal}))

    def test_appendages_head_and_dorsal_have_distinct_structural_state(self) -> None:
        markup = self.render({
            "front_appendage_count": "eight", "front_appendage_type": "tentacle", "front_appendage_size": "large",
            "rear_appendage_count": "six", "rear_appendage_type": "walking_leg", "rear_appendage_size": "small",
            "snout_type": "hammer", "mouth_type": "filter_feeding", "eye_type": "stalked",
            "dorsal_type": "carapace", "dorsal_size": "large",
        })
        for expected in ('data-count="eight"', 'appendage-tentacle', 'data-count="six"', 'appendage-walking_leg', 'data-snout="hammer"', 'data-mouth="filter_feeding"', 'data-eye="stalked"', 'data-dorsal-type="carapace"'):
            self.assertIn(expected, markup)

    def test_all_appendage_head_variants_have_safe_state(self) -> None:
        for kind in ("none", "fin", "flipper", "walking_leg", "claw", "tentacle"):
            with self.subTest(front=kind):
                markup = self.render({"front_appendage_type": kind, "front_appendage_count": "two" if kind != "none" else "zero"})
                self.assertIn(f'data-appendage-type="{kind}"', markup)
        for kind in ("none", "fin", "flipper", "walking_leg", "tentacle"):
            with self.subTest(rear=kind):
                markup = self.render({"rear_appendage_type": kind, "rear_appendage_count": "two" if kind != "none" else "zero"})
                self.assertIn(f'data-appendage-type="{kind}"', markup)
        for snout in ("standard", "pointed", "blunt", "saw", "hammer", "elongated"):
            self.assertIn(f'data-snout="{snout}"', self.render({"snout_type": snout}))
        for mouth in ("standard", "beak", "suction", "filter_feeding", "jawed"):
            self.assertIn(f'data-mouth="{mouth}"', self.render({"mouth_type": mouth}))
        for eye in ("standard", "large", "lateral", "stalked"):
            self.assertIn(f'data-eye="{eye}"', self.render({"eye_type": eye}))

    def test_size_color_and_proportion_change_semantic_state_without_clipping_viewbox(self) -> None:
        markup = self.render({"body_size": "giant", "body_color": "white", "body_proportion": "flattened"})
        self.assertIn(f'viewBox="{VIEW_BOX}"', markup)
        self.assertIn('data-body-size="giant"', markup)
        self.assertIn('data-color="white"', markup)
        self.assertIn('data-proportion="flattened"', markup)

    def test_ids_are_unique_and_uid_is_sanitized(self) -> None:
        first = self.render(uid="fish 1<script>")
        second = self.render(uid="fish 2<script>")
        ids = re.findall(r'\bid="([^"]+)"', first + second)
        self.assertEqual(len(ids), len(set(ids)))
        self.assertNotIn("<script>", first)
        self.assertIn("morph-tone-fish-1-script", first)

    def test_unknown_values_fall_back_without_interpolating_untrusted_markup(self) -> None:
        markup = self.render({"body_shape": "<bad>", "body_color": "unknown_value"})
        self.assertIn('data-shape="unknown"', markup)
        self.assertIn('data-color="unknown_value"', markup)
        self.assertNotIn("<bad>", markup)

    def test_legacy_models_stay_on_the_existing_macro_path(self) -> None:
        self.assertIsNone(render_creature_portrait({"display_model": "legacy"}, "legacy"))


if __name__ == "__main__":
    unittest.main()
