from __future__ import annotations

from PySide6.QtWidgets import QMessageBox

from app.config import AppConfig
from app.db.connection import close_connection, create_connection
from app.db.pkg_api import PkgApi
from app.gui.auth_window import AuthWindow
from app.gui.lab_window import LabWindow
from app.gui.main_window import MainWindow
from app.services.session_state import SessionState


class GuiController:
    def __init__(self, state: SessionState, pkg_api: PkgApi) -> None:
        self.state = state
        self.pkg_api = pkg_api

        self.auth_window: AuthWindow | None = None
        self.lab_window: LabWindow | None = None
        self.main_window: MainWindow | None = None

        self._programmatic_close = False
        self._application_closing = False
        self._connection_closed = False

    def start(self) -> None:
        self.show_auth_window()

    def is_programmatic_close(self) -> bool:
        return self._programmatic_close

    def _close_windows(self) -> None:
        self._programmatic_close = True
        try:
            for window in (self.auth_window, self.lab_window, self.main_window):
                if window is not None:
                    window.close()
        finally:
            self._programmatic_close = False

    def show_auth_window(self) -> None:
        self._close_windows()
        self.auth_window = AuthWindow(
            pkg_api=self.pkg_api,
            state=self.state,
            on_login_success=self.show_lab_window,
        )
        self.lab_window = None
        self.main_window = None
        self.auth_window.show()

    def show_lab_window(self) -> None:
        if self.state.session_token is None or self.state.user_id is None:
            self.show_auth_window()
            return

        self._close_windows()
        self.lab_window = LabWindow(
            pkg_api=self.pkg_api,
            state=self.state,
            on_open_lab=self.show_main_window,
            on_logout=self.logout_to_auth,
            on_window_close=self.close_application,
            is_programmatic_close=self.is_programmatic_close,
        )
        self.auth_window = None
        self.main_window = None
        self.lab_window.refresh_labs()
        self.lab_window.show()

    def show_main_window(self, lab_id: int) -> None:
        self.state.set_selected_lab(lab_id)

        self._close_windows()
        self.main_window = MainWindow(
            pkg_api=self.pkg_api,
            state=self.state,
            on_back_to_labs=self.return_to_lab_selection,
            on_logout=self.logout_to_auth,
            on_window_close=self.close_application,
            is_programmatic_close=self.is_programmatic_close,
        )
        self.auth_window = None
        self.lab_window = None
        self.main_window.refresh_main_shell()
        self.main_window.show()

    def return_to_lab_selection(self) -> None:
        self.state.clear_lab_context()
        self.show_lab_window()

    def logout_to_auth(self) -> None:
        self._logout_current_session()
        self.state.clear_session_context()
        self._close_connection_once()

        if not self._open_fresh_connection_for_auth():
            return

        self.show_auth_window()

    def close_application(self) -> None:
        if self._application_closing:
            return

        self._application_closing = True
        self._logout_current_session()
        self.state.clear_session_context()
        self._close_connection_once()

    def _logout_current_session(self) -> None:
        token = self.state.session_token
        if not token:
            return

        try:
            self.pkg_api.logout_user(token)
        except Exception:
            pass

    def _close_connection_once(self) -> None:
        if self._connection_closed:
            return

        close_connection(self.state.connection)
        self._connection_closed = True

    def _open_fresh_connection_for_auth(self) -> bool:
        try:
            config = AppConfig.load()
            connection = create_connection(config.oracle)
        except Exception as exc:
            QMessageBox.critical(
                None,
                "Ошибка подключения к Oracle",
                (
                    "Выход из аккаунта выполнен, но не удалось открыть новое подключение к Oracle. "
                    "Перезапустите приложение или проверьте параметры подключения в .env.\n\n"
                    f"Технические детали: {exc}"
                ),
            )
            return False

        self.state.connection = connection
        self.pkg_api = PkgApi(connection)
        self._connection_closed = False
        return True
