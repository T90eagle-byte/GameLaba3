APP_STYLE = """
QWidget {
    background-color: #f3efe6;
    color: #243041;
    font-family: Segoe UI, Arial, sans-serif;
    font-size: 13px;
}

QMainWindow, QDialog {
    background-color: #f3efe6;
}

QLabel#title {
    font-size: 20px;
    font-weight: 800;
    color: #172033;
}

QLabel#subtitle {
    color: #5b6575;
    font-weight: 600;
}

QGroupBox {
    border: 1px solid #ddd0bb;
    border-radius: 8px;
    margin-top: 10px;
    padding-top: 10px;
    background: #fffdf8;
}

QGroupBox::title {
    subcontrol-origin: margin;
    left: 10px;
    padding: 0 4px;
    color: #1f2937;
    font-weight: 600;
}

QLineEdit, QComboBox, QTableWidget, QTabWidget::pane {
    background: #fffdf8;
    border: 1px solid #d8cab4;
    border-radius: 7px;
    padding: 6px;
}

QLineEdit:focus, QComboBox:focus {
    border: 1px solid #b8874f;
    background: #ffffff;
}

QComboBox::drop-down {
    border: 0;
    width: 24px;
}

QComboBox QAbstractItemView {
    background-color: #fffdf8;
    border: 1px solid #d8cab4;
    selection-background-color: #f4dfb6;
    selection-color: #1f2937;
}

QPushButton {
    background-color: #2f6f89;
    color: #ffffff;
    border: 1px solid #285d73;
    border-radius: 7px;
    padding: 8px 14px;
    font-weight: 700;
    min-height: 18px;
}

QPushButton:hover {
    background-color: #357f9d;
    border-color: #2e6f89;
}

QPushButton:pressed {
    background-color: #24596f;
}

QPushButton:disabled {
    background-color: #d8d1c6;
    border-color: #c9bfae;
    color: #817a70;
}

QPushButton[role='secondary'] {
    background-color: #f3eadc;
    color: #2c3442;
    border: 1px solid #d9c9ad;
}

QPushButton[role='secondary']:hover {
    background-color: #eadcc7;
    border-color: #c8b38e;
}

QPushButton[role='secondary']:pressed {
    background-color: #ddc9aa;
}

QPushButton[role='secondary']:disabled {
    background-color: #e4ded5;
    color: #8a8175;
}

QPushButton[role='quick'] {
    background-color: #fff8ea;
    color: #334155;
    border: 1px solid #e6d6b8;
    border-radius: 8px;
    padding: 7px 10px;
    font-weight: 600;
}

QPushButton[role='quick']:hover {
    background-color: #fff0d3;
    border-color: #d9bd88;
}

QPushButton[role='quick']:pressed {
    background-color: #f3dfb8;
}

QTableWidget {
    gridline-color: #eadfce;
    selection-background-color: #f4dfb6;
    selection-color: #1f2937;
    alternate-background-color: #fff8ec;
    background-color: #fffdf8;
}

QTableWidget::item {
    padding: 5px;
}

QTableWidget::item:hover {
    background-color: #fff3d8;
}

QTableWidget::item:selected {
    background-color: #f4dfb6;
    color: #1f2937;
}

QTableCornerButton::section {
    background-color: #efe3cf;
    border: 0;
    border-right: 1px solid #d7c5a7;
    border-bottom: 1px solid #d7c5a7;
}

QHeaderView::section {
    background-color: #efe3cf;
    border: 0;
    border-right: 1px solid #d7c5a7;
    border-bottom: 1px solid #d7c5a7;
    padding: 7px;
    font-weight: 700;
    color: #253247;
}

QTabBar::tab {
    background: #eadfce;
    border: 1px solid #d3c1a2;
    border-bottom: none;
    border-top-left-radius: 7px;
    border-top-right-radius: 7px;
    padding: 8px 12px;
    margin-right: 2px;
    color: #596272;
    font-weight: 600;
}

QTabBar::tab:hover {
    background: #f2e7d4;
    color: #2f3a4d;
}

QTabBar::tab:selected {
    background: #fffdf8;
    color: #172033;
    border-color: #c8b38e;
}

QTabWidget::pane {
    border: 1px solid #c8b38e;
    border-radius: 8px;
    background: #fffdf8;
    top: -1px;
}

QFrame#infoPanel {
    background-color: #fff7e8;
    border: 1px solid #e4c997;
    border-radius: 8px;
}

QFrame#geneCard {
    background-color: #fffaf0;
    border: 1px solid #eadfce;
    border-radius: 7px;
}

QLabel#geneCardTitle {
    font-weight: 700;
    color: #111827;
}

QLabel#muted {
    color: #64748b;
}

QLabel[helpCard='true'] {
    background-color: #fff8ea;
    border: 1px solid #e1c693;
    border-left: 4px solid #c99a4a;
    border-radius: 8px;
    padding: 8px 11px;
    color: #4b5563;
    line-height: 135%;
    font-weight: 500;
}

QFrame[card='true'] {
    background-color: #fffdf8;
    border: 1px solid #dfd0b8;
    border-radius: 8px;
}


QFrame#creaturePassportCard {
    background-color: #fffdf7;
    border: 1px solid #dfd2bd;
    border-radius: 10px;
}

QLabel#creatureNameTitle {
    color: #253247;
    font-size: 18px;
    font-weight: 800;
}

QLabel#creatureIdBadge {
    background-color: #f4ead8;
    border: 1px solid #d9c6a6;
    border-radius: 7px;
    padding: 4px 9px;
    color: #5b4630;
    font-weight: 700;
}

QFrame#phenotypeBadgePanel {
    background-color: #fffaf0;
    border: 1px dashed #dec9a4;
    border-radius: 8px;
}

QLabel[phenotypeBadge='true'] {
    background-color: #fffdf7;
    border: 1px solid #eadfce;
    border-radius: 7px;
    padding: 5px 8px;
    color: #344154;
    font-size: 12px;
}

QFrame#statCard {
    background-color: #fffaf0;
    border: 1px solid #e6d6b8;
    border-radius: 8px;
}

QLabel[statLabel='true'] {
    color: #64748b;
    font-size: 12px;
}

QLabel[statValue='true'] {
    color: #1f2937;
    font-size: 18px;
    font-weight: 700;
}

QFrame#creaturePortrait {
    background-color: #fffdf7;
    border: 1px solid #e2d6c2;
    border-radius: 10px;
}

QLabel[badge='true'] {
    background-color: #fff8ea;
    border: 1px solid #e0cfb1;
    border-radius: 7px;
    padding: 3px 8px;
    color: #374151;
    font-size: 12px;
    font-weight: 600;
}

QLabel[typechip='cross'] {
    background-color: #e8f1ff;
    border: 1px solid #c7dafc;
    border-radius: 6px;
    padding: 2px 8px;
}

QLabel[typechip='mutation'] {
    background-color: #f3ecff;
    border: 1px solid #dccfff;
    border-radius: 6px;
    padding: 2px 8px;
}

QLabel[typechip='mutagen'] {
    background-color: #eafaf2;
    border: 1px solid #c7eed8;
    border-radius: 6px;
    padding: 2px 8px;
}

QScrollBar:vertical {
    background: #efe6d7;
    width: 10px;
    margin: 0;
    border-radius: 5px;
}

QScrollBar::handle:vertical {
    background: #cdbb9c;
    min-height: 24px;
    border-radius: 5px;
}

QScrollBar::handle:vertical:hover {
    background: #bda682;
}

QScrollBar:horizontal {
    background: #efe6d7;
    height: 10px;
    margin: 0;
    border-radius: 5px;
}

QScrollBar::handle:horizontal {
    background: #cdbb9c;
    min-width: 24px;
    border-radius: 5px;
}

QScrollBar::handle:horizontal:hover {
    background: #bda682;
}

QScrollBar::add-line, QScrollBar::sub-line {
    width: 0;
    height: 0;
}

QScrollBar::add-page, QScrollBar::sub-page {
    background: transparent;
}


QFrame#missionListCard, QFrame#journalListCard {
    background-color: #fffdf7;
    border: 1px solid #e4d3b7;
    border-radius: 8px;
}

QFrame#missionCard, QFrame#journalCard {
    background-color: #fffaf0;
    border: 1px solid #dec9a4;
    border-radius: 8px;
}

QFrame#missionCreatureCard {
    background-color: #fbfff7;
    border: 1px solid #d7e5c5;
    border-radius: 8px;
}

QFrame#resultStatusCard {
    background-color: #f8fbff;
    border: 1px solid #d4dfef;
    border-radius: 8px;
}

QLabel#missionSectionTitle, QLabel#journalTitle {
    color: #1f2937;
    font-weight: 700;
    font-size: 14px;
}

QLabel#missionTitle {
    color: #0f172a;
    font-weight: 700;
    font-size: 16px;
}

QLabel#missionDescription {
    background-color: #fffdf7;
    border: 1px solid #eadfce;
    border-radius: 6px;
    padding: 8px;
    color: #334155;
}

QLabel[badgeType='difficulty'] {
    background-color: #fef3c7;
    border-color: #e7c66b;
    color: #4b3b12;
}

QLabel[badgeType='status'] {
    background-color: #e8f1ff;
    border-color: #bdd4fb;
    color: #1e3a8a;
}

QLabel[badgeType='reward'] {
    background-color: #eafaf2;
    border-color: #c5e8d2;
    color: #14532d;
}

QLabel[resultStatus='neutral'] {
    background-color: #fffdf7;
    border: 1px solid #e2d6c2;
    border-radius: 6px;
    padding: 8px;
    color: #475569;
}

QLabel[resultStatus='success'] {
    background-color: #ecfdf3;
    border: 1px solid #bbebcd;
    border-radius: 6px;
    padding: 8px;
    color: #166534;
    font-weight: 600;
}

QLabel[resultStatus='error'] {
    background-color: #fff1f2;
    border: 1px solid #fecdd3;
    border-radius: 6px;
    padding: 8px;
    color: #9f1239;
    font-weight: 600;
}

QLabel[resultStatus='done'] {
    background-color: #f5f0ff;
    border: 1px solid #d8c9ff;
    border-radius: 6px;
    padding: 8px;
    color: #5b21b6;
    font-weight: 600;
}

QLabel[emptyState='true'] {
    background-color: #fffaf0;
    border: 1px dashed #dec9a4;
    border-radius: 8px;
    padding: 8px;
    color: #64748b;
}


QFrame#experimentFlowCard,
QFrame#mutationStandInfo {
    background-color: #fff7e8;
    border: 1px solid #e8d4ad;
    border-radius: 8px;
}

QFrame#experimentSelectorCard,
QFrame#parentCard,
QFrame#probabilityCard,
QFrame#experimentResultCard,
QFrame#mutationShopCard,
QFrame#mutationCreatureCard,
QFrame#mutationApplyCard,
QFrame#mutagenCard {
    background-color: #fffdf7;
    border: 1px solid #e4d7c3;
    border-radius: 8px;
}

QLabel#flowSteps {
    background-color: #f5ead7;
    border: 1px solid #d7bd92;
    color: #4b3b25;
    font-weight: 700;
    padding: 7px 10px;
    border-radius: 6px;
}

QLabel#mutationTitle {
    color: #293241;
    font-size: 15px;
    font-weight: 700;
}

QLabel[badgeType='stock'] {
    background-color: #eef7ff;
    border-color: #bedaf7;
    color: #1d4f7a;
}

QLabel[badgeType='radiation'] {
    background-color: #fff3d8;
    border-color: #e8bd62;
    color: #7a4b00;
}

QLabel[badgeType='chemical'] {
    background-color: #eafaf2;
    border-color: #b8e4cd;
    color: #14532d;
}

QLabel[resultStatus='warning'] {
    background-color: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 6px;
    padding: 8px;
    color: #9a3412;
    font-weight: 600;
}

QLabel[compatibilityStatus='neutral'] {
    background-color: #fffdf7;
    border: 1px solid #e2d6c2;
    border-radius: 6px;
    padding: 7px;
    color: #64748b;
}

QLabel[compatibilityStatus='ready'] {
    background-color: #ecfdf3;
    border: 1px solid #bbebcd;
    border-radius: 6px;
    padding: 7px;
    color: #166534;
    font-weight: 600;
}

QLabel[compatibilityStatus='warning'] {
    background-color: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 6px;
    padding: 7px;
    color: #9a3412;
    font-weight: 600;
}

QLabel[compatibilityStatus='blocked'] {
    background-color: #fff1f2;
    border: 1px solid #fecdd3;
    border-radius: 6px;
    padding: 7px;
    color: #9f1239;
    font-weight: 600;
}

QToolTip {
    background-color: #fffdf8;
    color: #1f2937;
    border: 1px solid #cdbb9c;
    border-radius: 5px;
    padding: 6px 8px;
}

QMessageBox {
    background-color: #f3efe6;
}
"""


