from __future__ import annotations

from typing import Any

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QMessageBox,
    QPushButton,
    QSplitter,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState
from app.services.display_names import (
    display_creature_name,
    display_gene_name,
    display_gene_type,
    display_trait_value,
    dominance_label,
    format_phenotype_summary,
    species_label,
)



class CreaturesTab(QWidget):
    def __init__(self, pkg_api: PkgApi, state: SessionState) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state

        self._creatures: list[dict[str, Any]] = []
        self._build_ui()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(10)

        toolbar = QHBoxLayout()
        title = QLabel("Коллекция существ")
        title.setObjectName("title")
        subtitle = QLabel("Существа лаборатории, фенотип и генотип выбранного экземпляра")
        subtitle.setObjectName("subtitle")

        heading = QVBoxLayout()
        heading.addWidget(title)
        heading.addWidget(subtitle)

        self.refresh_btn = QPushButton("Обновить")
        self.refresh_btn.setProperty("role", "secondary")
        self.refresh_btn.clicked.connect(self.refresh_data)

        toolbar.addLayout(heading)
        toolbar.addStretch()
        toolbar.addWidget(self.refresh_btn)

        root.addLayout(toolbar)

        splitter = QSplitter(Qt.Horizontal)

        left_panel = QFrame()
        left_panel.setProperty("card", "true")
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(10, 10, 10, 10)

        self.creatures_table = QTableWidget(0, 8)
        self.creatures_table.setHorizontalHeaderLabels(
            [
                "ID",
                "Имя",
                "Вид",
                "Цвет",
                "Размер",
                "Крылья",
                "Тип питания",
                "Фенотип",
            ]
        )
        self.creatures_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.creatures_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.creatures_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.creatures_table.verticalHeader().setVisible(False)
        self.creatures_table.setAlternatingRowColors(True)
        self.creatures_table.itemSelectionChanged.connect(self._on_creature_selected)

        header = self.creatures_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(2, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(3, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(4, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(5, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(6, QHeaderView.ResizeToContents)
        header.setSectionResizeMode(7, QHeaderView.Stretch)

        left_layout.addWidget(self.creatures_table)
        splitter.addWidget(left_panel)

        right_panel = QFrame()
        right_panel.setProperty("card", "true")
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(10, 10, 10, 10)
        right_layout.setSpacing(10)

        card_title = QLabel("Карточка существа")
        card_title.setObjectName("subtitle")
        right_layout.addWidget(card_title)

        info_form = QFormLayout()
        info_form.setLabelAlignment(Qt.AlignRight)

        self.lbl_creature_id = QLabel("-")
        self.lbl_creature_name = QLabel("-")
        self.lbl_species = QLabel("-")
        self.lbl_color = QLabel("-")
        self.lbl_size = QLabel("-")
        self.lbl_wings = QLabel("-")
        self.lbl_nutrition = QLabel("-")

        info_form.addRow("ID:", self.lbl_creature_id)
        info_form.addRow("Имя:", self.lbl_creature_name)
        info_form.addRow("Вид:", self.lbl_species)
        info_form.addRow("Цвет:", self.lbl_color)
        info_form.addRow("Размер:", self.lbl_size)
        info_form.addRow("Крылья:", self.lbl_wings)
        info_form.addRow("Тип питания:", self.lbl_nutrition)

        right_layout.addLayout(info_form)

        summary_label = QLabel("Описание фенотипа")
        summary_label.setObjectName("subtitle")
        right_layout.addWidget(summary_label)

        self.phenotype_summary = QLabel("-")
        self.phenotype_summary.setWordWrap(True)
        self.phenotype_summary.setAlignment(Qt.AlignTop | Qt.AlignLeft)
        self.phenotype_summary.setMinimumHeight(64)
        right_layout.addWidget(self.phenotype_summary)

        genotype_label = QLabel("Генотип")
        genotype_label.setObjectName("subtitle")
        right_layout.addWidget(genotype_label)

        self.genotype_table = QTableWidget(0, 7)
        self.genotype_table.setHorizontalHeaderLabels(
            [
                "Ген",
                "Тип гена",
                "Тип доминирования",
                "Аллель 1",
                "Значение 1",
                "Аллель 2",
                "Значение 2",
            ]
        )
        self.genotype_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.genotype_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.genotype_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.genotype_table.verticalHeader().setVisible(False)
        self.genotype_table.setAlternatingRowColors(True)

        g_header = self.genotype_table.horizontalHeader()
        g_header.setSectionResizeMode(0, QHeaderView.ResizeToContents)
        g_header.setSectionResizeMode(1, QHeaderView.ResizeToContents)
        g_header.setSectionResizeMode(2, QHeaderView.ResizeToContents)
        g_header.setSectionResizeMode(3, QHeaderView.Stretch)
        g_header.setSectionResizeMode(4, QHeaderView.ResizeToContents)
        g_header.setSectionResizeMode(5, QHeaderView.Stretch)
        g_header.setSectionResizeMode(6, QHeaderView.ResizeToContents)

        right_layout.addWidget(self.genotype_table)

        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 2)

        root.addWidget(splitter)

    def refresh_data(self) -> None:
        lab_id = self.state.selected_lab_id
        if lab_id is None:
            QMessageBox.warning(self, "Существа", "Сначала выберите лабораторию.")
            return

        try:
            self._creatures = self.pkg_api.get_creatures(lab_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка существ", map_oracle_error(exc))
            return

        self._fill_creatures_table()

    def _fill_creatures_table(self) -> None:
        self.creatures_table.setRowCount(0)

        for row_idx, creature in enumerate(self._creatures):
            self.creatures_table.insertRow(row_idx)
            self._set_table_item(self.creatures_table, row_idx, 0, creature.get("creature_id"), center=True)
            self._set_table_item(
                self.creatures_table,
                row_idx,
                1,
                self._creature_name_display(creature.get("creature_name")),
                tooltip=True,
            )
            self._set_table_item(
                self.creatures_table,
                row_idx,
                2,
                self._species_name(creature.get("species_type")),
                center=True,
            )
            self._set_table_item(
                self.creatures_table,
                row_idx,
                3,
                self._trait_display(creature.get("phenotype_color")),
                tooltip=True,
            )
            self._set_table_item(
                self.creatures_table,
                row_idx,
                4,
                self._trait_display(creature.get("phenotype_size")),
                tooltip=True,
            )
            self._set_table_item(
                self.creatures_table,
                row_idx,
                5,
                self._trait_display(creature.get("phenotype_has_wings")),
                center=True,
            )
            self._set_table_item(
                self.creatures_table,
                row_idx,
                6,
                self._trait_display(creature.get("phenotype_nutrition_type")),
                tooltip=True,
            )
            self._set_table_item(
                self.creatures_table,
                row_idx,
                7,
                self._phenotype_summary_display(creature.get("phenotype_summary")),
                tooltip=True,
            )

        if self.creatures_table.rowCount() > 0:
            self.creatures_table.selectRow(0)
        else:
            self._clear_selected_creature_card()

    def _on_creature_selected(self) -> None:
        row = self.creatures_table.currentRow()
        if row < 0 or row >= len(self._creatures):
            self._clear_selected_creature_card()
            return

        creature = self._creatures[row]
        creature_id = self._to_int(creature.get("creature_id"))
        if creature_id is None:
            self._clear_selected_creature_card()
            return

        self._fill_selected_creature_card(creature)

        try:
            genotype_rows = self.pkg_api.get_genotype(creature_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка генотипа", map_oracle_error(exc))
            self.genotype_table.setRowCount(0)
            return

        self._fill_genotype_table(genotype_rows)

    def _fill_selected_creature_card(self, creature: dict[str, Any]) -> None:
        species_text = self._species_name(creature.get("species_type"))

        self.lbl_creature_id.setText(self._display(creature.get("creature_id")))
        self.lbl_creature_name.setText(self._creature_name_display(creature.get("creature_name")))
        self.lbl_species.setText(species_text)
        self.lbl_color.setText(self._trait_display(creature.get("phenotype_color")))
        self.lbl_size.setText(self._trait_display(creature.get("phenotype_size")))
        self.lbl_wings.setText(self._trait_display(creature.get("phenotype_has_wings")))
        self.lbl_nutrition.setText(self._trait_display(creature.get("phenotype_nutrition_type")))
        self.phenotype_summary.setText(self._phenotype_summary_display(creature.get("phenotype_summary")))

    def _fill_genotype_table(self, rows: list[dict[str, Any]]) -> None:
        self.genotype_table.setRowCount(0)

        for row_idx, rec in enumerate(rows):
            self.genotype_table.insertRow(row_idx)
            self._set_table_item(
                self.genotype_table,
                row_idx,
                0,
                self._gene_display(rec.get("gene_name")),
                tooltip=True,
            )
            self._set_table_item(self.genotype_table, row_idx, 1, display_gene_type(rec.get("gene_type")), tooltip=True)
            self._set_table_item(
                self.genotype_table,
                row_idx,
                2,
                self._dominance_display(rec.get("dominance_type")),
                center=True,
            )
            self._set_table_item(
                self.genotype_table,
                row_idx,
                3,
                self._trait_display(rec.get("allele1_description")),
                tooltip=True,
            )
            self._set_table_item(
                self.genotype_table,
                row_idx,
                4,
                self._trait_display(rec.get("allele1_trait_value")),
                tooltip=True,
            )
            self._set_table_item(
                self.genotype_table,
                row_idx,
                5,
                self._trait_display(rec.get("allele2_description")),
                tooltip=True,
            )
            self._set_table_item(
                self.genotype_table,
                row_idx,
                6,
                self._trait_display(rec.get("allele2_trait_value")),
                tooltip=True,
            )

    def _clear_selected_creature_card(self) -> None:
        self.lbl_creature_id.setText("-")
        self.lbl_creature_name.setText("-")
        self.lbl_species.setText("-")
        self.lbl_color.setText("-")
        self.lbl_size.setText("-")
        self.lbl_wings.setText("-")
        self.lbl_nutrition.setText("-")
        self.phenotype_summary.setText("-")
        self.genotype_table.setRowCount(0)

    @staticmethod
    def _set_table_item(
        table: QTableWidget,
        row: int,
        col: int,
        value: Any,
        center: bool = False,
        tooltip: bool = False,
    ) -> None:
        text = CreaturesTab._display(value)
        item = QTableWidgetItem(text)
        if center:
            item.setTextAlignment(Qt.AlignCenter)
        if tooltip:
            item.setToolTip(text)
        table.setItem(row, col, item)

    @staticmethod
    def _display(value: Any) -> str:
        if value is None:
            return "Не указано"
        text = str(value).strip()
        return text if text else "Не указано"

    @staticmethod
    def _species_name(value: Any) -> str:
        return species_label(value)

    @staticmethod
    def _trait_display(value: Any) -> str:
        return display_trait_value(value)

    @staticmethod
    def _dominance_display(value: Any) -> str:
        return dominance_label(value, with_code=False)

    @staticmethod
    def _gene_display(value: Any) -> str:
        return display_gene_name(value)

    @staticmethod
    def _creature_name_display(value: Any) -> str:
        return display_creature_name(value)

    @staticmethod
    def _phenotype_summary_display(value: Any) -> str:
        return format_phenotype_summary(value)

    @staticmethod
    def _to_int(value: Any) -> int | None:
        if value is None:
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None
