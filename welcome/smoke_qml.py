"""Run: QT_QPA_PLATFORM=offscreen python welcome/smoke_qml.py (needs PySide6 and Kirigami).
Opens every page and fails on any QML warning from our own files."""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import Q_ARG, QCoreApplication, QMetaObject, qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (so the root window converts)

import kriss_welcome  # noqa: E402

bad = []


def on_message(_type, _context, msg):
    print(msg, file=sys.stderr)
    # Kirigami says this for every page pushed as a Component; it is harmless.
    if "/qml/" in msg and "not placed in the graphics scene" not in msg:
        bad.append(msg)


qInstallMessageHandler(on_message)
app = kriss_welcome.QGuiApplication(sys.argv)
engine = kriss_welcome.QQmlApplicationEngine()
backend = kriss_welcome.Backend(app, engine)
engine.rootContext().setContextProperty("backend", backend)
engine.rootContext().setContextProperty("logo", "")
engine.load(str(kriss_welcome.HERE / "qml/Main.qml"))
assert engine.rootObjects(), "Main.qml did not load"
root = engine.rootObjects()[0]
shots = os.environ.get("SMOKE_SHOTS")  # a folder: save a screenshot of each page there
for i in range(5):  # the pages in Main.qml
    QMetaObject.invokeMethod(root, "showPage", Q_ARG("QVariant", i))
    for _ in range(20):
        QCoreApplication.processEvents()
    if shots:
        root.grabWindow().save(f"{shots}/page{i}.png")
print("\n".join(bad) or "qml ok")
sys.stdout.flush()
os._exit(1 if bad else 0)  # skip teardown, where bindings see a null backend
