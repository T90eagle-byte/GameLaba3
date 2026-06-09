from __future__ import annotations

from collections.abc import Callable

from PySide6.QtWidgets import (
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.gui.creatures_tab import CreaturesTab
from app.gui.crossbreed_tab import CrossbreedTab
from app.gui.history_tab import HistoryTab
from app.gui.mutations_tab import MutationsTab
from app.gui.tasks_tab import TasksTab
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState


class MainWindow(QWidget):
    def __init__(
        self,
        pkg_api: PkgApi,
        state: SessionState,
        on_back_to_labs,
        on_logout,
        on_window_close: Callable[[], None],
        is_programmatic_close: Callable[[], bool],
    ) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_back_to_labs = on_back_to_labs
        self.on_logout = on_logout
        self.on_window_close = on_window_close
        self.is_programmatic_close = is_programmatic_close

        self.stat_labels: dict[str, QLabel] = {}
        self.creatures_tab: CreaturesTab | None = None
        self.crossbreed_tab: CrossbreedTab | None = None
        self.mutations_tab: MutationsTab | None = None
        self.tasks_tab: TasksTab | None = None
        self.history_tab: HistoryTab | None = None
        self.tabs: QTabWidget | None = None

        self.setWindowTitle("БиоСборка — Лаборатория")
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
        subtitle = QLabel("Управляйте лабораторией, изучайте существ и проводите эксперименты.")
        subtitle.setObjectName("subtitle")
        title_col.addWidget(title)
        title_col.addWidget(subtitle)

        title_row.addLayout(title_col)
        title_row.addStretch()

        refresh_btn = QPushButton("Обновить статистику")
        refresh_btn.setProperty("role", "secondary")
        refresh_btn.clicked.connect(self.refresh_stats)

        back_to_labs_btn = QPushButton("К лабораториям")
        back_to_labs_btn.setProperty("role", "secondary")
        back_to_labs_btn.clicked.connect(self.on_back_to_labs)

        logout_btn = QPushButton("Выйти из аккаунта")
        logout_btn.clicked.connect(self.on_logout)

        title_row.addWidget(refresh_btn)
        title_row.addWidget(back_to_labs_btn)
        title_row.addWidget(logout_btn)

        root.addLayout(title_row)

        stats_card = QFrame()
        stats_card.setProperty("card", "true")
        stats_layout = QGridLayout(stats_card)
        stats_layout.setContentsMargins(12, 12, 12, 12)
        stats_layout.setHorizontalSpacing(18)
        stats_layout.setVerticalSpacing(10)

        self._add_stat(stats_layout, 0, 0, "Лаборатория", "lab_id")
        self._add_stat(stats_layout, 0, 1, "Монеты", "wallet")
        self._add_stat(stats_layout, 0, 2, "Рейтинг", "rating")
        self._add_stat(stats_layout, 0, 3, "Существа", "creature_count")
        self._add_stat(stats_layout, 1, 0, "Активные задания", "active_task_count")
        self._add_stat(stats_layout, 1, 1, "Выполненные задания", "completed_task_count")
        self._add_stat(stats_layout, 1, 2, "Эксперименты", "experiment_count")

        root.addWidget(stats_card)

        next_steps_card = QFrame()
        next_steps_card.setProperty("card", "true")
        next_steps_card.setObjectName("infoPanel")
        next_steps_layout = QVBoxLayout(next_steps_card)
        next_steps_layout.setContentsMargins(12, 10, 12, 10)
        next_steps_layout.setSpacing(6)

        next_steps_title = QLabel("Что делать дальше?")
        next_steps_title.setObjectName("subtitle")
        next_steps_text = QLabel(
            "\u041c\u0430\u0440\u0448\u0440\u0443\u0442 \u043f\u0435\u0440\u0432\u043e\u0433\u043e \u0437\u0430\u043f\u0443\u0441\u043a\u0430: \u0421\u0443\u0449\u0435\u0441\u0442\u0432\u0430 -> \u0413\u0435\u043d\u0435\u0442\u0438\u0447\u0435\u0441\u043a\u0438\u0439 \u044d\u043a\u0441\u043f\u0435\u0440\u0438\u043c\u0435\u043d\u0442 / \u041c\u0443\u0442\u0430\u0446\u0438\u0438 -> \u0417\u0430\u0434\u0430\u043d\u0438\u044f -> \u0418\u0441\u0442\u043e\u0440\u0438\u044f.\n"
            "\u0418\u0437\u0443\u0447\u0438\u0442\u0435 \u043f\u0440\u0438\u0437\u043d\u0430\u043a\u0438 \u0441\u0443\u0449\u0435\u0441\u0442\u0432, \u043f\u0440\u043e\u0432\u0435\u0434\u0438\u0442\u0435 \u044d\u043a\u0441\u043f\u0435\u0440\u0438\u043c\u0435\u043d\u0442, \u043f\u0440\u043e\u0432\u0435\u0440\u044c\u0442\u0435 \u043c\u0438\u0441\u0441\u0438\u0438 \u0438 \u043e\u0442\u043a\u0440\u043e\u0439\u0442\u0435 \u0436\u0443\u0440\u043d\u0430\u043b, \u0447\u0442\u043e\u0431\u044b \u0443\u0432\u0438\u0434\u0435\u0442\u044c \u0440\u0435\u0437\u0443\u043b\u044c\u0442\u0430\u0442."
        )
        next_steps_text.setProperty("helpCard", True)
        next_steps_text.setWordWrap(True)

        next_steps_layout.addWidget(next_steps_title)
        next_steps_layout.addWidget(next_steps_text)

        quick_actions = QHBoxLayout()
        quick_actions.setSpacing(8)
        self._add_quick_action(quick_actions, "Изучить существ", 0)
        self._add_quick_action(quick_actions, "Провести скрещивание", 1)
        self._add_quick_action(quick_actions, "Открыть мутации", 2)
        self._add_quick_action(quick_actions, "Проверить задания", 3)
        self._add_quick_action(quick_actions, "Открыть журнал", 4)
        next_steps_layout.addLayout(quick_actions)

        root.addWidget(next_steps_card)

        self.tabs = QTabWidget()

        self.creatures_tab = CreaturesTab(pkg_api=self.pkg_api, state=self.state)
        self.tabs.addTab(self._wrap_tab(self.creatures_tab), "Существа")

        self.crossbreed_tab = CrossbreedTab(
            pkg_api=self.pkg_api,
            state=self.state,
            on_experiment_completed=self.refresh_main_shell,
        )
        self.tabs.addTab(self._wrap_tab(self.crossbreed_tab), "Генетический эксперимент")

        self.mutations_tab = MutationsTab(
            pkg_api=self.pkg_api,
            state=self.state,
            on_lab_data_changed=self.refresh_main_shell,
        )
        self.tabs.addTab(self._wrap_tab(self.mutations_tab), "Мутации")

        self.tasks_tab = TasksTab(
            pkg_api=self.pkg_api,
            state=self.state,
            on_lab_data_changed=self.refresh_main_shell,
        )
        self.tabs.addTab(self._wrap_tab(self.tasks_tab), "Задания")

        self.history_tab = HistoryTab(pkg_api=self.pkg_api, state=self.state)
        self.tabs.addTab(self._wrap_tab(self.history_tab), "История экспериментов")

        root.addWidget(self.tabs)

    def _add_quick_action(self, layout: QHBoxLayout, label: str, index: int) -> None:
        button = QPushButton(label)
        tooltips = {
            0: "\u041f\u043e\u0441\u043c\u043e\u0442\u0440\u0435\u0442\u044c \u0444\u0435\u043d\u043e\u0442\u0438\u043f, \u0433\u0435\u043d\u043e\u0442\u0438\u043f \u0438 \u043f\u043e\u0440\u0442\u0440\u0435\u0442\u044b \u0441\u0443\u0449\u0435\u0441\u0442\u0432.",
            1: "\u0412\u044b\u0431\u0440\u0430\u0442\u044c \u0440\u043e\u0434\u0438\u0442\u0435\u043b\u0435\u0439 \u0438 \u043f\u043e\u0441\u043c\u043e\u0442\u0440\u0435\u0442\u044c \u0432\u0435\u0440\u043e\u044f\u0442\u043d\u043e\u0441\u0442\u0438 \u043f\u0440\u0438\u0437\u043d\u0430\u043a\u0430.",
            2: "\u041a\u0443\u043f\u0438\u0442\u044c \u0438 \u043f\u0440\u0438\u043c\u0435\u043d\u0438\u0442\u044c \u043d\u0430\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u043d\u044b\u0435 \u0438\u0437\u043c\u0435\u043d\u0435\u043d\u0438\u044f.",
            3: "\u041f\u0440\u043e\u0432\u0435\u0440\u0438\u0442\u044c \u043c\u0438\u0441\u0441\u0438\u0438 \u043f\u043e \u043f\u0440\u0438\u0437\u043d\u0430\u043a\u0430\u043c \u0432\u044b\u0431\u0440\u0430\u043d\u043d\u043e\u0433\u043e \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0430.",
            4: "\u041f\u043e\u0441\u043c\u043e\u0442\u0440\u0435\u0442\u044c \u0436\u0443\u0440\u043d\u0430\u043b \u0441\u043a\u0440\u0435\u0449\u0438\u0432\u0430\u043d\u0438\u0439, \u043c\u0443\u0442\u0430\u0446\u0438\u0439 \u0438 \u043c\u0443\u0442\u0430\u0433\u0435\u043d\u043e\u0432.",
        }
        button.setToolTip(tooltips.get(index, "\u041e\u0442\u043a\u0440\u044b\u0442\u044c \u0440\u0430\u0437\u0434\u0435\u043b."))
        button.setProperty("role", "quick")
        button.clicked.connect(lambda checked=False, tab_index=index: self._open_tab(tab_index))
        layout.addWidget(button)

    def _open_tab(self, index: int) -> None:
        if self.tabs is not None:
            self.tabs.setCurrentIndex(index)

    def closeEvent(self, event) -> None:
        if self.is_programmatic_close():
            event.accept()
            return

        self.on_window_close()
        event.accept()

    def _add_stat(self, layout: QGridLayout, row: int, col: int, label: str, key: str) -> None:
        container = QFrame()
        container.setProperty("card", "true")
        container.setObjectName("statCard")
        stat_tooltips = {
            "wallet": "\u041c\u043e\u043d\u0435\u0442\u044b \u043d\u0443\u0436\u043d\u044b \u0434\u043b\u044f \u043f\u043e\u043a\u0443\u043f\u043a\u0438 \u043c\u0443\u0442\u0430\u0446\u0438\u0439 \u0438 \u043c\u0443\u0442\u0430\u0433\u0435\u043d\u043d\u044b\u0445 \u0432\u043e\u0437\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0439.",
            "rating": "\u0420\u0435\u0439\u0442\u0438\u043d\u0433 \u0440\u0430\u0441\u0442\u0435\u0442 \u0437\u0430 \u0437\u0430\u0434\u0430\u043d\u0438\u044f \u0438 \u043c\u043e\u0436\u0435\u0442 \u0441\u043d\u0438\u0436\u0430\u0442\u044c\u0441\u044f \u043e\u0442 \u0440\u0438\u0441\u043a\u043e\u0432\u044b\u0445 \u0432\u043e\u0437\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0439.",
            "creature_count": "\u0421\u043a\u043e\u043b\u044c\u043a\u043e \u0441\u0443\u0449\u0435\u0441\u0442\u0432 \u0441\u0435\u0439\u0447\u0430\u0441 \u0435\u0441\u0442\u044c \u0432 \u043b\u0430\u0431\u043e\u0440\u0430\u0442\u043e\u0440\u0438\u0438.",
            "active_tasks": "\u0417\u0430\u0434\u0430\u043d\u0438\u044f, \u043a\u043e\u0442\u043e\u0440\u044b\u0435 \u0435\u0449\u0435 \u043c\u043e\u0436\u043d\u043e \u043f\u0440\u043e\u0432\u0435\u0440\u0438\u0442\u044c \u0438 \u0437\u0430\u0432\u0435\u0440\u0448\u0438\u0442\u044c.",
            "completed_tasks": "\u0423\u0436\u0435 \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u043d\u044b\u0435 \u0437\u0430\u0434\u0430\u043d\u0438\u044f.",
            "experiment_count": "\u0417\u0430\u043f\u0438\u0441\u0438 \u043e \u0441\u043a\u0440\u0435\u0449\u0438\u0432\u0430\u043d\u0438\u044f\u0445, \u043c\u0443\u0442\u0430\u0446\u0438\u044f\u0445 \u0438 \u043c\u0443\u0442\u0430\u0433\u0435\u043d\u0430\u0445.",
        }
        container.setToolTip(stat_tooltips.get(key, ""))
        vbox = QVBoxLayout(container)
        vbox.setContentsMargins(10, 8, 10, 8)

        name = QLabel(label)
        name.setObjectName("subtitle")
        name.setToolTip(container.toolTip())
        value = QLabel("—")
        value.setToolTip(container.toolTip())
        value.setStyleSheet("font-size: 16px; font-weight: 700;")

        vbox.addWidget(name)
        vbox.addWidget(value)
        layout.addWidget(container, row, col)

        self.stat_labels[key] = value

    @staticmethod
    def _wrap_tab(tab_widget: QWidget) -> QScrollArea:
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setWidget(tab_widget)
        return scroll

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
        self.stat_labels["wallet"].setText(self._format_stat(stats.get("wallet")))
        self.stat_labels["rating"].setText(self._format_stat(stats.get("rating")))
        self.stat_labels["creature_count"].setText(self._format_stat(stats.get("creature_count")))
        self.stat_labels["active_task_count"].setText(self._format_stat(stats.get("active_task_count")))
        self.stat_labels["completed_task_count"].setText(self._format_stat(stats.get("completed_task_count")))
        self.stat_labels["experiment_count"].setText(self._format_stat(stats.get("experiment_count")))

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

        if self.history_tab is not None:
            self.history_tab.refresh_data()

    @staticmethod
    def _format_stat(value) -> str:
        if value is None:
            return "Не указано"
        return str(value)






