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
from app.gui.creature_portrait import CreaturePortraitWidget
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState
from app.services.display_names import (
    display_creature_name,
    display_gene_name,
    display_task_name,
    display_trait_value,
    display_value,
    format_phenotype_summary,
    species_label,
)




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

        self.crossbreed_info_panel = QFrame()
        self.crossbreed_info_panel.setObjectName("experimentFlowCard")
        info_layout = QVBoxLayout(self.crossbreed_info_panel)
        info_layout.setContentsMargins(10, 8, 10, 8)
        info_text = QLabel("Выберите двух исходных существ одного вида, посмотрите вероятности признаков и создайте потомка.")
        info_text.setObjectName("subtitle")
        info_text.setProperty("helpCard", True)
        info_text.setWordWrap(True)
        info_layout.addWidget(info_text)

        self.crossbreed_flow_hint = QLabel('1) Выберите родителей   2) Посмотрите вероятность признака   3) Создайте потомка')
        self.crossbreed_flow_hint.setProperty("badge", True)
        self.crossbreed_flow_hint.setObjectName("flowSteps")
        info_layout.addWidget(self.crossbreed_flow_hint)
        root.addWidget(self.crossbreed_info_panel)

        selector_card = QFrame()
        selector_card.setProperty("card", "true")
        selector_card.setObjectName("experimentSelectorCard")
        selector_layout = QFormLayout(selector_card)
        selector_layout.setContentsMargins(12, 12, 12, 12)
        selector_layout.setLabelAlignment(Qt.AlignRight)

        self.parent_a_combo = QComboBox()
        self.parent_b_combo = QComboBox()
        self.gene_combo = QComboBox()

        self.parent_a_combo.setToolTip("\u041f\u0435\u0440\u0432\u043e\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u043e \u0434\u043b\u044f \u0441\u043a\u0440\u0435\u0449\u0438\u0432\u0430\u043d\u0438\u044f.")
        self.parent_b_combo.setToolTip("\u0412\u0442\u043e\u0440\u043e\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u043e \u0434\u043b\u044f \u0441\u043a\u0440\u0435\u0449\u0438\u0432\u0430\u043d\u0438\u044f.")
        self.gene_combo.setToolTip("\u0413\u0435\u043d \u0434\u043b\u044f \u043f\u0440\u043e\u0441\u043c\u043e\u0442\u0440\u0430 \u0432\u0435\u0440\u043e\u044f\u0442\u043d\u043e\u0441\u0442\u0435\u0439; \u043f\u043e\u0442\u043e\u043c\u043e\u043a \u0432\u0441\u0435 \u0440\u0430\u0432\u043d\u043e \u0441\u043e\u0437\u0434\u0430\u0435\u0442\u0441\u044f \u043f\u043e \u0432\u0441\u0435\u043c\u0443 \u0433\u0435\u043d\u043e\u0442\u0438\u043f\u0443.")

        self.parent_a_combo.currentIndexChanged.connect(self._on_parent_changed)
        self.parent_b_combo.currentIndexChanged.connect(self._on_parent_changed)

        selector_layout.addRow("Исходное существо A:", self.parent_a_combo)
        selector_layout.addRow("Исходное существо B:", self.parent_b_combo)
        selector_layout.addRow("Ген:", self.gene_combo)

        self.show_probabilities_btn = QPushButton("Показать вероятности")
        self.show_probabilities_btn.setToolTip("\u041f\u043e\u043a\u0430\u0437\u0430\u0442\u044c \u0432\u0430\u0440\u0438\u0430\u043d\u0442\u044b \u0432\u044b\u0431\u0440\u0430\u043d\u043d\u043e\u0433\u043e \u043f\u0440\u0438\u0437\u043d\u0430\u043a\u0430 \u0434\u043b\u044f \u043f\u0430\u0440\u044b \u0440\u043e\u0434\u0438\u0442\u0435\u043b\u0435\u0439.")
        self.show_probabilities_btn.clicked.connect(self.show_probabilities)
        selector_layout.addRow("", self.show_probabilities_btn)

        root.addWidget(selector_card)

        self.empty_experiment_hint = QLabel("")
        self.empty_experiment_hint.setObjectName("subtitle")
        self.empty_experiment_hint.setWordWrap(True)
        root.addWidget(self.empty_experiment_hint)

        cards_row = QHBoxLayout()
        self.parent_a_card, self.parent_a_fields, self.parent_a_portrait = self._build_source_card("Исходное существо A")
        self.parent_b_card, self.parent_b_fields, self.parent_b_portrait = self._build_source_card("Исходное существо B")
        cards_row.addWidget(self.parent_a_card)
        cards_row.addWidget(self.parent_b_card)
        root.addLayout(cards_row)

        probabilities_card = QFrame()
        probabilities_card.setProperty("card", "true")
        probabilities_card.setObjectName("probabilityCard")
        probabilities_layout = QVBoxLayout(probabilities_card)
        probabilities_layout.setContentsMargins(12, 12, 12, 12)

        probabilities_title = QLabel("Вероятности признаков")
        probabilities_title.setObjectName("subtitle")
        probabilities_layout.addWidget(probabilities_title)

        self.probabilities_table = QTableWidget(0, 4)
        self.probabilities_table.setHorizontalHeaderLabels(
            [
                "Признак",
                "Аллель 1",
                "Аллель 2",
                "Вероятность",
            ]
        )
        self.probabilities_table.verticalHeader().setVisible(False)
        self.probabilities_table.verticalHeader().setDefaultSectionSize(40)
        self.probabilities_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.probabilities_table.setSelectionBehavior(QTableWidget.SelectRows)
        self.probabilities_table.setSelectionMode(QTableWidget.SingleSelection)
        self.probabilities_table.setAlternatingRowColors(True)
        self.probabilities_table.setWordWrap(True)

        header = self.probabilities_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents)

        probabilities_layout.addWidget(self.probabilities_table)

        probabilities_hint = QLabel("Вероятности рассчитываются системой по генотипам выбранных существ.")
        probabilities_hint.setObjectName("subtitle")
        probabilities_hint.setProperty("helpCard", True)
        probabilities_hint.setWordWrap(True)
        probabilities_layout.addWidget(probabilities_hint)

        selected_gene_hint = QLabel("Выбранный ген используется только для просмотра вероятностей. Потомок наследует признаки по всему генотипу.")
        selected_gene_hint.setObjectName("subtitle")
        selected_gene_hint.setProperty("helpCard", True)
        selected_gene_hint.setWordWrap(True)
        probabilities_layout.addWidget(selected_gene_hint)

        root.addWidget(probabilities_card)

        result_card = QFrame()
        result_card.setProperty("card", "true")
        result_card.setObjectName("experimentResultCard")
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
        self.result_hint_label.setProperty("resultStatus", "neutral")
        self.result_hint_label.setWordWrap(True)

        result_layout.addRow("Имя результата:", self.result_name_input)
        result_layout.addRow("", self.create_result_btn)
        result_layout.addRow("ID результата:", self.result_id_label)
        result_layout.addRow("", self.result_hint_label)

        root.addWidget(result_card)

    def _build_source_card(self, header: str) -> tuple[QFrame, dict[str, Any], CreaturePortraitWidget]:
        frame = QFrame()
        frame.setProperty("card", "true")
        frame.setObjectName("parentCard")
        layout = QFormLayout(frame)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setLabelAlignment(Qt.AlignRight)

        title = QLabel(header)
        title.setObjectName("subtitle")
        layout.addRow("", title)

        portrait = CreaturePortraitWidget(mode="compact")
        layout.addRow("", portrait)

        fields = {
            "creature_id": QLabel("-"),
            "creature_name": QLabel("-"),
            "species_type": QLabel("-"),
            "phenotype_summary": QLabel("-"),
            "portrait": portrait,
        }

        fields["phenotype_summary"].setWordWrap(True)
        fields["phenotype_summary"].setMinimumHeight(48)

        layout.addRow("ID:", fields["creature_id"])
        layout.addRow("Имя:", fields["creature_name"])
        layout.addRow("Вид:", fields["species_type"])
        layout.addRow("Фенотип:", fields["phenotype_summary"])

        return frame, fields, portrait

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
        self._ensure_result_name_suggestion()

        if len(self._creatures) < 2:
            self.empty_experiment_hint.setText("Для эксперимента нужны два совместимых существа.")
        elif not self._has_shared_genes_selected_pair():
            self.empty_experiment_hint.setText(
                "Выберите двух существ одного вида с общими генами для расчета вероятностей."
            )
        else:
            self.empty_experiment_hint.setText("")

    def _fill_parent_combo(self, combo: QComboBox, selected_id: Any) -> None:
        combo.blockSignals(True)
        combo.clear()
        combo.addItem("Выберите существо...", None)

        selected_index = 0

        for creature in self._creatures:
            creature_id = self._to_int(creature.get("creature_id"))
            if creature_id is None:
                continue

            name = display_creature_name(creature.get("creature_name"))
            species_text = self._species_text(creature)
            combo.addItem(f"{name} · ID {creature_id} | {species_text}", creature_id)

            if selected_id is not None and creature_id == self._to_int(selected_id):
                selected_index = combo.count() - 1

        combo.setCurrentIndex(selected_index)
        combo.blockSignals(False)

    def _on_parent_changed(self) -> None:
        self._update_parent_cards()
        self._reload_genes()

        if len(self._creatures) < 2:
            self.empty_experiment_hint.setText("Для эксперимента нужны два совместимых существа.")
        elif not self._has_shared_genes_selected_pair():
            self.empty_experiment_hint.setText(
                "Выберите двух существ одного вида с общими генами для расчета вероятностей."
            )
        else:
            self.empty_experiment_hint.setText("")

    def _update_parent_cards(self) -> None:
        self._fill_card(self.parent_a_fields, self._selected_creature(self.parent_a_combo.currentData()))
        self._fill_card(self.parent_b_fields, self._selected_creature(self.parent_b_combo.currentData()))

    def _fill_card(self, fields: dict[str, Any], creature: dict[str, Any] | None) -> None:
        portrait_widget = fields.get("portrait")
        if creature is None:
            fields["creature_id"].setText("-")
            fields["creature_name"].setText("Выберите существо")
            fields["species_type"].setText("-")
            fields["phenotype_summary"].setText("После выбора здесь появится фенотип.")
            if isinstance(portrait_widget, CreaturePortraitWidget):
                portrait_widget.clear()
            return

        fields["creature_id"].setText(self._display(creature.get("creature_id")))
        fields["creature_name"].setText(f"{display_creature_name(creature.get('creature_name'))} · ID {self._display(creature.get('creature_id'))}")
        fields["species_type"].setText(self._species_text(creature))
        fields["phenotype_summary"].setText(format_phenotype_summary(creature.get("phenotype_summary")))

        if isinstance(portrait_widget, CreaturePortraitWidget):
            portrait_widget.set_creature(
                species_label=self._species_text(creature),
                phenotype_color=display_trait_value(creature.get("phenotype_color")),
                phenotype_size=display_trait_value(creature.get("phenotype_size")),
                phenotype_wings=display_trait_value(creature.get("phenotype_has_wings")),
                phenotype_nutrition=display_trait_value(creature.get("phenotype_nutrition_type")),
                phenotype_summary=format_phenotype_summary(creature.get("phenotype_summary")),
                creature_key=creature.get("creature_id") or creature.get("creature_name"),
            )

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
            self._to_int(row.get("gene_id")): display_gene_name(row.get("gene_display_name") or row.get("gene_name"))
            for row in genes_a
            if self._to_int(row.get("gene_id")) is not None
        }
        map_b = {
            self._to_int(row.get("gene_id")): display_gene_name(row.get("gene_display_name") or row.get("gene_name"))
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

        gene_text = self.gene_combo.currentText().split(" (ID:")[0]
        for row_idx, row in enumerate(probabilities):
            allele1 = display_trait_value(row.get("allele1_description"))
            allele2 = display_trait_value(row.get("allele2_description"))
            probability = self._format_probability(row.get("probability"))
            tooltip = (
                f"allele1_id: {self._display(row.get('allele1_id'))}\n"
                f"allele2_id: {self._display(row.get('allele2_id'))}\n"
                f"probability: {self._display(row.get('probability'))}"
            )

            self.probabilities_table.insertRow(row_idx)
            self._set_table_item(row_idx, 0, gene_text, tooltip=True)
            self._set_table_item(row_idx, 1, allele1, tooltip=True)
            self._set_table_item(row_idx, 2, allele2, tooltip=True)
            self._set_table_item(row_idx, 3, probability, center=True, tooltip_text=tooltip)

        self.probabilities_table.resizeRowsToContents()

        if self.probabilities_table.rowCount() == 0:
            QMessageBox.information(self, "Генетический эксперимент", "Для выбранного гена нет данных вероятностей.")

    def create_result(self) -> None:
        lab_id = self.state.selected_lab_id
        parent_a_id = self._to_int(self.parent_a_combo.currentData())
        parent_b_id = self._to_int(self.parent_b_combo.currentData())
        result_name = self.result_name_input.text().strip()
        before_tasks = self._get_tasks_snapshot(lab_id)

        if lab_id is None:
            QMessageBox.warning(self, "Генетический эксперимент", "Сначала выберите лабораторию.")
            return

        if parent_a_id is None or parent_b_id is None:
            QMessageBox.warning(self, "Генетический эксперимент", "Выберите два исходных существа.")
            return

        validation_error = self._validate_result_name(result_name)
        if validation_error is not None:
            suggested = self._suggest_unique_result_name()
            if suggested:
                self.result_name_input.setText(suggested)
                self.result_name_input.selectAll()
            QMessageBox.warning(self, "Генетический эксперимент", validation_error)
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
                f"Создан потомок: {result_name}. ID: {offspring_id}",
        )
        after_tasks = self._get_tasks_snapshot(lab_id)
        auto_completed = self._collect_auto_completed_tasks(before_tasks, after_tasks)
        self._show_auto_completed_tasks_notice(auto_completed, "После эксперимента автоматически выполнены задания:")

        self.result_name_input.clear()
        self.refresh_creatures()

        if self.on_experiment_completed is not None:
            self.on_experiment_completed()

    def _validate_result_name(self, result_name: str) -> str | None:
        if not result_name:
            suggested = self._suggest_unique_result_name()
            if suggested:
                return (
                    "Введите имя результирующего существа. "
                    f"Подсказка: {suggested}"
                )
            return "Введите имя результирующего существа."

        if result_name.isdigit():
            suggested = self._suggest_unique_result_name()
            return (
                "Имя не должно состоять только из цифр. "
                f"Подсказка: {suggested}"
            )

        normalized_new = self._normalize_name(result_name)
        if normalized_new in self._existing_creature_name_keys():
            suggested = self._suggest_unique_result_name()
            return (
                "Существо с таким именем уже есть в этой лаборатории. "
                f"Подсказка: {suggested}"
            )

        return None

    def _ensure_result_name_suggestion(self) -> None:
        if self.result_name_input.text().strip():
            return
        suggested = self._suggest_unique_result_name()
        if suggested:
            self.result_name_input.setText(suggested)

    def _suggest_unique_result_name(self) -> str:
        species_text = self._selected_species_for_result()
        base = "Результат эксперимента"
        if species_text and species_text != "Не указано":
            base = f"Потомок {species_text}"

        existing = self._existing_creature_name_keys()
        idx = 1
        while True:
            candidate = f"{base} №{idx}"
            if self._normalize_name(candidate) not in existing:
                return candidate
            idx += 1

    def _selected_species_for_result(self) -> str:
        parent_a = self._selected_creature(self.parent_a_combo.currentData())
        if parent_a is None:
            return ""
        return self._species_text(parent_a)

    def _existing_creature_name_keys(self) -> set[str]:
        names: set[str] = set()
        for creature in self._creatures:
            raw_name = creature.get("creature_name")
            normalized = self._normalize_name(raw_name)
            if normalized:
                names.add(normalized)
        return names

    @staticmethod
    def _normalize_name(value: Any) -> str:
        if value is None:
            return ""
        return str(value).strip().casefold()

    def _set_table_item(self, row: int, col: int, value: Any, center: bool = False, tooltip: bool = False, tooltip_text: str | None = None) -> None:
        text = self._display(value)
        item = QTableWidgetItem(text)
        if center:
            item.setTextAlignment(Qt.AlignCenter)
        if tooltip or tooltip_text:
            item.setToolTip(tooltip_text or text)
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
    def _has_shared_genes_selected_pair(self) -> bool:
        parent_a_id = self._to_int(self.parent_a_combo.currentData())
        parent_b_id = self._to_int(self.parent_b_combo.currentData())
        if parent_a_id is None or parent_b_id is None:
            return False

        gene_ids = [self.gene_combo.itemData(i) for i in range(self.gene_combo.count())]
        return any(gid is not None for gid in gene_ids)
    @staticmethod
    def _species_text(value: Any) -> str:
        if isinstance(value, dict):
            display_name = value.get("species_display_name")
            if display_name is not None and str(display_name).strip():
                return str(display_name).strip()
            value = value.get("species_type")
        return species_label(value)







