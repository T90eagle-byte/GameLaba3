from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.gui.creatures_tab import CreaturesTab
from app.gui.crossbreed_tab import CrossbreedTab
from app.gui.mutations_tab import MutationsTab
from app.gui.tasks_tab import TasksTab
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState


class MainWindow(QWidget):
    def __init__(self, pkg_api: PkgApi, state: SessionState, on_logout) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_logout = on_logout

        self.stat_labels: dict[str, QLabel] = {}
        self.creatures_tab: CreaturesTab | None = None
        self.crossbreed_tab: CrossbreedTab | None = None
        self.mutations_tab: MutationsTab | None = None
        self.tasks_tab: TasksTab | None = None

        self.setWindowTitle("БиоСборка - Лаборатория")
        self.setMinimumSize(980, 640)
        self._build_ui()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 18, 20, 18)
        root.setSpacing(12)

        title_row = QHBoxLayout()

        title_col = QVBoxLayout()
        title = QLabel("Панель лаборатории")
        title.setObjectName("title")
        subtitle = QLabel("Игровая логика выполняется в Oracle PL/SQL")
        subtitle.setObjectName("subtitle")
        title_col.addWidget(title)
        title_col.addWidget(subtitle)

        title_row.addLayout(title_col)
        title_row.addStretch()

        refresh_btn = QPushButton("Обновить статистику")
        refresh_btn.setProperty("role", "secondary")
        refresh_btn.clicked.connect(self.refresh_stats)

        logout_btn = QPushButton("Выход")
        logout_btn.clicked.connect(self.on_logout)

        title_row.addWidget(refresh_btn)
        title_row.addWidget(logout_btn)

        root.addLayout(title_row)

        stats_card = QFrame()
        stats_card.setProperty("card", "true")
        stats_layout = QGridLayout(stats_card)
        stats_layout.setContentsMargins(12, 12, 12, 12)
        stats_layout.setHorizontalSpacing(18)
        stats_layout.setVerticalSpacing(10)

        self._add_stat(stats_layout, 0, 0, "ID лаборатории", "lab_id")
        self._add_stat(stats_layout, 0, 1, "Монеты", "wallet")
        self._add_stat(stats_layout, 0, 2, "Рейтинг", "rating")
        self._add_stat(stats_layout, 0, 3, "Существа", "creature_count")
        self._add_stat(stats_layout, 1, 0, "Активные задания", "active_task_count")
        self._add_stat(stats_layout, 1, 1, "Выполненные задания", "completed_task_count")
        self._add_stat(stats_layout, 1, 2, "Эксперименты", "experiment_count")

        root.addWidget(stats_card)

        tabs = QTabWidget()

        self.creatures_tab = CreaturesTab(pkg_api=self.pkg_api, state=self.state)
        tabs.addTab(self.creatures_tab, "Существа")

        self.crossbreed_tab = CrossbreedTab(
            pkg_api=self.pkg_api,
            state=self.state,
            on_experiment_completed=self.refresh_main_shell,
        )
        tabs.addTab(self.crossbreed_tab, "Генетический эксперимент")

        self.mutations_tab = MutationsTab(
            pkg_api=self.pkg_api,
            state=self.state,
            on_lab_data_changed=self.refresh_main_shell,
        )
        tabs.addTab(self.mutations_tab, "Мутации")

        self.tasks_tab = TasksTab(
            pkg_api=self.pkg_api,
            state=self.state,
            on_lab_data_changed=self.refresh_main_shell,
        )
        tabs.addTab(self.tasks_tab, "Задания")

        tabs.addTab(self._placeholder_tab("История экспериментов"), "История экспериментов")

        root.addWidget(tabs)

    def _add_stat(self, layout: QGridLayout, row: int, col: int, label: str, key: str) -> None:
        container = QFrame()
        container.setProperty("card", "true")
        vbox = QVBoxLayout(container)
        vbox.setContentsMargins(10, 8, 10, 8)

        name = QLabel(label)
        name.setObjectName("subtitle")
        value = QLabel("-")
        value.setStyleSheet("font-size: 16px; font-weight: 600;")

        vbox.addWidget(name)
        vbox.addWidget(value)
        layout.addWidget(container, row, col)

        self.stat_labels[key] = value

    def _placeholder_tab(self, name: str) -> QWidget:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        card = QFrame()
        card.setProperty("card", "true")
        card_layout = QVBoxLayout(card)

        label = QLabel(f"Экран «{name}» будет реализован на следующем этапе.")
        label.setAlignment(Qt.AlignCenter)
        label.setWordWrap(True)
        label.setStyleSheet("font-size: 15px; color: #374151;")

        card_layout.addStretch()
        card_layout.addWidget(label)
        card_layout.addStretch()

        layout.addWidget(card)
        return tab

    def refresh_stats(self) -> None:
        lab_id = self.state.selected_lab_id
        if lab_id is None:
            QMessageBox.warning(self, "Лаборатория", "Сначала выберите лабораторию.")
            return

        try:
            stats = self.pkg_api.get_lab_stats(lab_id)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка статистики", map_oracle_error(exc))
            return

        self.state.set_lab_stats(stats)

        self.stat_labels["lab_id"].setText(str(lab_id))
        self.stat_labels["wallet"].setText(str(stats.get("wallet", 0)))
        self.stat_labels["rating"].setText(str(stats.get("rating", 0)))
        self.stat_labels["creature_count"].setText(str(stats.get("creature_count", 0)))
        self.stat_labels["active_task_count"].setText(str(stats.get("active_task_count", 0)))
        self.stat_labels["completed_task_count"].setText(str(stats.get("completed_task_count", 0)))
        self.stat_labels["experiment_count"].setText(str(stats.get("experiment_count", 0)))

    def refresh_main_shell(self) -> None:
        self.refresh_stats()

        if self.creatures_tab is not None:
            self.creatures_tab.refresh_data()

        if self.crossbreed_tab is not None:
            self.crossbreed_tab.refresh_creatures()

        if self.mutations_tab is not None:
            self.mutations_tab.refresh_data()

        if self.tasks_tab is not None:
            self.tasks_tab.refresh_data()
