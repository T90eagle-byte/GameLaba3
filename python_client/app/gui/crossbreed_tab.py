from __future__ import annotations

from decimal import Decimal
from typing import Any, Callable

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QComboBox,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState
from app.services.display_names import (
    creature_name_label,
    display_value,
    gene_label,
    phenotype_summary_label,
    species_label,
    trait_label,
)


_SPECIES_LABELS = {
    1: "Хрящевые рыбы",
    2: "Костные рыбы",
    3: "Ракообразные",
    4: "Моллюски",
    5: "Черепахи",
    6: "Млекопитающие",
}


class CrossbreedTab(QWidget):
    def __init__(
        self,
        pkg_api: PkgApi,
        state: SessionState,
        on_experiment_completed: Callable[[], None] | None = None,
    ) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_experiment_completed = on_experiment_completed

        self._creatures: list[dict[str, Any]] = []
        self._creature_by_id: dict[int, dict[str, Any]] = {}

        self._build_ui()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(10)

        top_row = QHBoxLayout()
        heading = QVBoxLayout()

        title = QLabel("Генетический эксперимент")
        title.setObjectName("title")
        subtitle = QLabel("Выбор двух исходных существ, расчет вероятностей и создание результата")
        subtitle.setObjectName("subtitle")

        heading.addWidget(title)
        heading.addWidget(subtitle)

        self.refresh_btn = QPushButton("Обновить список")
        self.refresh_btn.setProperty("role", "secondary")
        self.refresh_btn.clicked.connect(self.refresh_creatures)

        top_row.addLayout(heading)
        top_row.addStretch()
        top_row.addWidget(self.refresh_btn)

        root.addLayout(top_row)

        selector_card = QFrame()
        selector_card.setProperty("card", "true")
        selector_layout = QFormLayout(selector_card)
        selector_layout.setContentsMargins(12, 12, 12, 12)
        selector_layout.setLabelAlignment(Qt.AlignRight)

        self.parent_a_combo = QComboBox()
        self.parent_b_combo = QComboBox()
        self.gene_combo = QComboBox()

        self.parent_a_combo.currentIndexChanged.connect(self._on_parent_changed)
        self.parent_b_combo.currentIndexChanged.connect(self._on_parent_changed)

        selector_layout.addRow("Исходное существо A:", self.parent_a_combo)
        selector_layout.addRow("Исходное существо B:", self.parent_b_combo)
        selector_layout.addRow("Ген:", self.gene_combo)

        self.show_probabilities_btn = QPushButton("Показать вероятности")
        self.show_probabilities_btn.clicked.connect(self.show_probabilities)
        selector_layout.addRow("", self.show_probabilities_btn)

        root.addWidget(selector_card)

        cards_row = QHBoxLayout()
        self.parent_a_card, self.parent_a_fields = self._build_source_card("Исходное существо A")
        self.parent_b_card, self.parent_b_fields = self._build_source_card("Исходное существо B")
        cards_row.addWidget(self.parent_a_card)
        cards_row.addWidget(self.parent_b_card)
        root.addLayout(cards_row)

        probabilities_card = QFrame()
        probabilities_card.setProperty("card", "true")
        probabilities_layout = QVBoxLayout(probabilities_card)
        probabilities_layout.setContentsMargins(12, 12, 12, 12)

        probabilities_title = QLabel("Вероятности признаков")
        probabilities_title.setObjectName("subtitle")
        probabilities_layout.addWidget(probabilities_title)

        self.probabilities_table = QTableWidget(0, 5)
        self.probabilities_table.setHorizontalHeaderLabels(
            [
                "Аллель 1 (ID)",
                "Аллель 2 (ID)",
                "Вероятность",
                "Описание аллеля 1",
                "Описание аллеля 2",
            ]
        )
        self.probabilities_table.verticalHeader().setVisible(False)
        self.probabilities_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.probabilities_table.setSelectionBehavior(QTableWidget.SelectRows)
        self.probabilities_table.setSelectionMode(QTableWidget.SingleSelection)
        self.probabilities_table.setAlternatingRowColors(True)

        header = self.probabilities_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(2, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(3, QHeaderView.Stretch)
        header.setSectionResizeMode(4, QHeaderView.Stretch)

        probabilities_layout.addWidget(self.probabilities_table)
        root.addWidget(probabilities_card)

        result_card = QFrame()
        result_card.setProperty("card", "true")
        result_layout = QFormLayout(result_card)
        result_layout.setContentsMargins(12, 12, 12, 12)
        result_layout.setLabelAlignment(Qt.AlignRight)

        self.result_name_input = QLineEdit()
        self.result_name_input.setPlaceholderText("Введите имя результирующего существа")

        self.create_result_btn = QPushButton("Создать результат")
        self.create_result_btn.clicked.connect(self.create_result)

        self.result_id_label = QLabel("-")
        self.result_hint_label = QLabel("После создания результата статистика лаборатории обновится автоматически.")
        self.result_hint_label.setObjectName("subtitle")
        self.result_hint_label.setWordWrap(True)

        result_layout.addRow("Имя результата:", self.result_name_input)
        result_layout.addRow("", self.create_result_btn)
        result_layout.addRow("ID результата:", self.result_id_label)
        result_layout.addRow("", self.result_hint_label)

        root.addWidget(result_card)

    def _build_source_card(self, header: str) -> tuple[QFrame, dict[str, QLabel]]:
        frame = QFrame()
        frame.setProperty("card", "true")
        layout = QFormLayout(frame)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setLabelAlignment(Qt.AlignRight)

        title = QLabel(header)
        title.setObjectName("subtitle")
        layout.addRow("", title)

        fields = {
            "creature_id": QLabel("-"),
            "creature_name": QLabel("-"),
            "species_type": QLabel("-"),
            "phenotype_summary": QLabel("-"),
        }

        fields["phenotype_summary"].setWordWrap(True)
        fields["phenotype_summary"].setMinimumHeight(48)

        layout.addRow("ID:", fields["creature_id"])
        layout.addRow("Имя:", fields["creature_name"])
        layout.addRow("Вид:", fields["species_type"])
        layout.addRow("Фенотип:", fields["phenotype_summary"])

        return frame, fields

    def refresh_creatures(self) -> None:
        lab_id = self.state.selected_lab_id
        if lab_id is None:
            QMessageBox.warning(self, "Генетический эксперимент", "Сначала выберите лабораторию.")
            return

        selected_a = self.parent_a_combo.currentData()
        selected_b = self.parent_b_combo.currentData()

        try:
            self._creatures = self.pkg_api.get_creatures(lab_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка", map_oracle_error(exc))
            return

        self._creature_by_id = {}
        for creature in self._creatures:
            creature_id = self._to_int(creature.get("creature_id"))
            if creature_id is not None:
                self._creature_by_id[creature_id] = creature

        self._fill_parent_combo(self.parent_a_combo, selected_a)
        self._fill_parent_combo(self.parent_b_combo, selected_b)

        self._update_parent_cards()
        self._reload_genes()

    def _fill_parent_combo(self, combo: QComboBox, selected_id: Any) -> None:
        combo.blockSignals(True)
        combo.clear()
        combo.addItem("Выберите существо...", None)

        selected_index = 0

        for creature in self._creatures:
            creature_id = self._to_int(creature.get("creature_id"))
            if creature_id is None:
                continue

            name = creature_name_label(creature.get("creature_name"))
            species_text = self._species_text(creature.get("species_type"))
            combo.addItem(f"{creature_id} | {name} | {species_text}", creature_id)

            if selected_id is not None and creature_id == self._to_int(selected_id):
                selected_index = combo.count() - 1

        combo.setCurrentIndex(selected_index)
        combo.blockSignals(False)

    def _on_parent_changed(self) -> None:
        self._update_parent_cards()
        self._reload_genes()

    def _update_parent_cards(self) -> None:
        self._fill_card(self.parent_a_fields, self._selected_creature(self.parent_a_combo.currentData()))
        self._fill_card(self.parent_b_fields, self._selected_creature(self.parent_b_combo.currentData()))

    def _fill_card(self, fields: dict[str, QLabel], creature: dict[str, Any] | None) -> None:
        if creature is None:
            fields["creature_id"].setText("-")
            fields["creature_name"].setText("-")
            fields["species_type"].setText("-")
            fields["phenotype_summary"].setText("-")
            return

        fields["creature_id"].setText(self._display(creature.get("creature_id")))
        fields["creature_name"].setText(creature_name_label(creature.get("creature_name")))
        fields["species_type"].setText(species_label(creature.get("species_type")))
        fields["phenotype_summary"].setText(phenotype_summary_label(creature.get("phenotype_summary")))

    def _selected_creature(self, creature_id: Any) -> dict[str, Any] | None:
        cid = self._to_int(creature_id)
        if cid is None:
            return None
        return self._creature_by_id.get(cid)

    def _reload_genes(self) -> None:
        self.gene_combo.clear()
        self.gene_combo.addItem("Выберите ген...", None)

        self.probabilities_table.setRowCount(0)

        parent_a_id = self._to_int(self.parent_a_combo.currentData())
        parent_b_id = self._to_int(self.parent_b_combo.currentData())
        if parent_a_id is None or parent_b_id is None:
            return

        try:
            genes_a = self.pkg_api.get_genotype(parent_a_id)
            genes_b = self.pkg_api.get_genotype(parent_b_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка", map_oracle_error(exc))
            return

        map_a = {
            self._to_int(row.get("gene_id")): gene_label(row.get("gene_name"))
            for row in genes_a
            if self._to_int(row.get("gene_id")) is not None
        }
        map_b = {
            self._to_int(row.get("gene_id")): gene_label(row.get("gene_name"))
            for row in genes_b
            if self._to_int(row.get("gene_id")) is not None
        }

        common_gene_ids = sorted(
            set(map_a.keys()) & set(map_b.keys()),
            key=lambda gid: (map_a.get(gid, ""), gid),
        )

        for gene_id in common_gene_ids:
            gene_name = map_a.get(gene_id, "-")
            self.gene_combo.addItem(f"{gene_name} (ID: {gene_id})", gene_id)

    def show_probabilities(self) -> None:
        parent_a_id = self._to_int(self.parent_a_combo.currentData())
        parent_b_id = self._to_int(self.parent_b_combo.currentData())
        gene_id = self._to_int(self.gene_combo.currentData())

        if parent_a_id is None or parent_b_id is None:
            QMessageBox.warning(self, "Генетический эксперимент", "Выберите два исходных существа.")
            return

        if gene_id is None:
            QMessageBox.warning(self, "Генетический эксперимент", "Выберите ген для расчета вероятностей.")
            return

        try:
            probabilities = self.pkg_api.calculate_punnett_probabilities(parent_a_id, parent_b_id, gene_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка", map_oracle_error(exc))
            return

        self.probabilities_table.setRowCount(0)

        for row_idx, row in enumerate(probabilities):
            self.probabilities_table.insertRow(row_idx)
            self._set_table_item(row_idx, 0, row.get("allele1_id"), center=True)
            self._set_table_item(row_idx, 1, row.get("allele2_id"), center=True)
            self._set_table_item(row_idx, 2, self._format_probability(row.get("probability")), center=True)
            self._set_table_item(row_idx, 3, trait_label(row.get("allele1_description")), tooltip=True)
            self._set_table_item(row_idx, 4, trait_label(row.get("allele2_description")), tooltip=True)

        if self.probabilities_table.rowCount() == 0:
            QMessageBox.information(self, "Генетический эксперимент", "Для выбранного гена нет данных вероятностей.")

    def create_result(self) -> None:
        lab_id = self.state.selected_lab_id
        parent_a_id = self._to_int(self.parent_a_combo.currentData())
        parent_b_id = self._to_int(self.parent_b_combo.currentData())
        result_name = self.result_name_input.text().strip()

        if lab_id is None:
            QMessageBox.warning(self, "Генетический эксперимент", "Сначала выберите лабораторию.")
            return

        if parent_a_id is None or parent_b_id is None:
            QMessageBox.warning(self, "Генетический эксперимент", "Выберите два исходных существа.")
            return

        if not result_name:
            QMessageBox.warning(self, "Генетический эксперимент", "Введите имя результирующего существа.")
            return

        try:
            offspring_id = self.pkg_api.crossbreed(lab_id, parent_a_id, parent_b_id, result_name)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка", map_oracle_error(exc))
            return

        self.result_id_label.setText(str(offspring_id))

        QMessageBox.information(
            self,
            "Генетический эксперимент",
            f"Результирующее существо создано. ID: {offspring_id}",
        )

        self.refresh_creatures()

        if self.on_experiment_completed is not None:
            self.on_experiment_completed()

    def _set_table_item(self, row: int, col: int, value: Any, center: bool = False, tooltip: bool = False) -> None:
        text = self._display(value)
        item = QTableWidgetItem(text)
        if center:
            item.setTextAlignment(Qt.AlignCenter)
        if tooltip:
            item.setToolTip(text)
        self.probabilities_table.setItem(row, col, item)

    @staticmethod
    def _format_probability(value: Any) -> str:
        if value is None:
            return "Нет данных"

        if isinstance(value, Decimal):
            prob = float(value)
        else:
            try:
                prob = float(value)
            except (TypeError, ValueError):
                return str(value)

        if prob <= 1:
            return f"{prob * 100:.0f}%"
        return f"{prob:.0f}%"

    @staticmethod
    def _display(value: Any) -> str:
        return display_value(value)

    @staticmethod
    def _to_int(value: Any) -> int | None:
        if value is None:
            return None

        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _species_text(species_value: Any) -> str:
        return species_label(species_value)
