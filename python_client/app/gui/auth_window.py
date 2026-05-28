from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFrame,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from app.db.pkg_api import PkgApi
from app.services.oracle_errors import map_oracle_error
from app.services.session_state import SessionState


class AuthWindow(QWidget):
    def __init__(self, pkg_api: PkgApi, state: SessionState, on_login_success) -> None:
        super().__init__()
        self.pkg_api = pkg_api
        self.state = state
        self.on_login_success = on_login_success

        self.setWindowTitle("БиоСборка — Авторизация")
        self.setMinimumSize(540, 430)

        self._build_ui()

    def _build_ui(self) -> None:
        root_layout = QVBoxLayout(self)
        root_layout.setContentsMargins(24, 20, 24, 20)
        root_layout.setSpacing(14)

        title = QLabel("БиоСборка")
        title.setObjectName("title")
        subtitle = QLabel("Вход в лабораторную систему")
        subtitle.setObjectName("subtitle")

        root_layout.addWidget(title)
        root_layout.addWidget(subtitle)

        onboarding_card = QFrame()
        onboarding_card.setProperty("card", "true")
        onboarding_layout = QVBoxLayout(onboarding_card)
        onboarding_layout.setContentsMargins(12, 10, 12, 10)
        onboarding_layout.setSpacing(6)

        onboarding_title = QLabel("Как начать")
        onboarding_title.setObjectName("subtitle")
        onboarding_text = QLabel(
            "1) Войдите или зарегистрируйтесь.\n"
            "2) Создайте лабораторию.\n"
            "3) Изучайте существ, проводите эксперименты и выполняйте задания."
        )
        onboarding_text.setWordWrap(True)

        onboarding_layout.addWidget(onboarding_title)
        onboarding_layout.addWidget(onboarding_text)

        root_layout.addWidget(onboarding_card)

        self.tabs = QTabWidget()
        self.tabs.addTab(self._build_login_tab(), "Вход")
        self.tabs.addTab(self._build_register_tab(), "Регистрация")
        root_layout.addWidget(self.tabs)

    def _build_login_tab(self) -> QWidget:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        box = QGroupBox("Вход")
        form = QFormLayout(box)
        form.setLabelAlignment(Qt.AlignRight)

        self.login_input = QLineEdit()
        self.login_input.setPlaceholderText("Логин: строчные латинские буквы и цифры")

        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.Password)
        self.password_input.setPlaceholderText("Пароль (не пустой)")

        form.addRow("Логин:", self.login_input)
        form.addRow("Пароль:", self.password_input)

        self.login_input.returnPressed.connect(self._handle_login)
        self.password_input.returnPressed.connect(self._handle_login)

        login_btn = QPushButton("Войти")
        login_btn.clicked.connect(self._handle_login)

        buttons = QHBoxLayout()
        buttons.addStretch()
        buttons.addWidget(login_btn)

        layout.addWidget(box)
        layout.addLayout(buttons)
        layout.addStretch()
        return tab

    def _build_register_tab(self) -> QWidget:
        tab = QWidget()
        layout = QVBoxLayout(tab)

        box = QGroupBox("Регистрация")
        form = QFormLayout(box)
        form.setLabelAlignment(Qt.AlignRight)

        self.reg_username_input = QLineEdit()
        self.reg_username_input.setPlaceholderText("Отображаемое имя")

        self.reg_login_input = QLineEdit()
        self.reg_login_input.setPlaceholderText("Логин: строчные латинские буквы и цифры")

        self.reg_password_input = QLineEdit()
        self.reg_password_input.setEchoMode(QLineEdit.Password)
        self.reg_password_input.setPlaceholderText("Пароль (не пустой)")

        self.reg_password_repeat_input = QLineEdit()
        self.reg_password_repeat_input.setEchoMode(QLineEdit.Password)
        self.reg_password_repeat_input.setPlaceholderText("Повторите пароль")

        form.addRow("Имя:", self.reg_username_input)
        form.addRow("Логин:", self.reg_login_input)
        form.addRow("Пароль:", self.reg_password_input)
        form.addRow("Повтор пароля:", self.reg_password_repeat_input)

        self.reg_username_input.returnPressed.connect(self._handle_register)
        self.reg_login_input.returnPressed.connect(self._handle_register)
        self.reg_password_input.returnPressed.connect(self._handle_register)
        self.reg_password_repeat_input.returnPressed.connect(self._handle_register)

        register_btn = QPushButton("Зарегистрироваться")
        register_btn.clicked.connect(self._handle_register)

        buttons = QHBoxLayout()
        buttons.addStretch()
        buttons.addWidget(register_btn)

        layout.addWidget(box)
        layout.addLayout(buttons)
        layout.addStretch()
        return tab

    def _handle_login(self) -> None:
        login = self.login_input.text().strip()
        password = self.password_input.text()

        if not login or not password:
            QMessageBox.warning(self, "Проверка данных", "Введите логин и пароль.")
            return

        try:
            token = self.pkg_api.login_user(login, password)
            if not token:
                QMessageBox.warning(self, "Вход", "Неверный логин или пароль.")
                return

            user_id = self.pkg_api.resolve_user_id_by_token(token)
            if user_id is None:
                QMessageBox.critical(
                    self,
                    "Вход",
                    "Не удалось определить пользователя по токену сессии. Повторите вход.",
                )
                return

            self.state.session_token = token
            self.state.user_id = user_id
            self.state.clear_lab_context()
            self.on_login_success()
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка входа", map_oracle_error(exc))

    def _handle_register(self) -> None:
        username = self.reg_username_input.text().strip()
        login = self.reg_login_input.text().strip()
        password = self.reg_password_input.text()
        password_repeat = self.reg_password_repeat_input.text()

        if not username or not login or not password:
            QMessageBox.warning(self, "Проверка данных", "Заполните имя, логин и пароль.")
            return

        if password != password_repeat:
            QMessageBox.warning(self, "Проверка данных", "Пароли не совпадают.")
            return

        try:
            self.pkg_api.register_user(username, login, password)
            QMessageBox.information(self, "Регистрация", "Пользователь успешно создан. Теперь выполните вход.")
            self.login_input.setText(login)
            self.password_input.setFocus()
            self.tabs.setCurrentIndex(0)
        except Exception as exc:
            QMessageBox.critical(self, "Ошибка регистрации", map_oracle_error(exc))

