// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

// A soft drop shadow made of fading outlines, so it also draws without GPU shaders.
Item {
    property real radius: Theme.radius
    Repeater {
        model: 6
        Rectangle {
            required property int index
            anchors.fill: parent
            anchors.margins: -(index + 1)
            anchors.topMargin: -(index + 1) + 2
            radius: parent.radius + index + 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.16 - index * 0.025)
        }
    }
}
