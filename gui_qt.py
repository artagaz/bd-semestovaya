#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import json
from datetime import date

try:
    from PySide6.QtWidgets import (
        QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
        QTableWidget, QTableWidgetItem, QPushButton, QLabel, QLineEdit,
        QComboBox, QDialog, QFormLayout, QMessageBox, QHeaderView,
        QTabWidget, QStatusBar, QGroupBox, QCheckBox, QTextEdit,
        QDateEdit, QSpinBox
    )
    from PySide6.QtCore import Qt, QDate, QTimer
    from PySide6.QtGui import QColor, QBrush, QFont
    QT_AVAILABLE = True
except ImportError:
    QT_AVAILABLE = False

try:
    import oracledb
    ORACLE_AVAILABLE = True
except ImportError:
    ORACLE_AVAILABLE = False


# =====================================================================
# Работа с БД
# =====================================================================
class DB:
    conn = None

    @classmethod
    def connect(cls, user, pwd, host, port, service, role):
        dsn = f"{host}:{port}/{service}"
        kwargs = {"user": user, "password": pwd, "dsn": dsn}
        if role == "SYSDBA":
            kwargs["mode"] = oracledb.SYSDBA
        elif role == "SYSOPER":
            kwargs["mode"] = oracledb.SYSOPER
        cls.conn = oracledb.connect(**kwargs)

    @classmethod
    def query(cls, sql, params=None):
        if cls.conn is None:
            return []
        with cls.conn.cursor() as cur:
            cur.execute(sql, params or {})
            return cur.fetchall()

    @classmethod
    def execute(cls, sql, params=None):
        if cls.conn is None:
            return
        with cls.conn.cursor() as cur:
            cur.execute(sql, params or {})
        cls.conn.commit()


# =====================================================================
# Диалог подключения
# =====================================================================
class ConnectDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Подключение к Oracle")
        self.setFixedSize(350, 300)
        layout = QFormLayout(self)

        self.user = QLineEdit("student")
        self.pwd = QLineEdit()
        self.pwd.setEchoMode(QLineEdit.Password)
        self.host = QLineEdit("localhost")
        self.port = QLineEdit("1521")
        self.service = QLineEdit("XEPDB1")
        self.role = QComboBox()
        self.role.addItems(["NORMAL", "SYSDBA", "SYSOPER"])

        layout.addRow("Пользователь:", self.user)
        layout.addRow("Пароль:", self.pwd)
        layout.addRow("Хост:", self.host)
        layout.addRow("Порт:", self.port)
        layout.addRow("Service Name:", self.service)
        layout.addRow("Role:", self.role)

        btn = QPushButton("Подключиться")
        btn.clicked.connect(self.do_connect)
        layout.addRow(btn)

    def do_connect(self):
        try:
            DB.connect(
                self.user.text(), self.pwd.text(), self.host.text(),
                self.port.text(), self.service.text(), self.role.currentText()
            )
            self.accept()
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))


# =====================================================================
# Диалог редактирования записи
# =====================================================================
class RecordDialog(QDialog):
    def __init__(self, title, fields, values=None, parent=None):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setFixedSize(400, 350)
        self.layout = QFormLayout(self)
        self.fields = {}
        values = values or {}

        for col, label in fields:
            edit = QLineEdit(str(values.get(col, "")))
            self.layout.addRow(label + ":", edit)
            self.fields[col] = edit

        btn = QPushButton("Сохранить")
        btn.clicked.connect(self.accept)
        self.layout.addRow(btn)

    def get_data(self):
        return {k: v.text() for k, v in self.fields.items()}


# =====================================================================
# Диалог деталей операции
# =====================================================================
class LogDetailDialog(QDialog):
    def __init__(self, log_id, table, op_type, old_data, new_data, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Детали операции #{log_id}")
        self.resize(500, 400)
        layout = QVBoxLayout(self)

        info = QLabel(f"<b>Таблица:</b> {table} &nbsp; <b>Операция:</b> {op_type}")
        layout.addWidget(info)

        def make_box(title, data, color):
            if not data:
                return
            box = QGroupBox(title)
            v = QVBoxLayout(box)
            te = QTextEdit()
            te.setReadOnly(True)
            te.setStyleSheet(f"background-color: {color};")
            try:
                te.setPlainText(json.dumps(json.loads(data), ensure_ascii=False, indent=2))
            except Exception:
                te.setPlainText(str(data))
            v.addWidget(te)
            layout.addWidget(box)

        make_box("До операции (old_data)", old_data, "#ffe6e6")
        make_box("После операции (new_data)", new_data, "#e6ffe6")

        btn = QPushButton("Закрыть")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn)


