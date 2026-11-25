# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
"""Run: QT_QPA_PLATFORM=offscreen python welcome/smoke_qml.py (needs PySide6).
Opens every page and fails on any QML warning from our own files."""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import Q_ARG, QCoreApplication, QMetaObject, qInstallMessageHandler  # noqa: E402
from PySide6.QtQml import QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (so the root window converts)

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
shots = os.environ.get("SMOKE_SHOTS")  # a folder: save a screenshot of each page there


def show(i):
    QMetaObject.invokeMethod(root, "showPage", Q_ARG("QVariant", i))
    for _ in range(20):
        QCoreApplication.processEvents()


for i in range(5):  # the pages in Main.qml
    show(i)
    if shots:
        root.grabWindow().save(f"{shots}/page{i}.png")
# The Local AI model list, as shown once Ollama is installed.
e = QQmlExpression(engine.contextForObject(root), root, 'root.currentItem.installs = { ollama: "installed" };'
                   ' root.currentItem.pulls = { "llama3.2:3b": "pulled" }')
e.evaluate()
assert not e.hasError(), e.error().toString()
for _ in range(20):
    QCoreApplication.processEvents()
if shots:
    root.grabWindow().save(f"{shots}/ai-models.png")
# The Install dialog's text calls backend. It used to fail once you switched pages or
# closed the app with an install picked.
QQmlExpression(engine.contextForObject(root), root,
               'root.currentItem.pending = { id: "codecs", name: "Codecs" }').evaluate()
show(0)
show(4)
del root
engine.deleteLater()
for _ in range(20):
    QCoreApplication.processEvents()
print("\n".join(bad) or "qml ok")
sys.exit(1 if bad else 0)
