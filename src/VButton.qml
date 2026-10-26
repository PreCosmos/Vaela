// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls

// Vaela's button: filled accent, selected (for segmented controls), plain or flat.
AbstractButton {
    id: control
    property string iconName: ""
    property bool accent: false
    property bool active: false
    property bool flat: false
    property int iconSize: 16
    readonly property color foreground: !enabled ? Theme.faint : accent ? "white" : active ? Theme.accent : Theme.text
    hoverEnabled: true
    implicitHeight: 34
    implicitWidth: Math.max(implicitHeight, content.implicitWidth + (text ? 24 : 0))
    font.pixelSize: 13
    background: Rectangle {
        radius: Theme.radiusSmall
        color: control.accent ? (control.down ? Qt.darker(Theme.accent, 1.15) : control.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
             : control.active ? Theme.accentSoft
             : control.down ? Qt.lighter(Theme.surfacePressed, 1.15)
             : control.hovered ? Theme.surfacePressed
             : control.flat ? "transparent" : Theme.surfaceHover
        border.width: control.active ? 1 : 0
        border.color: Theme.accent
        opacity: control.enabled ? 1 : 0.6
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight
        Row {
            id: content
            anchors.centerIn: parent
            spacing: 8
            Image {
                visible: control.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: control.iconSize; height: control.iconSize
                sourceSize: Qt.size(control.iconSize, control.iconSize)
                source: control.iconName ? Theme.icon(control.iconName, control.foreground) : ""
            }
            Text {
                visible: control.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: control.text
                color: control.foreground
                font: control.font
            }
        }
    }
    ToolTip.visible: hovered && ToolTip.text !== ""
    ToolTip.delay: 500
}
