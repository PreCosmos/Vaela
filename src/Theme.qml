// SPDX-License-Identifier: GPL-2.0-or-later
pragma Singleton
import QtQuick

// One palette for every Vaela surface: dark glass panels with a warm coral accent.
QtObject {
    readonly property color panel: Qt.rgba(0.110, 0.114, 0.137, 0.97)
    readonly property color surface: "#25262e"
    readonly property color surfaceHover: "#2f3039"
    readonly property color surfacePressed: "#3a3b46"
    readonly property color border: "#34353f"
    readonly property color text: "#ecedf2"
    readonly property color muted: "#9b9daa"
    readonly property color faint: "#6e707d"
    readonly property color accent: "#ef6a4f"
    readonly property color accentSoft: Qt.rgba(0.937, 0.416, 0.310, 0.18)
    readonly property color danger: "#ff8a7a"

    readonly property int radiusLarge: 18
    readonly property int radius: 12
    readonly property int radiusSmall: 8
    readonly property int fast: 120
    readonly property int normal: 200

    // Monochrome theme icon drawn in one colour, for the shell's own controls.
    function icon(name, color) { return "image://menuicons/" + encodeURIComponent("tint/" + String(color).slice(0, 7) + "/" + name) }
    // Full-colour application icon or image path.
    function appIcon(name) { return "image://menuicons/" + encodeURIComponent(name) }
}
