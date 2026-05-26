import sys

from PySide6.QtWidgets import QApplication, QMessageBox

from app.config import AppConfig
from app.db.connection import close_connection, create_connection
from app.db.pkg_api import PkgApi
from app.gui.app import GuiController
from app.gui.styles import APP_STYLE
from app.services.session_state import SessionState


def main() -> int:
    app = QApplication(sys.argv)
    app.setStyleSheet(APP_STYLE)

    config = AppConfig.load()

    try:
        connection = create_connection(config.oracle)
    except Exception as exc:  # pragma: no cover - startup guard
        QMessageBox.critical(
            None,
            "Ошибка подключения к Oracle",
            (
                "Не удалось подключиться к базе данных Oracle. "
                "Проверьте параметры подключения в файле .env.\n\n"
                f"Технические детали: {exc}"
            ),
        )
        return 1

    state = SessionState(connection=connection)
    pkg_api = PkgApi(connection)
    controller = GuiController(state=state, pkg_api=pkg_api)

    app.aboutToQuit.connect(lambda: close_connection(state.connection))

    controller.start()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
