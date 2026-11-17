// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
import QtQuick
import Quickshell.Networking

Glyph {
    readonly property var dev: Networking.devices.values.find(d => d.connected) ?? null
    anchors.verticalCenter: parent.verticalCenter
    name: !dev ? "wifiOff" : dev.type === DeviceType.Wifi ? "wifi" : "wired"
    color: dev ? Theme.fg : Theme.soft
}
