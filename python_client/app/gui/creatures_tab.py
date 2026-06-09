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
    QScrollArea,
    QSplitter,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.gui.creature_portrait import CreaturePortraitWidget
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

        self.creatures_table = QTableWidget(0, 7)
        self.creatures_table.setHorizontalHeaderLabels(
            [
                "ID",
                "Имя",
                "Вид",
                "Цвет",
                "Размер",
                "Крылья",
                "Тип питания",
            ]
        )
        self.creatures_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.creatures_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.creatures_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.creatures_table.verticalHeader().setVisible(False)
        self.creatures_table.setAlternatingRowColors(True)
        self.creatures_table.itemSelectionChanged.connect(self._on_creature_selected)

        header = self.creatures_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(5, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(6, QHeaderView.ResizeMode.ResizeToContents)

        left_layout.addWidget(self.creatures_table)

        self.empty_creatures_hint = QLabel("")
        self.empty_creatures_hint.setObjectName("subtitle")
        self.empty_creatures_hint.setWordWrap(True)
        left_layout.addWidget(self.empty_creatures_hint)
        splitter.addWidget(left_panel)

        right_panel = QFrame()
        right_panel.setProperty("card", "true")
        right_panel.setObjectName("creaturePassportCard")
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(10, 10, 10, 10)
        right_layout.setSpacing(10)

        card_title = QLabel("Карточка существа")
        card_title.setObjectName("subtitle")
        right_layout.addWidget(card_title)

        creature_hint = QLabel(
            "\u0424\u0435\u043d\u043e\u0442\u0438\u043f \u2014 \u0432\u0438\u0434\u0438\u043c\u044b\u0435 \u043f\u0440\u0438\u0437\u043d\u0430\u043a\u0438: \u0432\u0438\u0434, \u043e\u043a\u0440\u0430\u0441\u043a\u0430, \u0440\u0430\u0437\u043c\u0435\u0440, \u043a\u0440\u044b\u043b\u044c\u044f \u0438 \u043f\u0438\u0442\u0430\u043d\u0438\u0435. "
            "\u0413\u0435\u043d\u043e\u0442\u0438\u043f \u2014 \u043f\u0430\u0440\u044b \u0430\u043b\u043b\u0435\u043b\u0435\u0439, \u043a\u043e\u0442\u043e\u0440\u044b\u0435 \u043d\u0430\u0441\u043b\u0435\u0434\u0443\u044e\u0442\u0441\u044f. "
            "\u041e\u043a\u0440\u0430\u0441\u043a\u0430 \u0442\u043e\u0436\u0435 \u043d\u0430\u0441\u043b\u0435\u0434\u0443\u0435\u0442\u0441\u044f: \u0432 \u043b\u0430\u0431\u043e\u0440\u0430\u0442\u043e\u0440\u0438\u0438 \u0432\u0441\u0442\u0440\u0435\u0447\u0430\u044e\u0442\u0441\u044f \u0440\u0430\u0437\u043d\u044b\u0435 \u0446\u0432\u0435\u0442\u043e\u0432\u044b\u0435 \u0432\u0430\u0440\u0438\u0430\u043d\u0442\u044b."
        )
        creature_hint.setProperty("helpCard", True)
        creature_hint.setWordWrap(True)
        right_layout.addWidget(creature_hint)

        self.creature_portrait = CreaturePortraitWidget(mode="large")
        right_layout.addWidget(self.creature_portrait, alignment=Qt.AlignHCenter)

        self.creature_name_title = QLabel("Выберите существо")
        self.creature_name_title.setObjectName("creatureNameTitle")
        self.creature_name_title.setWordWrap(True)
        self.creature_id_badge = QLabel("ID: -")
        self.creature_id_badge.setObjectName("creatureIdBadge")
        self.creature_id_badge.setProperty("badge", True)

        creature_header = QHBoxLayout()
        creature_header.setSpacing(8)
        creature_header.addWidget(self.creature_name_title, 1)
        creature_header.addWidget(self.creature_id_badge, 0, Qt.AlignTop)
        right_layout.addLayout(creature_header)

        self.phenotype_badges_frame = QFrame()
        self.phenotype_badges_frame.setObjectName("phenotypeBadgePanel")
        phenotype_badges_layout = QVBoxLayout(self.phenotype_badges_frame)
        phenotype_badges_layout.setContentsMargins(8, 8, 8, 8)
        phenotype_badges_layout.setSpacing(6)
        self.phenotype_badges = {}
        badge_rows = [QHBoxLayout(), QHBoxLayout()]
        for row_layout in badge_rows:
            row_layout.setSpacing(6)
            phenotype_badges_layout.addLayout(row_layout)

        badge_specs = [
            ("species", "Вид"),
            ("color", "Цвет"),
            ("size", "Размер"),
            ("wings", "Крылья"),
            ("nutrition", "Питание"),
            ("details", "Детали"),
        ]
        for idx, (key, title_text) in enumerate(badge_specs):
            badge = self._make_phenotype_badge(title_text, "-")
            self.phenotype_badges[key] = badge
            badge_rows[idx // 3].addWidget(badge, 1)
        right_layout.addWidget(self.phenotype_badges_frame)
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

        self.genotype_scroll = QScrollArea()
        self.genotype_scroll.setWidgetResizable(True)
        self.genotype_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.genotype_scroll.setMinimumHeight(260)

        self.genotype_container = QWidget()
        self.genotype_layout = QVBoxLayout(self.genotype_container)
        self.genotype_layout.setContentsMargins(0, 0, 0, 0)
        self.genotype_layout.setSpacing(8)
        self.genotype_scroll.setWidget(self.genotype_container)

        right_layout.addWidget(self.genotype_scroll, 1)

        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 2)

        root.addWidget(splitter)

    @staticmethod
    def _make_phenotype_badge(title: str, value: str) -> QLabel:
        badge = QLabel(f"{title}: {value}")
        badge.setProperty("phenotypeBadge", True)
        badge.setWordWrap(True)
        return badge

    def _set_phenotype_badge(self, key: str, title: str, value: str) -> None:
        badge = self.phenotype_badges.get(key)
        if badge is None:
            return
        text = f"{title}: {value}"
        badge.setText(text)
        badge.setToolTip(text)

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
                f"{self._creature_name_display(creature.get('creature_name'))} \u00b7 ID {self._display(creature.get('creature_id'))}",
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

        if self.creatures_table.rowCount() > 0:
            self.creatures_table.selectRow(0)
            self.empty_creatures_hint.setText("")
        else:
            self._clear_selected_creature_card()
            self.empty_creatures_hint.setText(
                "В лаборатории пока нет существ. Создайте новую лабораторию или обновите список."
            )

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
            self._clear_genotype_cards()
            return

        self._fill_genotype_table(genotype_rows)

    def _fill_selected_creature_card(self, creature: dict[str, Any]) -> None:
        species_text = self._species_name(creature.get("species_type"))

        creature_id_text = self._display(creature.get("creature_id"))
        creature_name_text = self._creature_name_display(creature.get("creature_name"))

        self.lbl_creature_id.setText(creature_id_text)
        self.lbl_creature_name.setText(creature_name_text)
        self.creature_name_title.setText(creature_name_text)
        self.creature_id_badge.setText(f"ID: {creature_id_text}")
        self.lbl_species.setText(species_text)
        self.lbl_color.setText(self._trait_display(creature.get("phenotype_color")))
        self.lbl_size.setText(self._trait_display(creature.get("phenotype_size")))
        self.lbl_wings.setText(self._trait_display(creature.get("phenotype_has_wings")))
        self.lbl_nutrition.setText(self._trait_display(creature.get("phenotype_nutrition_type")))
        phenotype_summary_text = self._phenotype_summary_display(creature.get("phenotype_summary"))
        self.phenotype_summary.setText(phenotype_summary_text)
        self._set_phenotype_badge("species", "Вид", species_text)
        self._set_phenotype_badge("color", "Цвет", self._trait_display(creature.get("phenotype_color")))
        self._set_phenotype_badge("size", "Размер", self._trait_display(creature.get("phenotype_size")))
        self._set_phenotype_badge("wings", "Крылья", self._trait_display(creature.get("phenotype_has_wings")))
        self._set_phenotype_badge("nutrition", "Питание", self._trait_display(creature.get("phenotype_nutrition_type")))
        self._set_phenotype_badge("details", "Детали", self._phenotype_detail_display(phenotype_summary_text))
        self.creature_portrait.set_creature(
            species_label=species_text,
            phenotype_color=self._trait_display(creature.get("phenotype_color")),
            phenotype_size=self._trait_display(creature.get("phenotype_size")),
            phenotype_wings=self._trait_display(creature.get("phenotype_has_wings")),
            phenotype_nutrition=self._trait_display(creature.get("phenotype_nutrition_type")),
            phenotype_summary=phenotype_summary_text,
            creature_key=creature.get("creature_id") or creature.get("creature_name"),
        )

    def _fill_genotype_table(self, rows: list[dict[str, Any]]) -> None:
        self._clear_genotype_cards()

        if not rows:
            self._add_genotype_hint("Генотип выбранного существа не найден.")
            return

        for rec in rows:
            self._add_genotype_card(rec)

        self.genotype_layout.addStretch()

    def _add_genotype_card(self, rec: dict[str, Any]) -> None:
        gene = self._gene_display(rec.get("gene_name"))
        gene_type = display_gene_type(rec.get("gene_type"))
        dominance = self._dominance_display(rec.get("dominance_type"))
        allele1 = self._trait_display(rec.get("allele1_description"))
        allele2 = self._trait_display(rec.get("allele2_description"))

        card = QFrame()
        card.setObjectName("geneCard")
        card.setToolTip(self._genotype_tooltip(rec))

        layout = QVBoxLayout(card)
        layout.setContentsMargins(10, 8, 10, 8)
        layout.setSpacing(4)

        title = QLabel(f"Признак: {gene}")
        title.setObjectName("geneCardTitle")
        title.setWordWrap(True)
        layout.addWidget(title)

        meta = QLabel(f"Тип: {gene_type}\nДоминирование: {dominance}")
        meta.setObjectName("muted")
        meta.setWordWrap(True)
        layout.addWidget(meta)

        alleles = QLabel(f"Аллели: {allele1} + {allele2}")
        alleles.setWordWrap(True)
        layout.addWidget(alleles)


        self.genotype_layout.addWidget(card)

    def _add_genotype_hint(self, text: str) -> None:
        hint = QLabel(text)
        hint.setObjectName("subtitle")
        hint.setWordWrap(True)
        self.genotype_layout.addWidget(hint)

    def _clear_genotype_cards(self) -> None:
        while self.genotype_layout.count():
            item = self.genotype_layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()

    def _genotype_tooltip(self, rec: dict[str, Any]) -> str:
        technical_values = (
            f"Технические значения аллелей: {self._display(rec.get('allele1_trait_value'))} / "
            f"{self._display(rec.get('allele2_trait_value'))}"
        )
        return "\n".join(
            [
                technical_values,
                f"gene_name: {self._display(rec.get('gene_name'))}",
                f"gene_type: {self._display(rec.get('gene_type'))}",
                f"dominance_type: {self._display(rec.get('dominance_type'))}",
                f"allele1_description: {self._display(rec.get('allele1_description'))}",
                f"allele2_description: {self._display(rec.get('allele2_description'))}",
            ]
        )

    def _clear_selected_creature_card(self) -> None:
        self.lbl_creature_id.setText("-")
        self.lbl_creature_name.setText("-")
        self.creature_name_title.setText("Выберите существо")
        self.creature_id_badge.setText("ID: -")
        self.lbl_species.setText("-")
        self.lbl_color.setText("-")
        self.lbl_size.setText("-")
        self.lbl_wings.setText("-")
        self.lbl_nutrition.setText("-")
        self.phenotype_summary.setText("-")
        for key, title_text in (
            ("species", "Вид"),
            ("color", "Цвет"),
            ("size", "Размер"),
            ("wings", "Крылья"),
            ("nutrition", "Питание"),
            ("details", "Детали"),
        ):
            self._set_phenotype_badge(key, title_text, "-")
        self.creature_portrait.clear()
        self._clear_genotype_cards()

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
    def _phenotype_detail_display(summary: Any) -> str:
        text = CreaturesTab._display(summary).casefold()
        labels = []
        checks = [
            ("плавник", ("плавник",)),
            ("панцирь", ("панцир",)),
            ("клешни", ("клеш",)),
            ("раковина", ("раков", "моллюск")),
            ("шерсть", ("шерст",)),
            ("скорость", ("скор", "быстр")),
            ("шипы", ("шип",)),
        ]
        for label, tokens in checks:
            if any(token in text for token in tokens):
                labels.append(label)
        return ", ".join(labels[:3]) if labels else "см. описание"

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