# =====================================================================
# Главное окно
# =====================================================================
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Магазин автозапчастей")
        self.resize(1150, 750)

        self.tabs = QTabWidget()
        self.setCentralWidget(self.tabs)

        self.build_table_tab("Suppliers", "suppliers",
                             ["id", "name", "category", "contact_info", "has_guarantee", "contract_id"],
                             [("name", "Название"), ("category", "Категория"),
                              ("contact_info", "Контакты"), ("has_guarantee", "Гарантия (Y/N)"),
                              ("contract_id", "Договор")])

        self.build_table_tab("Products", "products",
                             ["id", "name", "article"],
                             [("name", "Название"), ("article", "Артикул")])

        self.build_orders_tab()
        self.build_log_tab()
        self.build_report_tab()

        self.status = QStatusBar()
        self.setStatusBar(self.status)
        self.status.showMessage("Не подключено")

        QTimer.singleShot(0, self.show_connect)

    # -----------------------------------------------------------------
    # Универсальная вкладка таблицы
    # -----------------------------------------------------------------
    def build_table_tab(self, title, table, columns, fields):
        w = QWidget()
        v = QVBoxLayout(w)

        table_widget = QTableWidget()
        table_widget.setColumnCount(len(columns))
        table_widget.setHorizontalHeaderLabels(columns)
        table_widget.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        table_widget.setSelectionBehavior(QTableWidget.SelectRows)
        v.addWidget(table_widget)
        setattr(self, f"tw_{table}", table_widget)

        h = QHBoxLayout()
        btn_refresh = QPushButton("🔄 Обновить")
        btn_refresh.clicked.connect(lambda: self.load_table(table, columns))
        btn_add = QPushButton("➕ Добавить")
        btn_add.clicked.connect(lambda: self.add_record(table, fields))
        btn_edit = QPushButton("✏️ Изменить")
        btn_edit.clicked.connect(lambda: self.edit_record(table, columns, fields))
        btn_del = QPushButton("🗑️ Удалить")
        btn_del.clicked.connect(lambda: self.delete_record(table, columns))

        for b in (btn_refresh, btn_add, btn_edit, btn_del):
            h.addWidget(b)
        v.addLayout(h)

        self.tabs.addTab(w, title)
        QTimer.singleShot(100, lambda: self.load_table(table, columns))

    def load_table(self, table, columns):
        tw = getattr(self, f"tw_{table}")
        tw.setRowCount(0)
        try:
            rows = DB.query(f"SELECT {','.join(columns)} FROM {table}")
            tw.setRowCount(len(rows))
            for i, row in enumerate(rows):
                for j, val in enumerate(row):
                    tw.setItem(i, j, QTableWidgetItem(str(val) if val is not None else ""))
            self.status.showMessage(f"{table}: загружено {len(rows)} записей")
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    def add_record(self, table, fields):
        dlg = RecordDialog(f"Добавить {table}", fields)
        if dlg.exec() != QDialog.Accepted:
            return
        data = dlg.get_data()
        cols = ", ".join(data.keys())
        ph = ", ".join([f":{k}" for k in data.keys()])
        try:
            DB.execute(f"INSERT INTO {table} ({cols}) VALUES ({ph})", data)
            self.load_table(table, [c for c, _ in fields] + ["id"])
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    def edit_record(self, table, columns, fields):
        tw = getattr(self, f"tw_{table}")
        row = tw.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Внимание", "Выберите запись")
            return
        pk = tw.item(row, 0).text()
        current = {col: tw.item(row, i).text() for i, col in enumerate(columns)}
        dlg = RecordDialog(f"Изменить {table}", fields, current)
        if dlg.exec() != QDialog.Accepted:
            return
        data = dlg.get_data()
        sets = ", ".join([f"{k} = :{k}" for k in data.keys()])
        data["id"] = pk
        try:
            DB.execute(f"UPDATE {table} SET {sets} WHERE id = :id", data)
            self.load_table(table, columns)
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    def delete_record(self, table, columns):
        tw = getattr(self, f"tw_{table}")
        row = tw.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Внимание", "Выберите запись")
            return
        pk = tw.item(row, 0).text()
        if QMessageBox.question(self, "Подтверждение", f"Удалить запись {pk}?") == QMessageBox.Yes:
            try:
                DB.execute(f"DELETE FROM {table} WHERE id = :id", {"id": pk})
                self.load_table(table, columns)
            except Exception as e:
                QMessageBox.critical(self, "Ошибка", str(e))

    # -----------------------------------------------------------------
    # Orders (отдельно из-за DateEdit и ComboBox)
    # -----------------------------------------------------------------
    def build_orders_tab(self):
        w = QWidget()
        v = QVBoxLayout(w)

        self.tw_orders = QTableWidget()
        self.tw_orders.setColumnCount(3)
        self.tw_orders.setHorizontalHeaderLabels(["id", "supplier_id", "order_date"])
        self.tw_orders.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.tw_orders.setSelectionBehavior(QTableWidget.SelectRows)
        v.addWidget(self.tw_orders)

        h = QHBoxLayout()
        btn_refresh = QPushButton("🔄 Обновить")
        btn_refresh.clicked.connect(self.load_orders)
        btn_add = QPushButton("➕ Добавить")
        btn_add.clicked.connect(self.add_order)
        btn_edit = QPushButton("✏️ Изменить")
        btn_edit.clicked.connect(self.edit_order)
        btn_del = QPushButton("🗑️ Удалить")
        btn_del.clicked.connect(self.delete_order)
        for b in (btn_refresh, btn_add, btn_edit, btn_del):
            h.addWidget(b)
        v.addLayout(h)

        self.tabs.addTab(w, "Purchase Orders")
        QTimer.singleShot(150, self.load_orders)

    def load_orders(self):
        self.tw_orders.setRowCount(0)
        try:
            rows = DB.query("SELECT id, supplier_id, order_date FROM purchase_orders")
            self.tw_orders.setRowCount(len(rows))
            for i, (oid, sid, odate) in enumerate(rows):
                self.tw_orders.setItem(i, 0, QTableWidgetItem(str(oid)))
                self.tw_orders.setItem(i, 1, QTableWidgetItem(str(sid)))
                self.tw_orders.setItem(i, 2, QTableWidgetItem(str(odate) if odate else ""))
            self.status.showMessage(f"purchase_orders: загружено {len(rows)} записей")
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    def _supplier_combo(self):
        cb = QComboBox()
        self.supplier_map = {}
        for sid, sname in DB.query("SELECT id, name FROM suppliers"):
            txt = f"{sid} — {sname}"
            cb.addItem(txt)
            self.supplier_map[txt] = sid
        return cb

    def add_order(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("Добавить заказ")
        dlg.setFixedSize(350, 200)
        f = QFormLayout(dlg)
        cb = self._supplier_combo()
        de = QDateEdit(QDate.currentDate())
        de.setCalendarPopup(True)
        f.addRow("Поставщик:", cb)
        f.addRow("Дата:", de)
        btn = QPushButton("Сохранить")
        btn.clicked.connect(dlg.accept)
        f.addRow(btn)
        if dlg.exec() != QDialog.Accepted:
            return
        try:
            DB.execute("INSERT INTO purchase_orders (supplier_id, order_date) VALUES (:sid, :od)",
                       {"sid": self.supplier_map[cb.currentText()], "od": de.date().toPython()})
            self.load_orders()
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    def edit_order(self):
        row = self.tw_orders.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Внимание", "Выберите запись")
            return
        pk = self.tw_orders.item(row, 0).text()
        dlg = QDialog(self)
        dlg.setWindowTitle("Изменить заказ")
        dlg.setFixedSize(350, 200)
        f = QFormLayout(dlg)
        cb = self._supplier_combo()
        de = QDateEdit()
        de.setCalendarPopup(True)
        # установить текущие значения
        cur_sid = self.tw_orders.item(row, 1).text()
        cur_date = self.tw_orders.item(row, 2).text()
        for i in range(cb.count()):
            if cb.itemText(i).startswith(cur_sid + " "):
                cb.setCurrentIndex(i)
                break
        de.setDate(QDate.fromString(cur_date, "yyyy-MM-dd"))
        f.addRow("Поставщик:", cb)
        f.addRow("Дата:", de)
        btn = QPushButton("Сохранить")
        btn.clicked.connect(dlg.accept)
        f.addRow(btn)
        if dlg.exec() != QDialog.Accepted:
            return
        try:
            DB.execute("UPDATE purchase_orders SET supplier_id = :sid, order_date = :od WHERE id = :id",
                       {"sid": self.supplier_map[cb.currentText()],
                        "od": de.date().toPython(),
                        "id": pk})
            self.load_orders()
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    def delete_order(self):
        row = self.tw_orders.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Внимание", "Выберите запись")
            return
        pk = self.tw_orders.item(row, 0).text()
        if QMessageBox.question(self, "Подтверждение", f"Удалить заказ {pk}?") == QMessageBox.Yes:
            try:
                DB.execute("DELETE FROM purchase_orders WHERE id = :id", {"id": pk})
                self.load_orders()
            except Exception as e:
                QMessageBox.critical(self, "Ошибка", str(e))

    # -----------------------------------------------------------------
    # Журнал операций
    # -----------------------------------------------------------------
    def build_log_tab(self):
        w = QWidget()
        v = QVBoxLayout(w)

        filt = QGroupBox("Фильтры")
        fh = QHBoxLayout(filt)
        self.log_type = QComboBox()
        self.log_type.addItems(["Все", "INSERT", "UPDATE", "DELETE"])
        self.log_from = QLineEdit("2025-01-01")
        self.log_to = QLineEdit("2026-12-31")
        fh.addWidget(QLabel("Тип:"))
        fh.addWidget(self.log_type)
        fh.addWidget(QLabel("С:"))
        fh.addWidget(self.log_from)
        fh.addWidget(QLabel("По:"))
        fh.addWidget(self.log_to)
        btn_load = QPushButton("Показать")
        btn_load.clicked.connect(self.load_log)
        btn_undo = QPushButton("↩️ Отменить выбранное")
        btn_undo.clicked.connect(self.undo_selected)
        fh.addWidget(btn_load)
        fh.addWidget(btn_undo)
        fh.addStretch()
        v.addWidget(filt)

        self.tw_log = QTableWidget()
        self.tw_log.setColumnCount(8)
        self.tw_log.setHorizontalHeaderLabels(
            ["log_id", "table_name", "op_type", "date", "record_pk", "old_data", "new_data", "undone"]
        )
        self.tw_log.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.tw_log.setSelectionBehavior(QTableWidget.SelectRows)
        self.tw_log.doubleClicked.connect(self.log_double_click)
        v.addWidget(self.tw_log)

        # цветовые теги
        self.tw_log.tag_colors = {
            "INSERT": QColor("#d4edda"),
            "UPDATE": QColor("#fff3cd"),
            "DELETE": QColor("#f8d7da")
        }

        self.tabs.addTab(w, "Журнал операций")

    def load_log(self):
        self.tw_log.setRowCount(0)
        try:
            op = None if self.log_type.currentText() == "Все" else self.log_type.currentText()
            sql = """SELECT log_id, table_name, operation_type, operation_date, record_pk,
                            old_data, new_data, is_undone
                     FROM operation_log
                     WHERE (:op IS NULL OR operation_type = :op)
                       AND operation_date BETWEEN TO_TIMESTAMP(:d1, 'YYYY-MM-DD')
                                              AND TO_TIMESTAMP(:d2 || ' 23:59:59', 'YYYY-MM-DD HH24:MI:SS')
                     ORDER BY log_id DESC"""
            rows = DB.query(sql, {"op": op, "d1": self.log_from.text(), "d2": self.log_to.text()})
            self.tw_log.setRowCount(len(rows))
            for i, (lid, tn, ot, od, pk, old_d, new_d, und) in enumerate(rows):
                vals = [lid, tn, ot, str(od) if od else "", pk,
                        str(old_d)[:60] + "..." if old_d and len(str(old_d)) > 60 else str(old_d or ""),
                        str(new_d)[:60] + "..." if new_d and len(str(new_d)) > 60 else str(new_d or ""),
                        und]
                for j, val in enumerate(vals):
                    item = QTableWidgetItem(str(val))
                    if ot in self.tw_log.tag_colors:
                        item.setBackground(QBrush(self.tw_log.tag_colors[ot]))
                    self.tw_log.setItem(i, j, item)
            self.status.showMessage(f"Журнал: найдено {len(rows)} записей")
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    def undo_selected(self):
        row = self.tw_log.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Внимание", "Выберите запись")
            return
        lid = self.tw_log.item(row, 0).text()
        if QMessageBox.question(self, "Подтверждение", f"Отменить операцию {lid}?") == QMessageBox.Yes:
            try:
                DB.execute("BEGIN pkg_log_manager.undo_operation(:id); END;", {"id": lid})
                self.load_log()
                self.refresh_all_tables()
                QMessageBox.information(self, "Успех", "Операция отменена")
            except Exception as e:
                QMessageBox.critical(self, "Ошибка", str(e))

    def log_double_click(self):
        row = self.tw_log.currentRow()
        if row < 0:
            return
        lid = self.tw_log.item(row, 0).text()
        tn = self.tw_log.item(row, 1).text()
        ot = self.tw_log.item(row, 2).text()
        try:
            old_d, new_d = DB.query("SELECT old_data, new_data FROM operation_log WHERE log_id = :id", {"id": lid})[0]
            LogDetailDialog(int(lid), tn, ot, old_d, new_d, self).exec()
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    # -----------------------------------------------------------------
    # Отчёт
    # -----------------------------------------------------------------
    def build_report_tab(self):
        w = QWidget()
        v = QVBoxLayout(w)

        opts = QGroupBox("Параметры сортировки")
        oh = QHBoxLayout(opts)
        self.chk_r1 = QCheckBox("По таблице (флаг 1)")
        self.chk_r2 = QCheckBox("По типу операции (флаг 2)")
        self.chk_r3 = QCheckBox("По количеству (флаг 3)")
        btn = QPushButton("Сформировать отчёт")
        btn.clicked.connect(self.load_report)
        oh.addWidget(self.chk_r1)
        oh.addWidget(self.chk_r2)
        oh.addWidget(self.chk_r3)
        oh.addWidget(btn)
        oh.addStretch()
        v.addWidget(opts)

        self.tw_rep = QTableWidget()
        self.tw_rep.setColumnCount(3)
        self.tw_rep.setHorizontalHeaderLabels(["Таблица", "Тип операции", "Количество"])
        self.tw_rep.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        v.addWidget(self.tw_rep)
        self.tabs.addTab(w, "Отчёт")

    def load_report(self):
        self.tw_rep.setRowCount(0)
        try:
            parts = []
            if self.chk_r1.isChecked():
                parts.append("table_name")
            if self.chk_r2.isChecked():
                parts.append("operation_type")
            if self.chk_r3.isChecked():
                parts.append("op_count")
            order = "ORDER BY " + ", ".join(parts) if parts else ""
            sql = f"SELECT table_name, operation_type, COUNT(*) AS op_count FROM operation_log GROUP BY table_name, operation_type {order}"
            rows = DB.query(sql)
            self.tw_rep.setRowCount(len(rows))
            for i, (tn, ot, cnt) in enumerate(rows):
                for j, val in enumerate((tn, ot, str(cnt))):
                    self.tw_rep.setItem(i, j, QTableWidgetItem(val))
            self.status.showMessage(f"Отчёт: сформировано {len(rows)} строк")
        except Exception as e:
            QMessageBox.critical(self, "Ошибка", str(e))

    # -----------------------------------------------------------------
    # Служебные
    # -----------------------------------------------------------------
    def show_connect(self):
        if DB.conn is None:
            dlg = ConnectDialog(self)
            if dlg.exec() == QDialog.Accepted:
                self.status.showMessage("Подключено")
                self.refresh_all_tables()
                self.load_log()

    def refresh_all_tables(self):
        self.load_table("suppliers", ["id", "name", "category", "contact_info", "has_guarantee", "contract_id"])
        self.load_table("products", ["id", "name", "article"])
        self.load_orders()

    def closeEvent(self, event):
        if DB.conn:
            DB.conn.close()
        event.accept()


# =====================================================================
# Точка входа
# =====================================================================
if __name__ == "__main__":
    if not QT_AVAILABLE:
        print("Ошибка: PySide6 не установлен. Установите: pip install pyside6")
        sys.exit(1)
    if not ORACLE_AVAILABLE:
        print("Ошибка: oracledb не установлен. Установите: pip install oracledb")
        sys.exit(1)

    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    win = MainWindow()
    win.show()
    sys.exit(app.exec())
