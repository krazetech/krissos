#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
"""KrissOS Store: find, install, update and remove apps. Holds no root logic: every change
runs `pkexec kriss install|remove|update`, which takes a snapper snapshot first, so a bad
install rolls back from the boot menu. The catalogue is Flathub's AppStream, which Flatpak
keeps on disk, plus the KrissOS packs (logic.PACKS).

    kriss-store                 open the Store
    kriss-store --app ID        open it on one app (Start's "Get X from the Store" rows)
    kriss-store --write-index   write the list Start searches, and quit (runs at login)"""
import json
import os
import pathlib
import subprocess
import sys
import threading

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import logic  # noqa: E402

ROOT = pathlib.Path(os.environ.get("KRISS_STORE_FLATPAK", logic.FLATPAK))
INDEX = pathlib.Path(os.environ.get("XDG_CACHE_HOME") or pathlib.Path.home() / ".cache") / "kriss/store.json"


def lang():
    v = os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
    return "ms" if v.startswith("ms") else "en"


def out(argv):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=120).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def write_index():
    logic.write_index(logic.load_catalogue(ROOT, lang()), INDEX)


if "--write-index" in sys.argv:
    write_index()
    sys.exit(0)

from PySide6.QtCore import QObject, QProcess, QTranslator, Property, Signal, Slot  # noqa: E402
from PySide6.QtGui import QGuiApplication, QIcon  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402


class Backend(QObject):
    catalogueChanged = Signal()
    stateChanged = Signal()
    updatesChanged = Signal()
    done = Signal(str, str, bool)  # id ("" for update all), install|remove|update, ok

    def __init__(self, parent):
        super().__init__(parent)
        self._apps, self._by_id = [], {}
        self._ready = False
        self._installed = []
        self._busy = {}  # id -> "install" | "remove" | "update"
        self._updates = []
        self._procs = {}
        self._checking = False
        self.reload()
        # Fresh AppStream from Flathub; no root needed. Reload if it changed.
        self._run("appstream", ["flatpak", "update", "--appstream", "flathub"],
                  lambda ok: ok and self.reload())
        self.refresh()

    def reload(self):
        def work():
            apps = logic.load_catalogue(ROOT, lang())
            self._apps, self._by_id = apps, {a["id"]: a for a in apps}
            self._ready = True
            try:
                logic.write_index(apps, INDEX)
            except OSError:
                pass
            self.catalogueChanged.emit()
        threading.Thread(target=work, daemon=True).start()

    @Slot()
    def refresh(self):
        """What is installed, then what has updates (that needs the network, so it is second)."""
        def work():
            ids = logic.parse_flatpak_ids(out(["flatpak", "list", "--app", "--columns=application"]))
            packs = [p["id"] for p in logic.PACKS]
            have = out(["pacman", "-Q", *packs])
            self._installed = ids + [p for p in packs if p + " " in have]
            self.stateChanged.emit()
            ups = [{"name": n, "version": v} for n, v in logic.parse_checkupdates(out(["checkupdates"]))]
            ups += [{"name": self._by_id.get(i, {}).get("name", i), "version": ""}
                    for i in logic.parse_flatpak_ids(out(["flatpak", "remote-ls", "--updates", "--app", "--columns=application"]))]
            self._updates, self._checking = ups, False
            self.updatesChanged.emit()
        self._checking = True
        self.updatesChanged.emit()
        threading.Thread(target=work, daemon=True).start()

    @Property(bool, notify=catalogueChanged)
    def ready(self):
        return self._ready

    @Property(int, notify=catalogueChanged)
    def flathubCount(self):
        return sum(a["kind"] == "flatpak" for a in self._apps)

    @Property("QStringList", notify=stateChanged)
    def installed(self):
        return self._installed

    @Property("QVariantMap", notify=stateChanged)
    def busy(self):
        return self._busy

    @Property("QVariantList", notify=updatesChanged)
    def updates(self):
        return self._updates

    @Property(bool, notify=updatesChanged)
    def checking(self):
        return self._checking

    @Slot(result="QVariantList")
    def featured(self):
        return logic.featured(self._apps)

    @Slot(str, result="QVariantList")
    def category(self, cat):
        return logic.in_category(self._apps, cat)

    @Slot(str, result="QVariantList")
    def search(self, query):
        return logic.search(self._apps, query)

    @Slot(result="QVariantList")
    def installedApps(self):
        return [self._by_id[i] for i in self._installed if i in self._by_id]

    @Slot(str, result="QVariantMap")
    def app(self, app_id):
        return self._by_id.get(app_id, {})

    def _run(self, key, argv, finished):
        if key in self._procs:
            return
        p = QProcess(self)

        def end(ok):
            self._procs.pop(key).deleteLater()
            finished(ok)

        p.finished.connect(lambda code, status: end(code == 0 and status == QProcess.NormalExit))
        p.errorOccurred.connect(lambda err: err == QProcess.FailedToStart and end(False))
        self._procs[key] = p
        p.start(argv[0], argv[1:])

    def _change(self, app_id, action, argv):
        if self._busy:  # one change at a time: pacman and flatpak hold a lock each
            return
        self._busy = {app_id or "*": action}
        self.stateChanged.emit()

        def finished(ok):
            self._busy = {}
            self.done.emit(app_id, action, ok)
            self.refresh()
        self._run("change", argv, finished)

    @Slot(str)
    def install(self, app_id):
        a = self._by_id.get(app_id)
        if a:
            self._change(app_id, "install", ["pkexec", "kriss", "install", "--yes",
                                             "--repo" if a["kind"] == "pacman" else "--flatpak", app_id])

    @Slot(str)
    def remove(self, app_id):
        if app_id in self._installed:
            self._change(app_id, "remove", ["pkexec", "kriss", "remove", "--yes", app_id])

    @Slot()
    def updateAll(self):
        self._change("", "update", ["pkexec", "kriss", "update"])

    @Slot(str, result=bool)
    def canOpen(self, app_id):
        return self._by_id.get(app_id, {}).get("kind") == "flatpak"

    @Slot(str)
    def open(self, app_id):
        if self.canOpen(app_id):
            QProcess.startDetached("flatpak", ["run", app_id])


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("kriss-store")
    app.setDesktopFileName("org.krissos.Store")
    app.setWindowIcon(QIcon.fromTheme("system-software-install"))
    tr = QTranslator()
    if lang() == "ms" and tr.load(str(HERE / "i18n/kriss-store_ms.qm")):
        app.installTranslator(tr)
    engine = QQmlApplicationEngine()
    backend = Backend(engine)
    engine.rootContext().setContextProperty("backend", backend)
    start = sys.argv[sys.argv.index("--app") + 1] if "--app" in sys.argv[:-1] else ""
    engine.rootContext().setContextProperty("startApp", start)
    engine.load(str(HERE / "qml/Main.qml"))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
