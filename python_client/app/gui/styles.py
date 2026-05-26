APP_STYLE = """
QWidget {
    background-color: #f4f6fb;
    color: #1f2937;
    font-family: Segoe UI, Arial, sans-serif;
    font-size: 13px;
}

QMainWindow, QDialog {
    background-color: #f4f6fb;
}

QLabel#title {
    font-size: 20px;
    font-weight: 600;
    color: #111827;
}

QLabel#subtitle {
    color: #4b5563;
}

QLineEdit, QComboBox, QTableWidget, QTabWidget::pane {
    background: #ffffff;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    padding: 6px;
}

QPushButton {
    background-color: #2563eb;
    color: white;
    border: 0;
    border-radius: 6px;
    padding: 8px 14px;
    font-weight: 600;
}

QPushButton:hover {
    background-color: #1d4ed8;
}

QPushButton:pressed {
    background-color: #1e40af;
}

QPushButton[role='secondary'] {
    background-color: #e5e7eb;
    color: #111827;
}

QPushButton[role='secondary']:hover {
    background-color: #d1d5db;
}

QTableWidget {
    gridline-color: #e5e7eb;
    selection-background-color: #dbeafe;
    selection-color: #111827;
}

QHeaderView::section {
    background-color: #eef2ff;
    border: 0;
    border-right: 1px solid #d1d5db;
    border-bottom: 1px solid #d1d5db;
    padding: 6px;
    font-weight: 600;
}

QTabBar::tab {
    background: #e5e7eb;
    border: 1px solid #d1d5db;
    border-bottom: none;
    border-top-left-radius: 6px;
    border-top-right-radius: 6px;
    padding: 8px 12px;
    margin-right: 2px;
}

QTabBar::tab:selected {
    background: #ffffff;
    color: #111827;
}

QFrame[card='true'] {
    background-color: #ffffff;
    border: 1px solid #dbe1ea;
    border-radius: 8px;
}
"""