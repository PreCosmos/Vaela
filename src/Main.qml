// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

QtObject {
    id: root
    property var modes: ["Float", "Auto Tiling", "Scrollable"]
    readonly property var modeIcons: ({"Float": "window", "Auto Tiling": "view-grid", "Scrollable": "view-split-left-right"})
    property var commands: [
        {label:"Move column left",action:"column-left",icon:"go-previous"}, {label:"Move column right",action:"column-right",icon:"go-next"},
        {label:"Widen window / column",action:"widen",icon:"zoom-in"}, {label:"Narrow window / column",action:"narrow",icon:"zoom-out"},
        {label:"Increase row height",action:"taller",icon:"go-down"}, {label:"Decrease row height",action:"shorter",icon:"go-up"},
        {label:"Disabled",action:""},
        {label:"Send window to next workspace",action:"send-next",icon:"go-next"}, {label:"Send window to previous workspace",action:"send-previous",icon:"go-previous"},
        {label:"Quick Commands",action:"commands",icon:"search"},
        {label:"New terminal", action:"terminal",icon:"utilities-terminal"}, {label:"Files", action:"files",icon:"folder"},
        {label:"Web browser", action:"browser",icon:"globe"}, {label:"Screenshot", action:"screenshot",icon:"camera-photo"},
        {label:"Previous workspace", action:"previous",icon:"go-previous"}, {label:"Next workspace", action:"next",icon:"go-next"},
        {label:"Maximize / restore window", action:"maximize",icon:"window-maximize"}, {label:"Minimize window", action:"minimize",icon:"window-minimize"},
        {label:"Close window", action:"close",icon:"window-close"}, {label:"Cycle layout", action:"cycle-layout",icon:"view-refresh"},
        {label:"Focus next window", action:"focus-next",icon:"go-next"}, {label:"Focus previous window", action:"focus-previous",icon:"go-previous"},
        {label:"Activities", action:"activities",icon:"activities"}, {label:"Vaela Settings", action:"settings",icon:"configure"},
        {label:"System Settings", action:"system",icon:"configure"}]
    readonly property var strokes: [
        {stroke:"L",arrows:"←"}, {stroke:"R",arrows:"→"}, {stroke:"U",arrows:"↑"}, {stroke:"D",arrows:"↓"},
        {stroke:"DR",arrows:"↓ →"}, {stroke:"UD",arrows:"↑ ↓"}, {stroke:"DU",arrows:"↓ ↑"}, {stroke:"UL",arrows:"↑ ←"},
        {stroke:"UR",arrows:"↑ →"}, {stroke:"RU",arrows:"→ ↑"}, {stroke:"LU",arrows:"← ↑"}]
    readonly property var keys: [
        ["F2","Quick Commands"], ["Meta+Ctrl+S","Vaela Settings"], ["Meta+Ctrl+R","Radial menu"],
        ["Meta+Ctrl+Space","Cycle layout"], ["Meta+← / →","Focus the window to the left / right (Scrollable)"],
        ["Meta+Alt+← / →","Focus previous / next window"], ["Ctrl+Meta+← / →","Move column left / right (Scrollable)"],
        ["Meta+Plus / Minus","Widen / narrow the active column"], ["Meta+Ctrl+Alt+Arrows","Resize columns and rows"]]
    readonly property var systemPages: [
        {label:"Displays & HDR",icon:"preferences-desktop-display",page:"kcm_kscreen"}, {label:"Sound",icon:"preferences-desktop-sound",page:"kcm_pulseaudio"},
        {label:"Printers",icon:"printer",page:"kcm_printer_manager"}, {label:"Power",icon:"preferences-system-power-management",page:"kcm_powerdevilprofilesconfig"},
        {label:"Keyboard",icon:"preferences-desktop-keyboard",page:"kcm_keyboard"}, {label:"Mouse",icon:"preferences-desktop-mouse",page:"kcm_mouse"},
        {label:"Touchpad",icon:"input-touchpad",page:"kcm_touchpad"}, {label:"Shortcuts",icon:"preferences-desktop-keyboard-shortcut",page:"kcm_keys"},
        {label:"Night Light",icon:"redshift-status-on",page:"kcm_nightlight"}, {label:"Themes",icon:"preferences-desktop-theme-global",page:"kcm_lookandfeel"},
        {label:"System Info",icon:"help-about",page:"info"}, {label:"All Settings",icon:"preferences-system",page:"system"}]

    // Stock controls (sliders, switches, combo boxes, menus) take these colours from their window.
    function applyPalette(window) {
        const p=window.palette
        p.window=Theme.panel; p.windowText=Theme.text; p.base=Theme.surface; p.alternateBase=Theme.surfaceHover
        p.text=Theme.text; p.button=Theme.surfaceHover; p.buttonText=Theme.text; p.brightText=Theme.text
        p.highlight=Theme.accent; p.highlightedText="#ffffff"; p.placeholderText=Theme.faint
        p.light=Theme.surfacePressed; p.midlight=Theme.surfaceHover; p.mid=Theme.border; p.dark="#141519"; p.shadow="#000000"
        p.toolTipBase=Theme.surface; p.toolTipText=Theme.text
    }
    function run(action) {
        overlay.hide()
        if (action === "settings" || action === "commands") open(action,0,0)
        else if (action === "system") vaela.launch("system")
        else vaela.call("action",[action])
    }
    function runRadial(entry) {
        if(entry.type === "builtin") run(entry.target)
        else {overlay.hide();radial.launch(entry.id)}
    }
    // Radial item under a point in the radial window, or -1 for the hub and outside the ring.
    function radialHot(px,py) {
        let dx=px-220, dy=py-220, distance=Math.hypot(dx,dy), count=radialItems.length
        if(!count || distance<72 || distance>214) return -1
        return Math.round((Math.atan2(dx,-dy)+2*Math.PI)/(2*Math.PI/count))%count
    }
    function open(view,x,y) {
        if(view === "dismiss") {overlay.hide();return}
        // While the right button is held, the KWin plugin reports the pointer in global coordinates.
        if(view === "radial-hover" || view === "radial-release") {
            if(!overlay.visible || overlay.view !== "radial") return
            overlay.hot=radialHot(x-overlay.originX,y-overlay.originY)
            // Releasing on the hub keeps the menu open for a left click.
            if(view === "radial-release" && overlay.hot >= 0) runRadial(radialItems[overlay.hot])
            return
        }
        overlay.hide(); overlay.view=view; overlay.hot=-1; overlay.radialPage=0; search.text=""; overlay.shownAt=Date.now()
        if(view === "radial-settings") radialEditor.page="menu"
        overlay.width=view === "radial" ? 440 : view === "commands" ? 600 : 680
        overlay.height=view === "radial" ? 440 : view === "commands" ? 520 : 660
        let origin=vaela.layer(overlay,"overlay",x || Screen.width/2,y || Screen.height/2)
        overlay.originX=origin.x; overlay.originY=origin.y
        overlay.show(); overlay.requestActivate()
        if(view === "commands") search.forceActiveFocus()
    }
    property var radialItems: radial.entries.slice(overlay.radialPage*8,overlay.radialPage*8+8)
    property Connections radialEvents: Connections {
        target:radial
        function onEntriesChanged() {overlay.hot=-1;overlay.radialPage=Math.min(overlay.radialPage,Math.max(0,Math.ceil(radial.entries.length/8)-1))}
        function onLaunchFailed() {root.open("radial-settings",0,0)}
    }
    property Connections bridge: Connections {
        target: vaela
        function onRequested(view,x,y) {root.open(view,x,y)}
        function onChanged() { if(!vaela.state.mode) overlay.hide() }
    }

    // A rounded card with a title, used to group settings.
    component Card: Rectangle {
        id: card
        property string title
        property string subtitle
        default property alias content: cardBody.data
        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight + 32
        radius: Theme.radius; color: Theme.surface; border.color: Theme.border
        ColumnLayout {
            id: cardColumn
            anchors {left: parent.left; right: parent.right; top: parent.top; margins: 16}
            spacing: 12
            ColumnLayout {
                spacing: 2; Layout.fillWidth: true
                Text {text: card.title; color: Theme.text; font.pixelSize: 14; font.weight: Font.DemiBold}
                Text {visible: card.subtitle !== ""; text: card.subtitle; color: Theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true}
            }
            ColumnLayout {id: cardBody; spacing: 10; Layout.fillWidth: true}
        }
    }
    // A label on the left and a control on the right.
    component SettingRow: RowLayout {
        property alias label: rowLabel.text
        Layout.fillWidth: true; spacing: 12
        Text {id: rowLabel; color: Theme.text; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap}
    }
    // A keyboard key cap.
    component KeyCap: Rectangle {
        property alias text: capText.text
        implicitWidth: capText.implicitWidth + 16; implicitHeight: 24; radius: 6
        color: Theme.surfacePressed; border.color: Theme.border
        Text {id: capText; anchors.centerIn: parent; color: Theme.text; font.pixelSize: 12; font.family: "monospace"}
    }

    // Layout switch: a short handle on the top edge, set in from the right (see Bridge::layer) so it
    // stays clear of a maximized window's close button, until the pointer reaches it.
    property Window top: Window {
        id: topWindow
        property bool expanded:false
        width: expanded ? switchPanel.implicitWidth + 8 : 160
        height: expanded ? 38 : 6; color: "transparent"
        visible: !!vaela.state.mode
        flags: Qt.FramelessWindowHint
        Component.onCompleted: {root.applyPalette(topWindow);vaela.layer(topWindow,"top")}
        HoverHandler {
            id:topHover
            onHoveredChanged:if(hovered) {topCollapse.stop();topWindow.expanded=true} else topCollapse.restart()
        }
        Timer {id:topCollapse;interval:300;onTriggered:if(!topHover.hovered) topWindow.expanded=false}
        Rectangle {
            visible: !topWindow.expanded
            anchors {top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter}
            width: 56; height: 4; radius: 2; color: Theme.accent; opacity: 0.9
        }
        Rectangle {
            id: switchPanel
            visible: topWindow.expanded
            anchors {right: parent.right; rightMargin: 4; top: parent.top; topMargin: 4}
            implicitWidth: switchRow.implicitWidth + 8
            width: implicitWidth; height: 30; radius: 10
            color: Theme.panel; border.color: Theme.border
            RowLayout {
                id: switchRow
                anchors.centerIn: parent; spacing: 2
                Repeater {
                    model: root.modes
                    VButton {
                        required property string modelData
                        text: modelData; iconName: root.modeIcons[modelData]; flat: true; implicitHeight: 24
                        active: vaela.state.mode === modelData
                        onClicked: vaela.call("setMode",[modelData])
                    }
                }
                Rectangle {width: 1; height: 16; color: Theme.border; Layout.leftMargin: 4; Layout.rightMargin: 4}
                VButton {iconName: "search"; flat: true; implicitWidth: 28; implicitHeight: 24; Accessible.name: "Quick Commands"; onClicked: root.open("commands",0,0)}
                VButton {iconName: "configure"; flat: true; implicitWidth: 28; implicitHeight: 24; Accessible.name: "Vaela Settings"; onClicked: root.open("settings",0,0)}
            }
        }
    }

    // Workspace bar: vertical tabs that slide in when the pointer reaches the right edge.
    property Window tabs: Window {
        id: tabsWindow
        property bool expanded:false
        property int openMenus:0
        readonly property bool opened: expanded || openMenus>0 || rename.visible
        width: opened ? 276 : 10
        height: Math.min(Screen.height-120,Math.max(170,(vaela.state.desktops || []).length*66+118))
        color: "transparent"; visible: !!vaela.state.mode
        flags: Qt.FramelessWindowHint
        Component.onCompleted: {root.applyPalette(tabsWindow);vaela.layer(tabsWindow,"tabs")}
        HoverHandler {
            id:tabsHover
            onHoveredChanged:if(hovered) {collapse.stop();tabsWindow.expanded=true} else collapse.restart()
        }
        Timer {id:collapse;interval:250;onTriggered:if(!tabsHover.hovered && !tabsWindow.openMenus && !rename.visible) tabsWindow.expanded=false}
        Rectangle {
            visible: !tabsWindow.opened
            anchors {right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter}
            width: 4; height: 56; radius: 2; color: Theme.accent; opacity: 0.9
        }
        Shadow {anchors.fill: tabsPanel; radius: tabsPanel.radius; visible: tabsWindow.opened}
        Rectangle {
            id: tabsPanel
            visible: tabsWindow.opened
            anchors {fill: parent; margins: 10; rightMargin: 8}
            radius: Theme.radiusLarge; color: Theme.panel; border.color: Theme.border
            ColumnLayout {
                anchors {fill: parent; margins: 10}
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 4
                    Text {text: "Workspaces"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true}
                    Text {text: (vaela.state.desktops || []).length; color: Theme.faint; font.pixelSize: 12}
                }
                ListView {
                    id: tabList
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                    model: vaela.state.desktops || []
                    delegate: Rectangle {
                        id: tab
                        required property var modelData
                        width: tabList.width; height: 60; radius: Theme.radius
                        color: modelData.current ? Theme.accentSoft : tabMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                        border.width: modelData.current ? 1 : 0; border.color: Theme.accent
                        Behavior on color {ColorAnimation {duration: Theme.fast}}
                        MouseArea {id: tabMouse; anchors.fill: parent; hoverEnabled: true; onClicked: vaela.call("desktop",[tab.modelData.id])}
                        ToolTip.text: modelData.windows.join("\n") || "Empty workspace"
                        ToolTip.visible: tabMouse.containsMouse
                        ToolTip.delay: 600
                        RowLayout {
                            anchors {fill: parent; leftMargin: 10; rightMargin: 4}
                            spacing: 10
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: tab.modelData.current ? Theme.accent : Theme.surfacePressed
                                Text {anchors.centerIn: parent; text: tab.modelData.id; color: tab.modelData.current ? "white" : Theme.muted; font.pixelSize: 12; font.weight: Font.DemiBold}
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Text {text: tab.modelData.name; color: Theme.text; font.pixelSize: 13; font.weight: tab.modelData.current ? Font.DemiBold : Font.Normal; elide: Text.ElideRight; Layout.fillWidth: true}
                                RowLayout {
                                    spacing: 5; Layout.fillWidth: true
                                    Image {source: Theme.icon(root.modeIcons[tab.modelData.mode] || "window", Theme.muted); sourceSize: Qt.size(12,12); Layout.preferredWidth: 12; Layout.preferredHeight: 12}
                                    Text {
                                        text: tab.modelData.mode+" · "+tab.modelData.windows.length+(tab.modelData.windows.length === 1 ? " window" : " windows")
                                        color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                }
                            }
                            VButton {
                                iconName: "overflow-menu"; flat: true; implicitWidth: 28; implicitHeight: 28; Accessible.name: "Workspace options"
                                onClicked: workspaceMenu.popup()
                                Menu {
                                    id: workspaceMenu
                                    onOpened:++tabsWindow.openMenus
                                    onClosed:{--tabsWindow.openMenus;collapse.restart()}
                                    MenuItem {text:"Rename…"; onTriggered:{rename.workspaceId=tab.modelData.id;renameName.text=tab.modelData.name;rename.open();tabsWindow.requestActivate();renameName.forceActiveFocus()}}
                                    MenuItem {text:"Remove workspace"; enabled:(vaela.state.desktops || []).length>1; onTriggered:vaela.call("removeDesktop",[tab.modelData.id])}
                                }
                            }
                        }
                    }
                }
                VButton {text: "New workspace"; iconName: "list-add"; flat: true; Layout.fillWidth: true; onClicked: vaela.call("addDesktop")}
            }
        }
        Dialog {
            id:rename; property int workspaceId:0; title:"Rename workspace"; modal:true
            anchors.centerIn: parent; width: 220
            standardButtons:Dialog.Ok | Dialog.Cancel
            TextField {id:renameName; placeholderText:"Workspace name"; width: parent.width}
            onAccepted:vaela.call("renameDesktop",[workspaceId,renameName.text])
        }
    }

    // Quick Commands, Vaela Settings, the radial menu and its editor share one overlay.
    property Window overlay: Window {
        id: overlay
        property string view: "commands"
        property int hot: -1
        property int radialPage: 0
        property double shownAt: 0
        property int originX: 0
        property int originY: 0
        color: "transparent"; flags:Qt.FramelessWindowHint
        Component.onCompleted: root.applyPalette(overlay)
        title: view === "radial-settings" ? "Radial Menu" : view === "settings" ? "Vaela Settings" : view === "radial" ? "Vaela Radial Menu" : "Quick Commands"
        // Switching views hides and reshows this window; the focus loss from that hide
        // arrives after the reshow and must not close the view that was just opened.
        onActiveChanged: if(!active && Date.now()-shownAt>400) hide()
        Item {
            anchors.fill:parent; focus:true
            Keys.onEscapePressed:overlay.hide()
            Shadow {anchors.fill: card; radius: card.radius; visible: card.visible}
            Rectangle {
                id: card
                visible: overlay.view !== "radial"
                anchors {fill: parent; margins: 12}
                radius: Theme.radiusLarge; color: Theme.panel; border.color: Theme.border
                ColumnLayout {
                    anchors {fill: parent; margins: 22}
                    spacing: 16
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Rectangle {
                            width: 38; height: 38; radius: 11; color: Theme.accentSoft
                            Image {
                                anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(20,20)
                                source: Theme.icon(overlay.view === "commands" ? "search" : overlay.view === "radial-settings" ? "view-list-icons" : "configure", Theme.accent)
                            }
                        }
                        ColumnLayout {
                            spacing: 1; Layout.fillWidth: true
                            Text {text: overlay.title; color: Theme.text; font.pixelSize: 20; font.weight: Font.DemiBold; Layout.fillWidth: true}
                            Text {
                                color: Theme.muted; font.pixelSize: 12; Layout.fillWidth: true
                                text: overlay.view === "commands" ? "Type to filter · ↑ ↓ to choose · Enter to run"
                                    : overlay.view === "radial-settings" ? "Choose what appears around the radial menu"
                                    : "Layouts, gestures and shortcuts"
                            }
                        }
                        VButton {iconName: "window-close"; flat: true; implicitWidth: 32; implicitHeight: 32; Accessible.name: "Close"; onClicked: overlay.hide()}
                    }

                    // Quick Commands
                    Rectangle {
                        visible: overlay.view === "commands"
                        Layout.fillWidth: true; implicitHeight: 44; radius: Theme.radius
                        color: Theme.surface; border.color: search.activeFocus ? Theme.accent : Theme.border
                        RowLayout {
                            anchors {fill: parent; leftMargin: 14; rightMargin: 10}
                            spacing: 10
                            Image {source: Theme.icon("search", Theme.muted); sourceSize: Qt.size(16,16); Layout.preferredWidth: 16; Layout.preferredHeight: 16}
                            TextField {
                                id:search; Layout.fillWidth:true
                                placeholderText:"Search commands…"; onTextChanged:commandList.currentIndex=0
                                background: null; color: Theme.text; placeholderTextColor: Theme.faint; font.pixelSize: 15
                                Keys.onDownPressed:commandList.incrementCurrentIndex()
                                Keys.onUpPressed:commandList.decrementCurrentIndex()
                                onAccepted:if(commandList.currentItem) root.run(commandList.currentItem.modelData.action)
                            }
                        }
                    }
                    ListView {
                        id:commandList; visible:overlay.view === "commands"; Layout.fillWidth:true; Layout.fillHeight:true; clip:true
                        model:root.commands.filter(c=>c.action && c.label.toLowerCase().includes(search.text.toLowerCase()))
                        currentIndex:0; spacing:2
                        delegate: Rectangle {
                            id: commandRow
                            required property var modelData
                            required property int index
                            readonly property bool current: commandList.currentIndex === index
                            width: commandList.width; height: 42; radius: Theme.radiusSmall
                            color: current ? Theme.accentSoft : commandMouse.containsMouse ? Theme.surfaceHover : "transparent"
                            Rectangle {visible: commandRow.current; width: 3; radius: 1.5; color: Theme.accent; anchors {left: parent.left; top: parent.top; bottom: parent.bottom; margins: 9}}
                            RowLayout {
                                anchors {fill: parent; leftMargin: 18; rightMargin: 14}
                                spacing: 12
                                Image {source: Theme.icon(commandRow.modelData.icon || "go-next", commandRow.current ? Theme.accent : Theme.muted); sourceSize: Qt.size(16,16); Layout.preferredWidth: 16; Layout.preferredHeight: 16}
                                Text {text: commandRow.modelData.label; color: Theme.text; font.pixelSize: 14; Layout.fillWidth: true; elide: Text.ElideRight}
                                Text {visible: commandRow.current; text: "↵"; color: Theme.muted; font.pixelSize: 14}
                            }
                            MouseArea {
                                id: commandMouse; anchors.fill: parent; hoverEnabled: true
                                onEntered: commandList.currentIndex = commandRow.index
                                onClicked: root.run(commandRow.modelData.action)
                            }
                        }
                        Text {anchors.centerIn: parent; visible: commandList.count === 0; text: "No matching commands"; color: Theme.muted; font.pixelSize: 13}
                        ScrollBar.vertical:ScrollBar {}
                    }

                    RadialEditor {
                        id:radialEditor
                        visible:overlay.view === "radial-settings";Layout.fillWidth:true;Layout.fillHeight:true
                    }

                    // Vaela Settings
                    ScrollView {
                        id: settingsScroll
                        visible:overlay.view === "settings"; Layout.fillHeight:true; Layout.fillWidth:true
                        contentWidth:availableWidth; clip: true
                        ColumnLayout {
                            width: settingsScroll.availableWidth - 12; spacing: 12
                            Card {
                                title: "Window layout"; subtitle: "Applies to the current workspace in this activity."
                                RowLayout {
                                    spacing: 6; Layout.fillWidth: true
                                    Repeater {
                                        model: root.modes
                                        VButton {
                                            required property string modelData
                                            text: modelData; iconName: root.modeIcons[modelData]; Layout.fillWidth: true
                                            active: vaela.state.mode === modelData
                                            onClicked: vaela.call("setMode",[modelData])
                                        }
                                    }
                                }
                                SettingRow {
                                    label: "Gap between windows"
                                    Slider {from: 0; to: 40; stepSize: 1; value: vaela.gap; Layout.preferredWidth: 200; onMoved: vaela.setting("Gap",Math.round(value))}
                                    Text {text: vaela.gap+" px"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
                                }
                            }
                            Card {
                                title: "Mouse gestures"
                                subtitle: "Hold the right button still for half a second for the radial menu, move onto an item and release to open it. A quick right-click opens the app's own menu. Draw with the right button for gestures. Shift + right-click skips Vaela."
                                SettingRow {
                                    label: "Right-button gestures and radial menu"
                                    Switch {checked: vaela.gestures; onToggled: vaela.setting("Gestures",checked)}
                                }
                                SettingRow {
                                    label: "Stroke length before a gesture starts"
                                    Slider {from: 12; to: 120; stepSize: 1; value: vaela.threshold; Layout.preferredWidth: 200; onMoved: vaela.setting("Threshold",Math.round(value))}
                                    Text {text: vaela.threshold+" px"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
                                }
                            }
                            Card {
                                title: "Gesture actions"; subtitle: "Choose what each stroke does."
                                GridLayout {
                                    columns: 2; columnSpacing: 12; rowSpacing: 8; Layout.fillWidth: true
                                    Repeater {
                                        model: root.strokes
                                        delegate: RowLayout {
                                            id: strokeRow
                                            required property var modelData
                                            Layout.fillWidth: true; spacing: 8
                                            KeyCap {text: strokeRow.modelData.arrows; Layout.preferredWidth: 52}
                                            ComboBox {
                                                model:root.commands; textRole:"label"; valueRole:"action"; Layout.fillWidth:true
                                                currentIndex:root.commands.findIndex(c=>c.action === vaela.bindings[strokeRow.modelData.stroke])
                                                onActivated:vaela.bind(strokeRow.modelData.stroke,currentValue)
                                            }
                                        }
                                    }
                                }
                            }
                            Card {
                                title: "Radial menu"; subtitle: "Applications, commands and desktop actions around the pointer."
                                VButton {text: "Customize radial menu…"; iconName: "view-list-icons"; accent: true; onClicked: root.open("radial-settings",0,0)}
                            }
                            Card {
                                title: "Keyboard shortcuts"
                                Repeater {
                                    model: root.keys
                                    delegate: RowLayout {
                                        id: keyRow
                                        required property var modelData
                                        Layout.fillWidth: true; spacing: 12
                                        KeyCap {text: keyRow.modelData[0]; Layout.preferredWidth: 170}
                                        Text {text: keyRow.modelData[1]; color: Theme.text; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap}
                                    }
                                }
                                VButton {text: "Edit keyboard shortcuts…"; iconName: "preferences-desktop-keyboard-shortcut"; onClicked: vaela.launch("shortcuts")}
                            }
                            Card {
                                title: "System"; subtitle: "Plasma's settings pages, opened directly."
                                GridLayout {
                                    columns: 3; columnSpacing: 8; rowSpacing: 8; Layout.fillWidth: true
                                    Repeater {
                                        model: root.systemPages
                                        delegate: Rectangle {
                                            id: pageTile
                                            required property var modelData
                                            Layout.fillWidth: true; implicitHeight: 44; radius: Theme.radiusSmall
                                            color: pageMouse.containsMouse ? Theme.surfaceHover : Theme.surfacePressed
                                            Behavior on color {ColorAnimation {duration: Theme.fast}}
                                            RowLayout {
                                                anchors {fill: parent; leftMargin: 10; rightMargin: 8}
                                                spacing: 10
                                                Image {source: Theme.appIcon(pageTile.modelData.icon); sourceSize: Qt.size(22,22); Layout.preferredWidth: 22; Layout.preferredHeight: 22}
                                                Text {text: pageTile.modelData.label; color: Theme.text; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true}
                                            }
                                            MouseArea {id: pageMouse; anchors.fill: parent; hoverEnabled: true; onClicked: {overlay.hide();vaela.launch(pageTile.modelData.page)}}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Radial menu: items around a hub; the hovered item grows and opens on release or click.
            Item {
                id: radialView
                anchors.fill:parent; visible:overlay.view === "radial"
                Shadow {anchors.fill: disc; radius: disc.radius}
                Rectangle {
                    id: disc
                    anchors.centerIn: parent; width: 428; height: 428; radius: 214
                    color: Theme.panel; border.color: Theme.border
                }
                Rectangle {
                    anchors.centerIn: parent; width: 290; height: 290; radius: 145
                    color: "transparent"; border.color: Qt.rgba(1,1,1,0.04); border.width: 1
                }
                HoverHandler {onPointChanged: overlay.hot=root.radialHot(point.position.x,point.position.y)}
                Repeater {
                    model:root.radialItems
                    Item {
                        id: radialItem
                        required property var modelData
                        required property int index
                        readonly property bool hot: overlay.hot === index
                        readonly property real angle: index*2*Math.PI/Math.max(1,root.radialItems.length)
                        x: 220+145*Math.sin(angle)-width/2
                        y: 220-145*Math.cos(angle)-32
                        width: 110; height: 98
                        Rectangle {
                            id: bubble
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 64; height: 64; radius: 32
                            color: radialItem.hot ? Theme.accent : Theme.surface
                            border.width: 2; border.color: radialItem.hot ? Qt.lighter(Theme.accent,1.25) : Theme.border
                            scale: radialItem.hot ? 1.22 : 1
                            Behavior on scale {NumberAnimation {duration: Theme.normal; easing.type: Easing.OutBack}}
                            Behavior on color {ColorAnimation {duration: Theme.fast}}
                            Image {
                                anchors.centerIn: parent; width: 36; height: 36
                                source: radialItem.modelData.type === "builtin" ? Theme.icon(radialItem.modelData.icon, radialItem.hot ? "#ffffff" : Theme.text) : Theme.appIcon(radialItem.modelData.icon)
                                sourceSize: Qt.size(48,48); fillMode: Image.PreserveAspectFit
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: radialItem.modelData.label
                        }
                        Text {
                            anchors {top: bubble.bottom; topMargin: radialItem.hot ? 12 : 6}
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                            text: radialItem.modelData.label; font.pixelSize: 12
                            font.weight: radialItem.hot ? Font.DemiBold : Font.Normal
                            color: radialItem.hot ? Theme.text : Theme.muted
                        }
                        MouseArea {
                            anchors.fill: bubble; hoverEnabled: true
                            onEntered: overlay.hot = radialItem.index
                            onClicked: root.runRadial(radialItem.modelData)
                        }
                    }
                }
                Rectangle {
                    id: hub
                    anchors.centerIn: parent; width: 132; height: 132; radius: 66
                    color: Theme.surface; border.width: 2; border.color: overlay.hot >= 0 ? Theme.accent : Theme.border
                    Behavior on border.color {ColorAnimation {duration: Theme.fast}}
                    Column {
                        anchors.centerIn: parent; spacing: 3; width: 112
                        Text {
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                            text: overlay.hot >= 0 && root.radialItems[overlay.hot] ? root.radialItems[overlay.hot].label : radial.entries.length ? "Vaela" : "Empty menu"
                            color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width; horizontalAlignment: Text.AlignHCenter
                            text: overlay.hot >= 0 ? "Release to open" : radial.entries.length ? (vaela.state.mode || "") : "Add items with ⚙"
                            color: Theme.muted; font.pixelSize: 11
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 2; topPadding: 4
                            VButton {iconName: "go-previous"; flat: true; implicitWidth: 24; implicitHeight: 24; iconSize: 12; visible: radial.entries.length>8; enabled: overlay.radialPage>0; Accessible.name: "Previous page"; onClicked: {overlay.hot=-1;--overlay.radialPage}}
                            VButton {iconName: "configure"; flat: true; implicitWidth: 24; implicitHeight: 24; iconSize: 14; Accessible.name: "Customize radial menu"; onClicked: root.open("radial-settings",0,0)}
                            VButton {iconName: "go-next"; flat: true; implicitWidth: 24; implicitHeight: 24; iconSize: 12; visible: radial.entries.length>8; enabled: (overlay.radialPage+1)*8<radial.entries.length; Accessible.name: "Next page"; onClicked: {overlay.hot=-1;++overlay.radialPage}}
                        }
                    }
                }
            }
        }
    }
}
