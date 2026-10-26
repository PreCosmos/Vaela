// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Plasma's "Configure Desktop and Wallpaper" page for the Vaela wallpaper. Per-workspace
// backgrounds are chosen in Vaela Settings; this sets the picture for the other workspaces.
Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout
    property alias formLayout: root
    property string cfg_Fallback

    QQC2.Label {
        Kirigami.FormData.label: "Workspace backgrounds:"
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        text: "Choose a video or picture for each workspace in Vaela Settings (Meta+Ctrl+S)."
        wrapMode: Text.WordWrap
    }
    RowLayout {
        Kirigami.FormData.label: "Other workspaces:"
        QQC2.Label {
            text: root.cfg_Fallback ? decodeURIComponent(root.cfg_Fallback.replace(/\/$/, "").split("/").pop()) : "Plasma's default wallpaper"
            elide: Text.ElideMiddle
            Layout.maximumWidth: Kirigami.Units.gridUnit * 14
        }
        QQC2.Button {text: "Choose…"; icon.name: "document-open"; onClicked: picker.open()}
        QQC2.Button {text: "Default"; icon.name: "edit-undo"; visible: root.cfg_Fallback !== ""; onClicked: root.cfg_Fallback = ""}
    }
    FileDialog {
        id: picker
        title: "Picture for workspaces without a background"
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp *.avif *.jxl *.bmp *.svg *.svgz)", "All files (*)"]
        onAccepted: root.cfg_Fallback = selectedFile.toString()
    }
}
