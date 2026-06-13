from __future__ import annotations

from typing import Any, Callable

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.gui.creature_portrait import CreaturePortraitWidget
from app.services.display_names import (
    display_creature_name,
    display_gene_name,
    display_gene_type,
    display_mutation_name,
    display_task_name,
    display_trait_value,
    display_value,
    format_phenotype_summary,
    mutagen_type_label,
    mutation_type_label,
    species_label,
)
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState


class MutationsTab(QWidget):
    STATUS_NO_TARGET_GENE = "NO_TARGET_GENE"
    STATUS_HAS_TARGET_ALLELE = "HAS_TARGET_ALLELE"
    STATUS_CAN_CHANGE = "CAN_CHANGE"

    def __init__(
        self,
        pkg_api: PkgApi,
        state: SessionState,
        on_lab_data_changed: Callable[[], None] | None = None,
    ) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_lab_data_changed = on_lab_data_changed

        self._shop_rows: list[dict[str, Any]] = []
        self._creatures: list[dict[str, Any]] = []
        self._creature_by_id: dict[int, dict[str, Any]] = {}

        self._target_genes: list[dict[str, Any]] = []
        self._compatible_creature_ids: set[int] = set()
        self._mutation_stock_qty: int = 0
        self._selected_creature_target_warning: str = ""
        self._creature_compatibility_state: dict[int, str] = {}

        self.last_purchased_mutation_id: int | None = None

        self._build_ui()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(10)

        heading_row = QHBoxLayout()
        heading = QVBoxLayout()

        title = QLabel("Мутации")
        title.setObjectName("title")
        subtitle = QLabel("Магазин мутаций, совместимость существ и мутагенные воздействия")
        subtitle.setObjectName("subtitle")
        heading.addWidget(title)
        heading.addWidget(subtitle)

        self.refresh_shop_btn = QPushButton("Обновить магазин")
        self.refresh_shop_btn.setProperty("role", "secondary")
        self.refresh_shop_btn.clicked.connect(self.refresh_shop)

        self.refresh_creatures_btn = QPushButton("Обновить список существ")
        self.refresh_creatures_btn.setProperty("role", "secondary")
        self.refresh_creatures_btn.clicked.connect(self.refresh_creatures)

        heading_row.addLayout(heading)
        heading_row.addStretch()
        heading_row.addWidget(self.refresh_shop_btn)
        heading_row.addWidget(self.refresh_creatures_btn)

        root.addLayout(heading_row)

        self.mutations_info_panel = QFrame()
        self.mutations_info_panel.setObjectName("mutationStandInfo")
        info_layout = QVBoxLayout(self.mutations_info_panel)
        info_layout.setContentsMargins(10, 8, 10, 8)
        info_text = QLabel("Мутация — купленное направленное изменение признака. Мутаген — экспериментальное воздействие с ценой, риском и штрафом рейтинга.")
        info_text.setObjectName("subtitle")
        info_text.setProperty("helpCard", True)
        info_text.setWordWrap(True)
        info_layout.addWidget(info_text)
        root.addWidget(self.mutations_info_panel)

        content_row = QHBoxLayout()
        content_row.setSpacing(10)

        shop_card = QFrame()
        shop_card.setProperty("card", "true")
        shop_card.setObjectName("mutationShopCard")
        shop_layout = QVBoxLayout(shop_card)
        shop_layout.setContentsMargins(12, 12, 12, 12)
        shop_layout.setSpacing(8)

        shop_title = QLabel("1. Магазин мутаций")
        shop_title.setObjectName("subtitle")
        shop_layout.addWidget(shop_title)

        self.shop_table = QTableWidget(0, 6)
        self.shop_table.setHorizontalHeaderLabels(
            ["ID", "Название", "Тип", "Описание", "Цена", "Эффект рейтинга"]
        )
        self.shop_table.verticalHeader().setVisible(False)
        self.shop_table.verticalHeader().setDefaultSectionSize(38)
        self.shop_table.setWordWrap(True)
        self.shop_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.shop_table.setSelectionBehavior(QTableWidget.SelectRows)
        self.shop_table.setSelectionMode(QTableWidget.SingleSelection)
        self.shop_table.horizontalHeader().setStretchLastSection(True)
        self.shop_table.setAlternatingRowColors(True)
        self.shop_table.itemSelectionChanged.connect(self._on_mutation_selected)
        shop_layout.addWidget(self.shop_table)

        selected_mutation_form = QFormLayout()
        selected_mutation_form.setLabelAlignment(Qt.AlignRight)

        self.selected_mutation_id_label = QLabel("-")
        self.selected_mutation_name_label = QLabel("-")
        self.selected_mutation_name_label.setObjectName("mutationTitle")
        self.selected_mutation_name_label.setWordWrap(True)
        self.selected_mutation_price_label = QLabel("-")
        self.selected_mutation_stock_label = QLabel("0")
        self.selected_mutation_stock_label.setProperty("badge", True)
        self.selected_mutation_stock_label.setProperty("badgeType", "stock")

        selected_mutation_form.addRow("Выбрано (ID):", self.selected_mutation_id_label)
        selected_mutation_form.addRow("Название:", self.selected_mutation_name_label)
        selected_mutation_form.addRow("Цена:", self.selected_mutation_price_label)
        selected_mutation_form.addRow("Запас в лаборатории:", self.selected_mutation_stock_label)
        shop_layout.addLayout(selected_mutation_form)

        self.buy_btn = QPushButton("Купить мутацию")
        self.buy_btn.setToolTip("\u041a\u0443\u043f\u0438\u0442\u044c \u0432\u044b\u0431\u0440\u0430\u043d\u043d\u0443\u044e \u043c\u0443\u0442\u0430\u0446\u0438\u044e \u0432 \u0437\u0430\u043f\u0430\u0441 \u043b\u0430\u0431\u043e\u0440\u0430\u0442\u043e\u0440\u0438\u0438.")
        self.buy_btn.clicked.connect(self.buy_selected_mutation)
        shop_layout.addWidget(self.buy_btn)

        target_genes_title = QLabel("2. Целевые гены")
        target_genes_title.setObjectName("subtitle")
        shop_layout.addWidget(target_genes_title)

        self.target_genes_table = QTableWidget(0, 7)
        self.target_genes_table.setHorizontalHeaderLabels(
            [
                "ID гена",
                "Название гена",
                "Тип гена",
                "Признак",
                "Целевой слот",
                "Значение",
                "Описание целевого аллеля",
            ]
        )
        self.target_genes_table.verticalHeader().setVisible(False)
        self.target_genes_table.verticalHeader().setDefaultSectionSize(36)
        self.target_genes_table.setWordWrap(True)
        self.target_genes_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.target_genes_table.setSelectionBehavior(QTableWidget.SelectRows)
        self.target_genes_table.setSelectionMode(QTableWidget.SingleSelection)
        self.target_genes_table.horizontalHeader().setStretchLastSection(True)
        self.target_genes_table.setAlternatingRowColors(True)
        shop_layout.addWidget(self.target_genes_table)

        self.target_hint_label = QLabel("Выберите мутацию, чтобы увидеть целевые гены.")
        self.target_hint_label.setObjectName("subtitle")
        self.target_hint_label.setWordWrap(True)
        shop_layout.addWidget(self.target_hint_label)

        content_row.addWidget(shop_card, 3)

        right_col = QVBoxLayout()
        right_col.setSpacing(10)

        creature_card = QFrame()
        creature_card.setProperty("card", "true")
        creature_card.setObjectName("mutationCreatureCard")
        creature_layout = QFormLayout(creature_card)
        creature_layout.setContentsMargins(12, 12, 12, 12)
        creature_layout.setLabelAlignment(Qt.AlignRight)

        creature_title = QLabel("3. Выбранное существо")
        creature_title.setObjectName("subtitle")
        creature_layout.addRow("", creature_title)

        self.creature_portrait = CreaturePortraitWidget(mode="compact")
        self.creature_portrait.set_compact_canvas_limit(560, 260)
        self.creature_portrait.setMinimumSize(500, 230)
        portrait_row = QHBoxLayout()
        portrait_row.addStretch()
        portrait_row.addWidget(self.creature_portrait)
        portrait_row.addStretch()
        creature_layout.addRow("", portrait_row)

        self.only_compatible_checkbox = QCheckBox("Показывать несовместимых существ")
        self.only_compatible_checkbox.setChecked(False)
        self.only_compatible_checkbox.toggled.connect(self._on_compatibility_filter_toggled)
        creature_layout.addRow("", self.only_compatible_checkbox)

        self.creature_combo = QComboBox()
        self.creature_combo.currentIndexChanged.connect(self._on_creature_changed)

        self.creature_id_label = QLabel("-")
        self.creature_name_label = QLabel("-")
        self.creature_species_label = QLabel("-")
        self.creature_phenotype_label = QLabel("-")
        self.creature_phenotype_label.setWordWrap(True)
        self.creature_phenotype_label.setMinimumHeight(48)
        self.creature_compatibility_label = QLabel("Выберите мутацию и существо.")
        self.creature_compatibility_label.setProperty("compatibilityStatus", "neutral")
        self.creature_compatibility_label.setWordWrap(True)

        creature_layout.addRow("Существо:", self.creature_combo)
        creature_layout.addRow("ID:", self.creature_id_label)
        creature_layout.addRow("Имя:", self.creature_name_label)
        creature_layout.addRow("Вид:", self.creature_species_label)
        creature_layout.addRow("Фенотип:", self.creature_phenotype_label)
        creature_layout.addRow("Совместимость:", self.creature_compatibility_label)

        right_col.addWidget(creature_card)

        apply_card = QFrame()
        apply_card.setProperty("card", "true")
        apply_card.setObjectName("mutationApplyCard")
        apply_layout = QVBoxLayout(apply_card)
        apply_layout.setContentsMargins(12, 12, 12, 12)
        apply_layout.setSpacing(8)

        apply_title = QLabel("4. Применение мутации")
        apply_title.setObjectName("subtitle")
        apply_layout.addWidget(apply_title)

        self.apply_mutation_btn = QPushButton("Применить купленную мутацию")
        self.apply_mutation_btn.setToolTip("\u041f\u0440\u0438\u043c\u0435\u043d\u0438\u0442\u044c \u0432\u044b\u0431\u0440\u0430\u043d\u043d\u0443\u044e \u043c\u0443\u0442\u0430\u0446\u0438\u044e \u043a \u0432\u044b\u0431\u0440\u0430\u043d\u043d\u043e\u043c\u0443 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0443.")
        self.apply_mutation_btn.clicked.connect(self.apply_selected_mutation)
        apply_layout.addWidget(self.apply_mutation_btn)

        self.apply_state_label = QLabel("Сначала выберите мутацию.")
        self.apply_state_label.setObjectName("subtitle")
        self.apply_state_label.setWordWrap(True)
        apply_layout.addWidget(self.apply_state_label)

        self.apply_hint_label = QLabel(
            "\u041c\u0443\u0442\u0430\u0446\u0438\u044f \u2014 \u043a\u0443\u043f\u043b\u0435\u043d\u043d\u043e\u0435 \u043d\u0430\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u043d\u043e\u0435 \u0438\u0437\u043c\u0435\u043d\u0435\u043d\u0438\u0435 \u043f\u0440\u0438\u0437\u043d\u0430\u043a\u0430. "
            "\u0415\u0441\u043b\u0438 \u0443 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0430 \u0443\u0436\u0435 \u0435\u0441\u0442\u044c \u0446\u0435\u043b\u0435\u0432\u043e\u0439 \u0430\u043b\u043b\u0435\u043b\u044c, \u0432\u0438\u0434\u0438\u043c\u044b\u0439 \u043f\u0440\u0438\u0437\u043d\u0430\u043a \u043c\u043e\u0436\u0435\u0442 \u043d\u0435 \u0438\u0437\u043c\u0435\u043d\u0438\u0442\u044c\u0441\u044f."
        )
        self.apply_hint_label.setObjectName("subtitle")
        self.apply_hint_label.setProperty("helpCard", True)
        self.apply_hint_label.setWordWrap(True)
        apply_layout.addWidget(self.apply_hint_label)

        self.target_allele_warning_label = QLabel("")
        self.target_allele_warning_label.setObjectName("subtitle")
        self.target_allele_warning_label.setProperty("resultStatus", "warning")
        self.target_allele_warning_label.setWordWrap(True)
        self.target_allele_warning_label.setVisible(False)
        apply_layout.addWidget(self.target_allele_warning_label)

        right_col.addWidget(apply_card)

        mutagen_card = QFrame()
        mutagen_card.setProperty("card", "true")
        mutagen_card.setObjectName("mutagenCard")
        mutagen_layout = QFormLayout(mutagen_card)
        mutagen_layout.setContentsMargins(12, 12, 12, 12)
        mutagen_layout.setLabelAlignment(Qt.AlignRight)

        mutagen_title = QLabel("5. Мутагены")
        mutagen_title.setObjectName("subtitle")
        mutagen_layout.addRow("", mutagen_title)

        self.mutagen_type_combo = QComboBox()
        self.mutagen_type_combo.addItem("Радиационный мутаген (RADIATION)", "RADIATION")
        self.mutagen_type_combo.addItem("Химический мутаген (CHEMICAL)", "CHEMICAL")

        self.apply_mutagen_btn = QPushButton("Применить мутаген")
        self.apply_mutagen_btn.setToolTip("\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u043d\u043e\u0432\u043e\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u043e \u0447\u0435\u0440\u0435\u0437 \u0432\u044b\u0431\u0440\u0430\u043d\u043d\u043e\u0435 \u0432\u043e\u0437\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435.")
        self.apply_mutagen_btn.clicked.connect(self.apply_selected_mutagen)

        self.new_creature_id_label = QLabel("-")

        mutagen_layout.addRow("Тип мутагена:", self.mutagen_type_combo)
        mutagen_layout.addRow("", self.apply_mutagen_btn)
        mutagen_layout.addRow("ID нового существа:", self.new_creature_id_label)

        self.mutagen_info_label = QLabel(
            "Радиационный мутаген (RADIATION): стоимость 50 монет, рейтинг -5, риск высокий, эффект более случайный.\nХимический мутаген (CHEMICAL): стоимость 100 монет, рейтинг -2, риск ниже, эффект более контролируемый."
        )
        self.mutagen_info_label.setObjectName("subtitle")
        self.mutagen_info_label.setProperty("helpCard", True)
        self.mutagen_info_label.setWordWrap(True)
        mutagen_layout.addRow("", self.mutagen_info_label)

        self.mutagen_radiation_badge = QLabel('RADIATION: 50 монет, рейтинг -5, риск высокий')
        self.mutagen_radiation_badge.setProperty("badge", True)
        self.mutagen_radiation_badge.setProperty("badgeType", "radiation")
        self.mutagen_radiation_badge.setToolTip("\u0414\u0435\u0448\u0435\u0432\u043b\u0435, \u043d\u043e \u0440\u0438\u0441\u043a\u043e\u0432\u0430\u043d\u043d\u0435\u0435 \u0438 \u0441\u0438\u043b\u044c\u043d\u0435\u0435 \u0441\u043d\u0438\u0436\u0430\u0435\u0442 \u0440\u0435\u0439\u0442\u0438\u043d\u0433.")
        self.mutagen_chemical_badge = QLabel('CHEMICAL: 100 монет, рейтинг -2, риск ниже')
        self.mutagen_chemical_badge.setProperty("badge", True)
        self.mutagen_chemical_badge.setProperty("badgeType", "chemical")
        self.mutagen_chemical_badge.setToolTip("\u0414\u043e\u0440\u043e\u0436\u0435, \u043d\u043e \u043c\u044f\u0433\u0447\u0435 \u043f\u043e \u0440\u0435\u0439\u0442\u0438\u043d\u0433\u0443 \u0438 \u0431\u043e\u043b\u0435\u0435 \u043a\u043e\u043d\u0442\u0440\u043e\u043b\u0438\u0440\u0443\u0435\u043c\u043e.")
        mutagen_layout.addRow("", self.mutagen_radiation_badge)
        mutagen_layout.addRow("", self.mutagen_chemical_badge)

        right_col.addWidget(mutagen_card)

        content_row.addLayout(right_col, 2)
        root.addLayout(content_row)

    def refresh_data(self) -> None:
        self.refresh_shop()
        self.refresh_creatures()

    def refresh_shop(self) -> None:
        selected_mutation_id = self._selected_mutation_id() or self.last_purchased_mutation_id

        try:
            self._shop_rows = self.pkg_api.show_mutation_shop()
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка магазина", map_oracle_error(exc))
            return

        self.shop_table.blockSignals(True)
        self.shop_table.setRowCount(0)

        for row_idx, row in enumerate(self._shop_rows):
            self.shop_table.insertRow(row_idx)
            self._set_shop_item(row_idx, 0, row.get("mutation_id"), center=True)
            self._set_shop_item(row_idx, 1, display_mutation_name(row.get("mutation_name")))
            self._set_shop_item(row_idx, 2, row.get("mutation_type_display_name") or mutation_type_label(row.get("mutation_type")), center=True)
            self._set_shop_item(row_idx, 3, row.get("description"))
            self._set_shop_item(row_idx, 4, row.get("price"), center=True)
            self._set_shop_item(row_idx, 5, row.get("rating_effect"), center=True)

        if self.shop_table.rowCount() > 0:
            target_row = 0
            if selected_mutation_id is not None:
                for idx, row in enumerate(self._shop_rows):
                    if self._to_int(row.get("mutation_id")) == self._to_int(selected_mutation_id):
                        target_row = idx
                        break
            self.shop_table.selectRow(target_row)
        else:
            self._clear_selected_mutation_labels()

        self.shop_table.blockSignals(False)
        self._on_mutation_selected()

    def refresh_creatures(self) -> None:
        lab_id = self.state.selected_lab_id
        if lab_id is None:
            QMessageBox.warning(self, "Мутации", "Сначала выберите лабораторию.")
            return

        current_creature_id = self.creature_combo.currentData()

        try:
            self._creatures = self.pkg_api.get_creatures(lab_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка списка существ", map_oracle_error(exc))
            return

        self._creature_by_id = {}
        for creature in self._creatures:
            creature_id = self._to_int(creature.get("creature_id"))
            if creature_id is not None:
                self._creature_by_id[creature_id] = creature

        self._rebuild_creature_compatibility_state()
        self._update_creature_combo(current_creature_id)

    def buy_selected_mutation(self) -> None:
        lab_id = self.state.selected_lab_id
        mutation_id = self._selected_mutation_id()

        if lab_id is None:
            QMessageBox.warning(self, "Мутации", "Сначала выберите лабораторию.")
            return
        if mutation_id is None:
            QMessageBox.warning(self, "Мутации", "Выберите мутацию в магазине.")
            return

        try:
            result = self.pkg_api.buy_mutation(lab_id, mutation_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка покупки", map_oracle_error(exc))
            return

        if result == 0:
            QMessageBox.warning(self, "Мутации", "Недостаточно средств для покупки мутации.")
            return

        self.last_purchased_mutation_id = mutation_id
        QMessageBox.information(self, "Мутации", "Мутация успешно куплена.")
        self._notify_lab_data_changed()

    def apply_selected_mutation(self) -> None:
        creature_id = self._to_int(self.creature_combo.currentData())
        mutation_id = self._selected_mutation_id()

        if creature_id is None:
            QMessageBox.warning(self, "Мутации", "Выберите существо для применения мутации.")
            return
        if mutation_id is None:
            QMessageBox.warning(self, "Мутации", "Выберите мутацию в магазине.")
            return

        lab_id = self.state.selected_lab_id
        before_tasks = self._get_tasks_snapshot(lab_id)

        try:
            self.pkg_api.apply_mutation(creature_id, mutation_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка применения", map_oracle_error(exc))
            return

        QMessageBox.information(self, "Мутации", "Мутация успешно применена к существу.")

        lab_id = self.state.selected_lab_id
        if lab_id is not None:
            try:
                qty_after = self.pkg_api.get_lab_mutation_quantity(lab_id, mutation_id)
                if qty_after <= 0 and self.last_purchased_mutation_id == mutation_id:
                    self.last_purchased_mutation_id = None
            except Exception:
                pass

        after_tasks = self._get_tasks_snapshot(lab_id)
        auto_completed = self._collect_auto_completed_tasks(before_tasks, after_tasks)
        self._show_auto_completed_tasks_notice(auto_completed, "После применения мутации автоматически выполнены задания:")

        self._notify_lab_data_changed()

    def apply_selected_mutagen(self) -> None:
        creature_id = self._to_int(self.creature_combo.currentData())
        mutagen_type = self.mutagen_type_combo.currentData()

        if creature_id is None:
            QMessageBox.warning(self, "Мутагены", "Выберите существо для применения мутагена.")
            return
        if mutagen_type is None:
            QMessageBox.warning(self, "Мутагены", "Выберите тип мутагена.")
            return

        lab_id = self.state.selected_lab_id
        before_tasks = self._get_tasks_snapshot(lab_id)

        try:
            new_creature_id = self.pkg_api.apply_mutagen(creature_id, str(mutagen_type))
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка мутагена", map_oracle_error(exc))
            return

        self.new_creature_id_label.setText(str(new_creature_id))
        caption = mutagen_type_label(mutagen_type, with_code=False)
        QMessageBox.information(
            self,
            "Мутагены",
            f"{caption} мутаген применён успешно. Создано новое существо с ID: {new_creature_id}",
        )

        after_tasks = self._get_tasks_snapshot(lab_id)
        auto_completed = self._collect_auto_completed_tasks(before_tasks, after_tasks)
        self._show_auto_completed_tasks_notice(auto_completed, "После применения мутагена автоматически выполнены задания:")

        self._notify_lab_data_changed()


    def _get_tasks_snapshot(self, lab_id: int | None) -> list[dict[str, Any]]:
        if lab_id is None:
            return []
        try:
            return self.pkg_api.get_tasks(lab_id)
        except Exception:
            return []

    def _collect_auto_completed_tasks(
        self,
        before_tasks: list[dict[str, Any]],
        after_tasks: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        before_status: dict[int, str] = {}
        for row in before_tasks:
            assignment_id = self._to_int(row.get("lab_task_id"))
            if assignment_id is None:
                continue
            before_status[assignment_id] = str(row.get("task_status") or "").upper()

        completed: list[dict[str, Any]] = []
        for row in after_tasks:
            assignment_id = self._to_int(row.get("lab_task_id"))
            if assignment_id is None:
                continue
            after = str(row.get("task_status") or "").upper()
            before = before_status.get(assignment_id, "")
            if after == "COMPLETED" and before != "COMPLETED":
                completed.append(row)
        return completed

    def _show_auto_completed_tasks_notice(self, completed_tasks: list[dict[str, Any]], title: str) -> None:
        if not completed_tasks:
            return

        lines: list[str] = [title]
        for task in completed_tasks:
            task_name = display_task_name(task.get("task_display_name") or task.get("task_name"))
            reward_money = self._display(task.get("reward_money"))
            reward_rating = self._display(task.get("reward_rating"))
            lines.append(f"• {task_name}: +{reward_money} монет, +{reward_rating} рейтинга")

        QMessageBox.information(self, "Задания", "\n".join(lines))

    def _on_mutation_selected(self) -> None:
        mutation = self._selected_mutation_row()
        if mutation is None:
            self._clear_selected_mutation_labels()
            self._target_genes = []
            self._compatible_creature_ids = set()
            self._mutation_stock_qty = 0
            self._selected_creature_target_warning = ""
            self._creature_compatibility_state = {}
            self._fill_target_genes_table([])
            self.target_hint_label.setText("Выберите мутацию, чтобы увидеть целевые гены.")
            self._update_creature_combo(self.creature_combo.currentData())
            self._update_apply_mutation_state()
            return

        mutation_id = self._to_int(mutation.get("mutation_id"))
        self.selected_mutation_id_label.setText(self._display(mutation.get("mutation_id")))
        self.selected_mutation_name_label.setText(display_mutation_name(mutation.get("mutation_name")))
        self.selected_mutation_price_label.setText(self._display(mutation.get("price")))

        self._load_mutation_targets_and_compatibility(mutation_id)
        self._fill_target_genes_table(self._target_genes)
        self._update_target_hint()
        self._update_creature_combo(self.creature_combo.currentData())
        self._evaluate_target_allele_overlap(self._to_int(self.creature_combo.currentData()))
        self._update_apply_mutation_state()

    def _on_creature_changed(self) -> None:
        creature_id = self._to_int(self.creature_combo.currentData())
        creature = self._creature_by_id.get(creature_id) if creature_id is not None else None

        if creature is None:
            self.creature_id_label.setText("-")
            self.creature_name_label.setText("-")
            self.creature_species_label.setText("-")
            self.creature_phenotype_label.setText("-")
            self._set_compatibility_status("Выберите существо", "neutral")
            self.creature_portrait.clear()
            self._selected_creature_target_warning = ""
            self._update_apply_mutation_state()
            return

        self.creature_id_label.setText(self._display(creature.get("creature_id")))
        self.creature_name_label.setText(f"{display_creature_name(creature.get('creature_name'))} · ID {self._display(creature.get('creature_id'))}")
        self.creature_species_label.setText(self._species_text(creature))
        self.creature_phenotype_label.setText(format_phenotype_summary(creature.get("phenotype_summary")))
        self._set_compatibility_status(*self._compatibility_status_display(creature_id))
        self.creature_portrait.set_creature(
            species_label=self._species_text(creature),
            phenotype_color=display_trait_value(creature.get("phenotype_color")),
            phenotype_size=display_trait_value(creature.get("phenotype_size")),
            phenotype_wings=display_trait_value(creature.get("phenotype_has_wings")),
            phenotype_nutrition=display_trait_value(creature.get("phenotype_nutrition_type")),
            phenotype_summary=format_phenotype_summary(creature.get("phenotype_summary")),
            creature_key=creature.get("creature_id") or creature.get("creature_name"),
        )

        self._evaluate_target_allele_overlap(creature_id)
        self._update_apply_mutation_state()

    def _on_compatibility_filter_toggled(self) -> None:
        self._update_creature_combo(self.creature_combo.currentData())

    def _load_mutation_targets_and_compatibility(self, mutation_id: int | None) -> None:
        self._target_genes = []
        self._compatible_creature_ids = set()
        self._mutation_stock_qty = 0

        if mutation_id is None:
            self.selected_mutation_stock_label.setText("0")
            return

        lab_id = self.state.selected_lab_id
        if lab_id is None:
            self.selected_mutation_stock_label.setText("0")
            return

        try:
            self._target_genes = self.pkg_api.get_mutation_target_genes(mutation_id)
            compatible_ids = self.pkg_api.get_compatible_creature_ids_for_mutation(lab_id, mutation_id)
            self._compatible_creature_ids = set(compatible_ids)
            self._mutation_stock_qty = self.pkg_api.get_lab_mutation_quantity(lab_id, mutation_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка совместимости", map_oracle_error(exc))
            self._target_genes = []
            self._compatible_creature_ids = set()
            self._mutation_stock_qty = 0

        self.selected_mutation_stock_label.setText(str(self._mutation_stock_qty))
        self._rebuild_creature_compatibility_state()
        self._evaluate_target_allele_overlap(self._to_int(self.creature_combo.currentData()))

    def _fill_target_genes_table(self, rows: list[dict[str, Any]]) -> None:
        self.target_genes_table.setRowCount(0)

        for row_idx, row in enumerate(rows):
            self.target_genes_table.insertRow(row_idx)
            self._set_target_item(row_idx, 0, row.get("gene_id"), center=True)
            self._set_target_item(row_idx, 1, display_gene_name(row.get("gene_display_name") or row.get("gene_name")))
            self._set_target_item(row_idx, 2, display_gene_type(row.get("gene_type_display_name") or row.get("gene_type")))
            self._set_target_item(row_idx, 3, self._species_text(row), center=True)
            self._set_target_item(row_idx, 4, row.get("target_slot"), center=True)
            self._set_target_item(row_idx, 5, display_trait_value(row.get("trait_value")), center=True)
            self._set_target_item(row_idx, 6, display_trait_value(row.get("target_allele_display_name") or row.get("target_allele_description")))

    def _update_target_hint(self) -> None:
        if not self._target_genes:
            self.target_hint_label.setText("Для выбранной мутации не найдено целевых генов.")
            return

        names: list[str] = []
        for row in self._target_genes:
            gene_name = display_gene_name(row.get("gene_display_name") or row.get("gene_name"))
            if gene_name != "Не указано" and gene_name not in names:
                names.append(gene_name)

        if not names:
            self.target_hint_label.setText(
                "Эта мутация действует на набор целевых генов. Выберите совместимое существо."
            )
            return

        if len(names) == 1:
            self.target_hint_label.setText(
                f"Эта мутация действует на ген «{names[0]}». Выберите существо, у которого есть этот ген."
            )
            return

        self.target_hint_label.setText(
            f"Эта мутация действует на гены: {', '.join(names)}. Выберите существо, у которого есть эти гены."
        )

    def _rebuild_creature_compatibility_state(self) -> None:
        self._creature_compatibility_state = {}

        mutation_id = self._selected_mutation_id()
        if mutation_id is None:
            return

        for creature in self._creatures:
            creature_id = self._to_int(creature.get("creature_id"))
            if creature_id is None:
                continue

            try:
                genotype_rows = self.pkg_api.get_genotype(creature_id)
            except Exception:
                self._creature_compatibility_state[creature_id] = self.STATUS_CAN_CHANGE
                continue

            self._creature_compatibility_state[creature_id] = self._get_creature_mutation_status(genotype_rows)

    def _get_creature_mutation_status(self, genotype_rows: list[dict[str, Any]]) -> str:
        if not self._target_genes:
            return self.STATUS_CAN_CHANGE

        genotype_by_gene: dict[int, dict[str, Any]] = {}
        for row in genotype_rows:
            gene_id = self._to_int(row.get("gene_id"))
            if gene_id is not None:
                genotype_by_gene[gene_id] = row

        rules_with_genotype: list[tuple[dict[str, Any], dict[str, Any]]] = []

        for rule in self._target_genes:
            gene_id = self._to_int(rule.get("gene_id"))
            if gene_id is None:
                continue

            genotype_row = genotype_by_gene.get(gene_id)
            if genotype_row is None:
                return self.STATUS_NO_TARGET_GENE

            rules_with_genotype.append((genotype_row, rule))

        if not rules_with_genotype:
            return self.STATUS_NO_TARGET_GENE

        all_matched = all(
            self._matches_target_rule(genotype_row, rule)
            for genotype_row, rule in rules_with_genotype
        )
        if all_matched:
            return self.STATUS_HAS_TARGET_ALLELE
        return self.STATUS_CAN_CHANGE

    def _update_creature_combo(self, selected_creature_id: Any) -> None:
        mutation_id = self._selected_mutation_id()
        selected_id_int = self._to_int(selected_creature_id)

        self.creature_combo.blockSignals(True)
        self.creature_combo.clear()
        self.creature_combo.addItem("Выберите существо...", None)

        selected_index = 0
        show_incompatible = self.only_compatible_checkbox.isChecked() and mutation_id is not None

        for creature in self._creatures:
            creature_id = self._to_int(creature.get("creature_id"))
            if creature_id is None:
                continue

            status = (
                self._creature_compatibility_state.get(creature_id, self.STATUS_CAN_CHANGE)
                if mutation_id is not None
                else self.STATUS_CAN_CHANGE
            )
            is_compatible = status != self.STATUS_NO_TARGET_GENE
            if mutation_id is not None and not show_incompatible and not is_compatible:
                continue

            name = display_creature_name(creature.get("creature_name"))
            species_text = self._species_text(creature)
            base_label = f"{name} · ID {creature_id} | {species_text}"

            if mutation_id is None:
                label = base_label
            elif status == self.STATUS_NO_TARGET_GENE:
                label = f"[нет нужного гена] {base_label}"
            elif status == self.STATUS_HAS_TARGET_ALLELE:
                label = f"[уже есть целевой аллель] {base_label}"
            else:
                label = f"[можно изменить] {base_label}"

            self.creature_combo.addItem(label, creature_id)
            if selected_id_int is not None and creature_id == selected_id_int:
                selected_index = self.creature_combo.count() - 1

        self.creature_combo.setCurrentIndex(selected_index)
        self.creature_combo.blockSignals(False)

        self._on_creature_changed()

    def _evaluate_target_allele_overlap(self, creature_id: int | None) -> None:
        self._selected_creature_target_warning = ""

        mutation_id = self._selected_mutation_id()
        if mutation_id is None or creature_id is None or not self._target_genes:
            return

        status = self._creature_compatibility_state.get(creature_id, self.STATUS_CAN_CHANGE)
        if status == self.STATUS_HAS_TARGET_ALLELE:
            self._selected_creature_target_warning = (
                "У выбранного существа уже есть целевой аллель. "
                "Применение может не изменить фенотип."
            )

    def _matches_target_rule(self, genotype_row: dict[str, Any], rule: dict[str, Any]) -> bool:
        target_slot = self._display(rule.get("target_slot")).strip()
        target_desc = self._normalize_text(rule.get("target_allele_description"))
        if not target_desc or target_desc == "не указано":
            return False

        allele1_desc = self._normalize_text(genotype_row.get("allele1_description"))
        allele2_desc = self._normalize_text(genotype_row.get("allele2_description"))

        if target_slot == "1":
            return allele1_desc == target_desc
        if target_slot == "2":
            return allele2_desc == target_desc
        return allele1_desc == target_desc or allele2_desc == target_desc

    def _update_apply_mutation_state(self) -> None:
        mutation_id = self._selected_mutation_id()
        creature_id = self._to_int(self.creature_combo.currentData())

        reason = ""
        can_apply = False

        if mutation_id is None:
            reason = "Сначала выберите мутацию."
        elif self._mutation_stock_qty <= 0:
            reason = "Сначала купите выбранную мутацию."
        elif creature_id is None:
            reason = "Выберите существо для применения мутации."
        elif self._creature_compatibility_state.get(creature_id, self.STATUS_NO_TARGET_GENE) == self.STATUS_NO_TARGET_GENE:
            reason = "Выбранное существо не содержит целевой ген этой мутации."
        else:
            reason = "Можно применить."
            can_apply = True

        self.apply_mutation_btn.setEnabled(can_apply)
        if can_apply:
            state = "success"
        elif creature_id is not None and self._creature_compatibility_state.get(creature_id) == self.STATUS_NO_TARGET_GENE:
            state = "error"
        else:
            state = "neutral"
        self._set_apply_state(reason, state)
        self.target_allele_warning_label.setText(self._selected_creature_target_warning)
        self.target_allele_warning_label.setVisible(bool(self._selected_creature_target_warning))

    def _set_apply_state(self, text: str, status: str) -> None:
        self.apply_state_label.setText(text)
        self.apply_state_label.setProperty("resultStatus", status)
        self.apply_state_label.style().unpolish(self.apply_state_label)
        self.apply_state_label.style().polish(self.apply_state_label)

    def _compatibility_status_display(self, creature_id: int | None) -> tuple[str, str]:
        mutation_id = self._selected_mutation_id()
        if mutation_id is None or creature_id is None:
            return "Выберите мутацию и существо.", "neutral"

        status = self._creature_compatibility_state.get(creature_id, self.STATUS_CAN_CHANGE)
        if status == self.STATUS_NO_TARGET_GENE:
            return "[нет нужного гена] У существа нет целевого гена этой мутации.", "blocked"
        if status == self.STATUS_HAS_TARGET_ALLELE:
            return "[уже есть целевой аллель] Применение может не изменить фенотип.", "warning"
        return "[можно изменить] Существо содержит целевой ген выбранной мутации.", "ready"

    def _set_compatibility_status(self, text: str, status: str) -> None:
        self.creature_compatibility_label.setText(text)
        self.creature_compatibility_label.setProperty("compatibilityStatus", status)
        self.creature_compatibility_label.style().unpolish(self.creature_compatibility_label)
        self.creature_compatibility_label.style().polish(self.creature_compatibility_label)

    def _notify_lab_data_changed(self) -> None:
        if self.on_lab_data_changed is not None:
            self.on_lab_data_changed()
        else:
            self.refresh_data()

    def _selected_mutation_row(self) -> dict[str, Any] | None:
        row_idx = self.shop_table.currentRow()
        if row_idx < 0 or row_idx >= len(self._shop_rows):
            return None
        return self._shop_rows[row_idx]

    def _selected_mutation_id(self) -> int | None:
        mutation = self._selected_mutation_row()
        if mutation is None:
            return None
        return self._to_int(mutation.get("mutation_id"))

    def _clear_selected_mutation_labels(self) -> None:
        self.selected_mutation_id_label.setText("-")
        self.selected_mutation_name_label.setText("-")
        self.selected_mutation_price_label.setText("-")
        self.selected_mutation_stock_label.setText("0")

    def _set_shop_item(self, row: int, col: int, value: Any, center: bool = False) -> None:
        item = QTableWidgetItem(self._display(value))
        if center:
            item.setTextAlignment(Qt.AlignCenter)
        self.shop_table.setItem(row, col, item)

    def _set_target_item(self, row: int, col: int, value: Any, center: bool = False) -> None:
        item = QTableWidgetItem(self._display(value))
        if center:
            item.setTextAlignment(Qt.AlignCenter)
        self.target_genes_table.setItem(row, col, item)

    @staticmethod
    def _display(value: Any) -> str:
        return display_value(value)

    @staticmethod
    def _species_text(value: Any) -> str:
        if isinstance(value, dict):
            display_name = value.get("species_display_name")
            if display_name is not None and str(display_name).strip():
                return str(display_name).strip()
            value = value.get("species_type")
        return species_label(value)

    @staticmethod
    def _to_int(value: Any) -> int | None:
        if value is None:
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _normalize_text(value: Any) -> str:
        return display_value(value).strip().lower()


