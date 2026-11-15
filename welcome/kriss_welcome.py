#!/usr/bin/env python3
"""kriss-welcome: the KrissOS first-boot app. Holds no root logic: hardware facts come from
`kriss hwcheck`, and Flatpak installs go through `flatpak`, which asks polkit itself.
Colours come from the KDE colour scheme; the Sky Cyan accent is set system-wide there."""
import json
import pathlib
import sys

from PySide6.QtCore import QLocale, QObject, QProcess, QTranslator, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

import logic

HERE = pathlib.Path(__file__).resolve().parent
LOGO = "/usr/share/pixmaps/krissos.svg"  # from kriss-theme
AUTOSTART = pathlib.Path.home() / ".config/autostart/kriss-welcome.desktop"


def disable_autostart():
    """A Hidden=true copy in the user's autostart dir masks the system-wide entry (XDG spec)."""
    AUTOSTART.parent.mkdir(parents=True, exist_ok=True)
    AUTOSTART.write_text("[Desktop Entry]\nType=Application\nName=KrissOS Welcome\nHidden=true\n")


class Backend(QObject):
    installDone = Signal(str, bool)
    languageChanged = Signal()

    def __init__(self, app, engine):
        super().__init__()
        self._app, self._engine = app, engine
        self._translator = QTranslator()
        self._lang = "en"
        self._hw = logic.read_hwcheck()
        self._games = json.loads((HERE / "data/games.json").read_text())
        self._apps = json.loads((HERE / "data/apps.json").read_text())
        self._procs = {}

    @Property("QVariantMap", constant=True)
    def hw(self):
        return self._hw

    @Property("QVariantList", constant=True)
    def apps(self):
        return self._apps

    @Property(str, notify=languageChanged)
    def language(self):
        return self._lang

    @Slot(str)
    def setLanguage(self, lang):
        self._app.removeTranslator(self._translator)
        if lang != "en" and self._translator.load(str(HERE / f"i18n/kriss-welcome_{lang}.qm")):
            self._app.installTranslator(self._translator)
        else:
            lang = "en"
        self._lang = lang
        self._engine.retranslate()
        self.languageChanged.emit()

    @Slot(str, result="QVariantList")
    def searchGames(self, query):
        return logic.search_games(self._games, query)

    @Slot("QVariantMap", result="QVariantMap")
    def answer(self, app):
        return logic.answer(app, self._hw["winboat_ok"])

    @Slot(str)
    def install(self, flatpak_id):
        if flatpak_id in self._procs:
            return
        p = QProcess(self)
        p.finished.connect(lambda code, status: self._finished(flatpak_id, code == 0 and status == QProcess.NormalExit))
        p.errorOccurred.connect(lambda err: err == QProcess.FailedToStart and self._finished(flatpak_id, False))
        self._procs[flatpak_id] = p
        p.start("flatpak", ["install", "--noninteractive", "flathub", flatpak_id])

    def _finished(self, flatpak_id, ok):
        self._procs.pop(flatpak_id).deleteLater()
        self.installDone.emit(flatpak_id, ok)


def main():
    if "--autostart" in sys.argv:
        disable_autostart()
    app = QGuiApplication(sys.argv)
    app.setApplicationName("kriss-welcome")
    app.setDesktopFileName("org.krissos.Welcome")
    app.setWindowIcon(QIcon(LOGO))
    engine = QQmlApplicationEngine()
    backend = Backend(app, engine)
    backend.setLanguage("ms" if QLocale.system().name().startswith("ms") else "en")
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("logo", "file://" + LOGO)
    engine.load(str(HERE / "qml/Main.qml"))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
