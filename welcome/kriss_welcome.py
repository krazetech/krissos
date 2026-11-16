#!/usr/bin/env python3
"""kriss-welcome: the KrissOS first-boot app. Holds no root logic: hardware facts come from
`kriss hwcheck`, Flatpak installs go through `flatpak` and the Windows partition is mounted
read-only through `udisksctl` (both ask polkit themselves), and package installs go through
`pkexec` with the fixed commands in logic.EXTRAS.
Colours come from the KDE colour scheme; the Sky Cyan accent is set system-wide there."""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import threading

from PySide6.QtCore import QLocale, QObject, QProcess, QTranslator, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtNetwork import QNetworkInformation
from PySide6.QtQml import QQmlApplicationEngine

import logic

HERE = pathlib.Path(__file__).resolve().parent
LOGO = "/usr/share/pixmaps/krissos.svg"  # from kriss-theme
AUTOSTART = pathlib.Path.home() / ".config/autostart/kriss-welcome.desktop"


def disable_autostart():
    """A Hidden=true copy in the user's autostart dir masks the system-wide entry (XDG spec)."""
    AUTOSTART.parent.mkdir(parents=True, exist_ok=True)
    AUTOSTART.write_text("[Desktop Entry]\nType=Application\nName=KrissOS Welcome\nHidden=true\n")


def user_dir(name):
    """The home folder for an xdg-user-dir name such as DOCUMENTS (it may be translated)."""
    try:
        out = subprocess.run(["xdg-user-dir", name], capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        out = ""
    home = pathlib.Path.home()
    return out if out and out != str(home) else str(home / name.capitalize())


class Backend(QObject):
    installDone = Signal(str, bool)
    languageChanged = Signal()
    onlineChanged = Signal()
    windowsMounted = Signal(str, str)  # mount point, or "" and the error
    copyProgress = Signal(float, float, str)  # bytes done, bytes total, file name
    copyDone = Signal(int, int, "QStringList")  # files copied, files failed, bookmark files written

    def __init__(self, app, engine):
        # A child of the engine, so it outlives the QML that calls it: the engine deletes
        # its windows before its children.
        super().__init__(engine)
        self._app, self._engine = app, engine
        self._translator = QTranslator()
        self._lang = "en"
        self._hw = logic.read_hwcheck()
        self._games = json.loads((HERE / "data/games.json").read_text())
        self._apps = json.loads((HERE / "data/apps.json").read_text())
        self._procs = {}
        self._mounted = ""  # the Windows partition this app mounted, unmounted after copying
        # NetworkManager's view of the internet, so the extras page can say "needs internet"
        # instead of failing. Qt picks the backend; with none, assume online.
        self._net = QNetworkInformation.instance() if QNetworkInformation.loadDefaultBackend() else None
        if self._net:
            self._net.reachabilityChanged.connect(lambda _r: self.onlineChanged.emit())

    @Property("QVariantMap", constant=True)
    def hw(self):
        return self._hw

    @Property(bool, notify=onlineChanged)
    def online(self):
        r = QNetworkInformation.Reachability
        return not self._net or self._net.reachability() in (r.Online, r.Unknown)

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

    def _run(self, key, argv, done=None):
        """Run argv once per key; done(ok, output) or installDone(key, ok) when it ends."""
        if key in self._procs:
            return
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.MergedChannels)

        def finish(ok):
            self._procs.pop(key).deleteLater()
            out = bytes(p.readAll()).decode(errors="replace").strip()
            done(ok, out) if done else self.installDone.emit(key, ok)

        p.finished.connect(lambda code, status: finish(code == 0 and status == QProcess.NormalExit))
        p.errorOccurred.connect(lambda err: err == QProcess.FailedToStart and finish(False))
        self._procs[key] = p
        p.start(argv[0], argv[1:])

    @Slot(str)
    def install(self, flatpak_id):
        self._run(flatpak_id, ["flatpak", "install", "--noninteractive", "flathub", flatpak_id])

    # Drivers and extras
    @Slot(str, result=str)
    def extraCommand(self, extra_id):
        return " ".join(logic.extra_command(extra_id, self._hw["gpus"]))

    @Slot(str, result=bool)
    def extraInstalled(self, extra_id):
        return logic.extra_installed(extra_id, self._hw["gpus"])

    @Slot(str)
    def installExtra(self, extra_id):
        self._run(extra_id, logic.extra_command(extra_id, self._hw["gpus"]))

    # Copy from Windows
    @Slot(result="QVariantList")
    def windowsPartitions(self):
        try:
            out = subprocess.run(["lsblk", "-J", "-b", "-o", "PATH,FSTYPE,LABEL,SIZE,MOUNTPOINT,PARTTYPE"],
                                 capture_output=True, text=True, timeout=10).stdout
        except (OSError, subprocess.SubprocessError):
            return []
        return logic.windows_partitions(out)

    @Slot(str, str)
    def mountWindows(self, device, mountpoint):
        """Mount the partition read-only (or use it where it is already mounted)."""
        if mountpoint:
            return self.windowsMounted.emit(mountpoint, "")

        def done(ok, out):
            # udisksctl says "Mounted /dev/sda3 at /run/media/me/OS"
            where = out.rsplit(" at ", 1)[-1].rstrip(".") if ok else ""
            try:
                read_only = bool(os.statvfs(where).f_flag & os.ST_RDONLY)
            except OSError:
                read_only = False
            if where and not read_only:
                # Never keep Windows writable, even if udisks ignored "ro".
                subprocess.run(["udisksctl", "unmount", "-b", device], capture_output=True)
                ok, out, where = False, "not read-only", ""
            if where:
                self._mounted = device
            self.windowsMounted.emit(where, "" if where else out)

        self._run("mount", ["udisksctl", "mount", "-b", device, "-o", "ro"], done)

    @Slot(str, result="QStringList")
    def windowsUsers(self, root):
        return logic.windows_users(root)

    @Slot(str, str, "QStringList", bool, str)
    def copyFromWindows(self, root, user, folders, bookmarks, bookmark_name):
        """Copy in a thread; folders are FOLDERS names, bookmark_name has %1 for the browser."""
        src = pathlib.Path(root) / "Users" / user
        pairs = logic.plan_copy(src, {f: user_dir(f.upper()) for f in folders if f in logic.FOLDERS})

        def work():
            try:
                copy()
            except Exception as e:  # never leave the page spinning
                print("kriss-welcome: copy stopped:", e, file=sys.stderr)
                self.copyDone.emit(0, -2, [])  # -2: stopped by an error
            finally:
                self._unmount()

        def copy():
            items = logic.files_to_copy(pairs)
            total = sum(size for _s, _d, size in items)
            failed = 0
            if total > shutil.disk_usage(pathlib.Path.home()).free:
                return self.copyDone.emit(0, -1, [])  # -1: not enough space
            for done, name, ok in logic.copy_files(items):
                failed += not ok
                self.copyProgress.emit(done, total, name)
            written = []
            for browser, rel in logic.BROWSERS.items() if bookmarks else ():
                try:
                    page = logic.bookmarks_html((src / rel).read_text(encoding="utf-8"))
                except OSError:
                    continue
                dest = pathlib.Path(user_dir("DOCUMENTS")) / bookmark_name.replace("%1", browser)
                if page and not dest.exists():
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_text(page, encoding="utf-8")
                    written.append(str(dest))
            self.copyDone.emit(len(items) - failed, failed, written)

        threading.Thread(target=work, daemon=True).start()

    def _unmount(self):
        if self._mounted:
            subprocess.run(["udisksctl", "unmount", "-b", self._mounted], capture_output=True)
            self._mounted = ""


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
