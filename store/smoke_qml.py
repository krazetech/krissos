"""Run: QT_QPA_PLATFORM=offscreen python store/smoke_qml.py (needs PySide6 and Kirigami).
Opens every section, a search and an app page against the test catalogue, and fails on any
QML warning from our own files. Nothing is installed: flatpak and pacman are not called."""
import os
import pathlib
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
t = tempfile.mkdtemp()
os.environ["KRISS_STORE_FLATPAK"] = t
os.environ["XDG_CACHE_HOME"] = t + "/cache"
sys.argv = [sys.argv[0]]

import test_store  # noqa: E402  (its fixture catalogue)
from PySide6.QtCore import Q_ARG, QCoreApplication, QMetaObject, qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (so the root window converts)

import kriss_store  # noqa: E402

test_store.flatpak_root(t)
bad = []


def on_message(_type, _context, msg):
    print(msg, file=sys.stderr)
    if "/qml/" in msg:
        bad.append(msg)


def spin(n=40):
    for _ in range(n):
        QCoreApplication.processEvents()


qInstallMessageHandler(on_message)
app = kriss_store.QGuiApplication(sys.argv)
engine = kriss_store.QQmlApplicationEngine()
backend = kriss_store.Backend(engine)
engine.rootContext().setContextProperty("backend", backend)
engine.rootContext().setContextProperty("startApp", "com.spotify.Client")
engine.load(str(kriss_store.HERE / "qml/Main.qml"))
assert engine.rootObjects(), "Main.qml did not load"
root = engine.rootObjects()[0]
shots = os.environ.get("SMOKE_SHOTS")  # a folder: save a screenshot of each page there
import time  # noqa: E402
for _ in range(50):  # the catalogue loads in a thread
    spin()
    if backend.ready:
        break
    time.sleep(0.05)
spin()
assert backend.ready
# Spotify installed, LibreOffice installing: Open, a spinner, and Uninstall on its page.
backend._installed = ["com.spotify.Client"]
backend._by_id["org.libreoffice.LibreOffice"]["shot"] = ""  # no network in the test
backend._busy = {"org.libreoffice.LibreOffice": "install"}
backend.stateChanged.emit()
for key in ("home", "productivity", "games", "media", "installed", "updates"):
    QMetaObject.invokeMethod(root, "show", Q_ARG("QVariant", key))
    spin()
    if shots:
        root.grabWindow().save(f"{shots}/{key}.png")
QMetaObject.invokeMethod(root, "showSearch", Q_ARG("QVariant", "office"))
spin()
QMetaObject.invokeMethod(root, "openApp", Q_ARG("QVariant", "org.libreoffice.LibreOffice"))
spin()
if shots:
    root.grabWindow().save(f"{shots}/app.png")
# Let the AppStream refresh and the update check finish before tearing down.
for _ in range(600):
    spin()
    if not backend._procs and not backend.checking:
        break
    time.sleep(0.05)
del root
engine.deleteLater()
spin()
print("\n".join(bad) or "qml ok")
sys.exit(1 if bad else 0)
