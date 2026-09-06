from __future__ import annotations

import unittest

from web_client.services.display_service import (
    TASK_DESCRIPTIONS,
    TASK_LABELS,
    creature_visual,
    genotype_change_slots,
    genotype_view,
    phenotype_items,
    rating_event_view,
    task_view,
    trait_label,
    translate_free_text,
)


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
        self.assertNotIn("technical_pair_label", rendered["color"])
        self.assertEqual(rendered["color"]["pair_label"], "Аллели: синий / белый")

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


class GenotypeChangeTests(unittest.TestCase):
    @staticmethod
    def row(gene_id: int, gene_name: str, allele1_id: int, allele2_id: int) -> dict[str, object]:
        return {
            "gene_id": gene_id,
            "gene_name": gene_name,
            "allele1_id": allele1_id,
            "allele2_id": allele2_id,
        }

    def test_marks_only_allele1_that_changed(self) -> None:
        before = [self.row(1, "color", 10, 20)]
        after = [self.row(1, "color", 30, 20)]
        self.assertEqual(genotype_change_slots(before, after), {"color": ["allele1"]})

    def test_marks_only_allele2_that_changed(self) -> None:
        before = [self.row(1, "shell_armor", 10, 20)]
        after = [self.row(1, "shell_armor", 10, 30)]
        self.assertEqual(genotype_change_slots(before, after), {"shell_armor": ["allele2"]})

    def test_marks_both_slots_when_both_changed(self) -> None:
        before = [self.row(1, "size", 10, 20)]
        after = [self.row(1, "size", 30, 40)]
        self.assertEqual(genotype_change_slots(before, after), {"size": ["allele1", "allele2"]})

    def test_unchanged_genes_are_not_marked(self) -> None:
        before = [self.row(1, "color", 10, 20), self.row(2, "size", 30, 40)]
        after = [self.row(1, "color", 10, 20), self.row(2, "size", 30, 50)]
        self.assertEqual(genotype_change_slots(before, after), {"size": ["allele2"]})


class PlayerLocalizationTests(unittest.TestCase):
    def test_known_trait_and_history_values_are_russian(self) -> None:
        self.assertEqual(trait_label("spiked_shell"), "шипастый панцирь")
        self.assertEqual(translate_free_text("System adjustment"), "Корректировка результата")
        event = rating_event_view({"event_type": "SYSTEM_ADJUSTMENT", "description": "System adjustment"})
        self.assertEqual(event["type_label"], "Корректировка результата")
        self.assertEqual(event["description_text"], "Корректировка результата")

    def test_all_current_seed_allele_codes_have_player_facing_labels(self) -> None:
        seed_codes = (
            "green_color", "blue_color", "red_color", "yellow_color", "purple_color", "orange_color", "white_color", "black_color",
            "compact_size", "medium_size", "large_size", "herbivore", "carnivore", "no_wings", "wings",
            "pointed_fin", "broad_fin", "crescent_fin", "rounded_fin", "forked_fin", "ribbon_fin",
            "thick_armor", "light_armor", "ridged_armor", "short_claws", "long_claws", "hooked_claws",
            "rounded_nose", "sharp_beak", "spiral_profile", "smooth_shell", "spiked_shell", "plated_shell",
            "slow_speed", "fast_speed", "short_fur", "dense_fur", "soft_fur",
        )
        for code in seed_codes:
            with self.subTest(code=code):
                label = trait_label(code)
                self.assertNotIn("_", label)
                self.assertFalse(any("a" <= char.lower() <= "z" for char in label))


class TaskDisplayTests(unittest.TestCase):
    def test_armored_crustacean_has_player_facing_name(self) -> None:
        task = task_view({"task_name": "task_armored_crustacean", "task_display_name": "task_armored_crustacean"})
        self.assertEqual(task["display_name"], "Бронированный ракообразный")
        self.assertIsNone(task["unknown_task_code"])

    def test_all_known_tasks_have_nontechnical_names(self) -> None:
        self.assertEqual(len(TASK_LABELS), 21)
        for code, expected in TASK_LABELS.items():
            with self.subTest(code=code):
                task = task_view({"task_name": code, "task_display_name": code})
                self.assertEqual(task["display_name"], expected)
                self.assertFalse(task["display_name"].lower().startswith("task_"))

    def test_all_known_tasks_explain_genetic_carrier_condition(self) -> None:
        self.assertEqual(set(TASK_DESCRIPTIONS), set(TASK_LABELS))
        for code in TASK_LABELS:
            with self.subTest(code=code):
                task = task_view({"task_name": code, "description": "устаревшая фенотипическая формулировка"})
                self.assertIn("носительство", task["description_text"].lower())
                self.assertEqual(task["requirement_label"], "Генетическое условие")

    def test_wings_order_explains_recessive_carrier_case(self) -> None:
        task = task_view({"task_name": "task_winged_specimen"})
        self.assertEqual(task["display_name"], "Носитель аллеля крыльев")
        self.assertIn("могут не проявиться", task["description_text"])

    def test_unknown_internal_task_uses_safe_fallback_and_keeps_diagnostic_code(self) -> None:
        task = task_view({"task_name": "task_future_unknown", "task_display_name": "task_future_unknown"})
        self.assertEqual(task["display_name"], "Специальный заказ")
        self.assertEqual(task["unknown_task_code"], "task_future_unknown")


if __name__ == "__main__":
    unittest.main()
