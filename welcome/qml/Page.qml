import QtQuick
import QtQuick.Controls.Basic as B
import QtQuick.Layouts

// A scrolling page: its children stack in a column under the page title (Main.qml).
B.ScrollView {
    id: page
    default property alias pageContent: col.data
    contentWidth: availableWidth
    // Room at the bottom, so the last card is not flush with the window's edge.
    bottomPadding: 24
    clip: true
    B.ScrollBar.horizontal.policy: B.ScrollBar.AlwaysOff
    B.ScrollBar.vertical: B.ScrollBar {
        parent: page
        x: page.width - width - 2
        height: page.availableHeight
        policy: B.ScrollBar.AsNeeded
        contentItem: Rectangle { implicitWidth: 6; radius: 3; color: backend.theme.line }
    }
    ColumnLayout {
        id: col
        x: 32
        width: page.availableWidth - 64
        spacing: 16
    }
}
