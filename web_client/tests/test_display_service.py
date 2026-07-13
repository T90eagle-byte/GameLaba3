from __future__ import annotations

import unittest

from web_client.services.display_service import creature_visual, genotype_view, phenotype_items


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

    def test_crustacean_claw_and_armor_variants_are_composable(self) -> None:
        for claws in ("short_claws", "long_claws", "hooked_claws"):
            for armor in ("thick_armor", "ridged_armor"):
                with self.subTest(claws=claws, armor=armor):
                    classes = visual(
                        "crustacean",
                        f"claw_form={claws}; shell_armor={armor}; nutrition_type=carnivore/herbivore",
                    )["feature_classes"]
                    self.assertIn(f"feature-{claws.replace('_', '-')}", classes)
                    self.assertIn(f"feature-{armor.replace('_', '-')}", classes)

    def test_turtle_shell_speed_size_and_wings_are_composable(self) -> None:
        result = visual(
            "turtle",
            "shell_armor=plated_shell; speed_level=fast_speed; has_wings=wings; "
            "size=intermediate(medium_size/large_size); nutrition_type=herbivore",
        )
        self.assertEqual(result["wings_class"], "has-wings")
        self.assertEqual(result["size_class"], "size-intermediate-medium-large")
        self.assertEqual(result["nutrition_class"], "nutrition-herbivore")
        self.assertIn("feature-plated-shell", result["feature_classes"])
        self.assertIn("feature-fast-speed", result["feature_classes"])


class GenotypeDisplayTests(unittest.TestCase):
    @staticmethod
    def row(gene: str, allele1: str, value1: float, allele2: str, value2: float, dominance: str = "FULL") -> dict[str, object]:
        return {
            "gene_name": gene,
            "dominance_type": dominance,
            "allele1_display_name": allele1,
            "allele1_trait_value": value1,
            "allele2_display_name": allele2,
            "allele2_trait_value": value2,
        }

    def render(self, summary: str, rows: list[dict[str, object]]) -> dict[str, dict[str, object]]:
        phenotype = phenotype_items({"phenotype_summary": summary})
        return {item["gene_code"]: item for item in genotype_view(rows, phenotype)}

    def test_cartilaginous_blue_mixed_compact_medium_pointed(self) -> None:
        rows = [
            self.row("color", "blue_color", 20, "white_color", 70),
            self.row("has_wings", "wings", 1, "no_wings", 0),
            self.row("nutrition_type", "carnivore", 20, "herbivore", 10, "CODOMINANT"),
            self.row("size", "medium_size", 15, "compact_size", 10, "INCOMPLETE"),
            self.row("fin_shape", "pointed_fin", 10, "broad_fin", 20),
        ]
        rendered = self.render(
            "color=blue_color; has_wings=no_wings; nutrition_type=carnivore/herbivore; "
            "size=intermediate(compact_size/medium_size); fin_shape=pointed_fin",
            rows,
        )
        self.assertEqual(rendered["color"]["pair_label"], "Аллели: синий / белый")
        self.assertEqual(rendered["color"]["result_label"], "синий")
        self.assertEqual(rendered["has_wings"]["result_label"], "без крыльев")
        self.assertEqual(rendered["nutrition_type"]["result_label"], "смешанное")
        self.assertEqual(rendered["size"]["result_label"], "промежуточный между компактным и средним")
        self.assertEqual(rendered["fin_shape"]["result_label"], "заострённый плавник")
        self.assertEqual(rendered["color"]["technical_pair_label"], "20 / 70")
        self.assertEqual(rendered["has_wings"]["technical_pair_label"], "1 / 0")

    def test_cartilaginous_green_winged_medium_crescent(self) -> None:
        rendered = self.render(
            "color=green_color; has_wings=wings; nutrition_type=herbivore/carnivore; "
            "size=medium_size; fin_shape=crescent_fin",
            [
                self.row("color", "green_color", 10, "yellow_color", 40),
                self.row("has_wings", "wings", 1, "wings", 1),
                self.row("nutrition_type", "herbivore", 10, "carnivore", 20, "CODOMINANT"),
                self.row("size", "medium_size", 15, "medium_size", 15, "INCOMPLETE"),
                self.row("fin_shape", "pointed_fin", 10, "crescent_fin", 30),
            ],
        )
        self.assertEqual(rendered["color"]["result_label"], "зелёный")
        self.assertEqual(rendered["has_wings"]["result_label"], "есть крылья")
        self.assertEqual(rendered["nutrition_type"]["result_label"], "смешанное")
        self.assertEqual(rendered["size"]["result_label"], "средний")
        self.assertEqual(rendered["fin_shape"]["result_label"], "серповидный плавник")

    def test_bony_and_crustacean_results_use_backend_phenotype(self) -> None:
        bony = self.render(
            "color=red_color; has_wings=no_wings; size=medium_size; fin_shape=rounded_fin",
            [
                self.row("color", "white_color", 70, "red_color", 30),
                self.row("has_wings", "no_wings", 0, "wings", 1),
                self.row("size", "compact_size", 10, "large_size", 20, "INCOMPLETE"),
                self.row("fin_shape", "rounded_fin", 10, "rounded_fin", 10),
            ],
        )
        self.assertEqual(bony["color"]["result_label"], "красный")
        self.assertEqual(bony["has_wings"]["result_label"], "без крыльев")
        self.assertEqual(bony["size"]["result_label"], "средний")
        self.assertEqual(bony["fin_shape"]["result_label"], "округлый плавник")

        crustacean = self.render(
            "color=green_color; size=large_size; claw_form=hooked_claws; shell_armor=thick_armor",
            [
                self.row("color", "blue_color", 20, "green_color", 10),
                self.row("size", "large_size", 20, "large_size", 20, "INCOMPLETE"),
                self.row("claw_form", "hooked_claws", 30, "long_claws", 20),
                self.row("shell_armor", "thick_armor", 10, "thick_armor", 10),
            ],
        )
        self.assertEqual(crustacean["color"]["result_label"], "зелёный")
        self.assertEqual(crustacean["size"]["result_label"], "крупный")
        self.assertEqual(crustacean["claw_form"]["result_label"], "крючковатые клешни")
        self.assertEqual(crustacean["shell_armor"]["result_label"], "толстый панцирь")
        self.assertNotIn(".0", " ".join(item["technical_pair_label"] for item in crustacean.values()))


if __name__ == "__main__":
    unittest.main()
