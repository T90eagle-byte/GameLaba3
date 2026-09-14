from __future__ import annotations

import unittest

from web_client.services.display_service import (
    MORPHOLOGY_GENE_CODES,
    build_creature_view,
)


def morphology_rows() -> list[dict[str, str]]:
    values = {
        "body_shape": ("cetacean", "Китообразная форма"),
        "body_proportion": ("fusiform", "Веретенообразные пропорции"),
        "body_size": ("large", "Крупный"),
        "body_cover": ("smooth_skin", "Гладкая кожа"),
        "body_color": ("blue", "Синий"),
        "mouth_type": ("filter_feeding", "Фильтрующий рот"),
        "snout_type": ("blunt", "Тупая морда"),
        "eye_type": ("lateral", "Боковые глаза"),
        "front_appendage_count": ("zero", "Нет передних конечностей"),
        "front_appendage_type": ("flipper", "Ласты"),
        "front_appendage_size": ("large", "Крупные"),
        "rear_appendage_count": ("two", "Две"),
        "rear_appendage_type": ("flipper", "Ласты"),
        "rear_appendage_size": ("medium", "Средние"),
        "tail_type": ("none", "Нет хвоста"),
        "tail_size": ("large", "Крупный"),
        "dorsal_type": ("none", "Нет спинного элемента"),
        "dorsal_size": ("large", "Крупный"),
    }
    return [
        {
            "gene_code": code,
            "gene_display_name": "Размер тела" if code == "body_size" else f"Признак {index + 1}",
            "expressed_allele_code": values[code][0],
            "expressed_display_name": values[code][1],
        }
        for index, code in enumerate(MORPHOLOGY_GENE_CODES)
    ]


class VersionAwareCreatureViewTests(unittest.TestCase):
    def test_legacy_view_keeps_existing_phenotype_without_morphology(self) -> None:
        view = build_creature_view(
            {
                "creature_id": 7,
                "creature_name": "turtle #7",
                "species_type": "turtle",
                "phenotype_summary": "color=green_color; size=medium_size",
                "genetics_version": 1,
                "archetype_id": None,
            },
            morphology_rows(),
        )

        self.assertEqual(view["display_model"], "legacy")
        self.assertTrue(view["phenotype_items"])
        self.assertEqual(view["morphology"], {})
        self.assertIsNone(view["archetype"])

    def test_v3_view_uses_all_oracle_morphology_traits_and_archetype(self) -> None:
        view = build_creature_view(
            {
                "creature_id": 8,
                "creature_name": "mammal #8",
                "species_type": "mammal",
                "genetics_version": 3,
                "archetype_id": 42,
                "archetype_code": "whale",
                "archetype_display_name": "Кит",
                "phenotype_summary": "color=legacy_green; size=legacy_small; has_wings=wings",
            },
            morphology_rows(),
        )

        self.assertEqual(view["display_model"], "morphology")
        self.assertEqual(tuple(view["morphology"]), MORPHOLOGY_GENE_CODES)
        self.assertEqual(len(view["morphology_traits"]), 18)
        self.assertEqual(view["morphology"]["body_color"]["value"], "Синий")
        self.assertEqual(view["morphology"]["body_color"]["technical_value"], "blue")
        self.assertEqual(view["morphology"]["body_size"]["label"], "Размер тела")
        self.assertNotIn("color", view["morphology"])
        self.assertNotIn("size", view["morphology"])
        self.assertNotIn("has_wings", view["morphology"])
        self.assertNotIn("legacy_green", view["phenotype_text"])
        self.assertEqual(view["archetype"], {"archetype_id": 42, "code": "whale", "display_name": "Кит"})

    def test_visual_normalization_ignores_inapplicable_parts_but_keeps_raw_traits(self) -> None:
        view = build_creature_view({"genetics_version": 3, "species_type": 6}, morphology_rows())

        self.assertEqual(view["morphology"]["front_appendage_type"]["technical_value"], "flipper")
        self.assertEqual(view["morphology_visual_state"]["front_appendage_type"], "none")
        self.assertEqual(view["morphology_visual_state"]["front_appendage_size"], "none")
        self.assertEqual(view["morphology_visual_state"]["rear_appendage_type"], "flipper")
        self.assertEqual(view["morphology_visual_state"]["rear_appendage_size"], "medium")
        self.assertEqual(view["morphology_visual_state"]["tail_size"], "none")
        self.assertEqual(view["morphology_visual_state"]["dorsal_size"], "none")


if __name__ == "__main__":
    unittest.main()
