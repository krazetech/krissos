"""Run: QT_QPA_PLATFORM=offscreen python welcome/smoke_qml.py (needs PySide6 and Kirigami).
Opens every page and fails on any QML warning from our own files."""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import Q_ARG, QCoreApplication, QMetaObject, qInstallMessageHandler  # noqa: E402

import kriss_welcome  # noqa: E402

bad = []


def on_message(_type, _context, msg):
    print(msg, file=sys.stderr)
    if "/qml/" in msg:
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
for i in range(5):  # the pages in Main.qml
    QMetaObject.invokeMethod(root, "showPage", Q_ARG("QVariant", i))
    for _ in range(20):
        QCoreApplication.processEvents()
assert not bad, "\n".join(bad)
print("qml ok")
