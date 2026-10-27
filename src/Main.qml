// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs
import QtCore
import QtMultimedia

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
    readonly property var monitorChoices: [{label:"Primary monitor",value:"primary"}, {label:"All monitors",value:"all"}, {label:"Chosen monitors",value:"chosen"}]
    readonly property string monitorChoice: vaela.monitors === "primary" || vaela.monitors === "all" ? vaela.monitors : "chosen"
    readonly property var fills: [{label:"Fill",value:"fill",icon:"zoom-fit-best"}, {label:"Fit",value:"fit",icon:"zoom-original"}, {label:"Stretch",value:"stretch",icon:"transform-scale"}]
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
    function keyLabel(keys) {return keys ? keys.replace(/\+\+$/,"+Plus").replace(/\+-$/,"+Minus") : "None"}
    // Monitor switches in Settings: turning one on or off moves to an explicit list, never an empty one.
    function toggleMonitor(name,on) {
        const outputs=vaela.state.outputs || []
        let names=monitorChoice === "chosen" ? vaela.monitors.split(",").filter(n=>n) : outputs.filter(o=>o.covered).map(o=>o.name)
        names=names.filter(n=>n !== name)
        if(on) names.push(name)
        if(outputs.some(o=>names.includes(o.name))) vaela.setting("Monitors",names.join(","))
    }
    function fileName(url) {return url ? decodeURIComponent(String(url).replace(/\/$/, "").split("/").pop()) : ""}
    // Opens Settings with the file picker for one workspace's background.
    function chooseBackground(desktop,screen,x,y) {
        open("settings",x,y,screen)
        backgroundPicker.desktop=desktop
        backgroundPicker.open()
    }
    // Opens a view in the middle of the overlay as last shown, so it stays on that monitor.
    function reopen(view) {open(view,overlay.originX+overlay.width/2,overlay.originY+overlay.height/2,overlay.screenName,overlay.areaWidth,overlay.areaHeight)}
    function run(action) {
        overlay.hide()
        if (action === "settings" || action === "commands") reopen(action)
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
    // x and y are on the named screen when there is one (the KWin plugin always names it), global otherwise.
    function open(view,x,y,screen,width,height) {
        if(view === "dismiss") {overlay.hide();return}
        // While the right button is held, the KWin plugin reports the pointer on the radial menu's monitor.
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
        const placed=vaela.layer(overlay,"overlay",x,y,screen || "",width || 0,height || 0)
        overlay.originX=placed.x; overlay.originY=placed.y
        overlay.screenName=placed.screen; overlay.areaWidth=placed.width; overlay.areaHeight=placed.height
        overlay.show(); overlay.requestActivate()
        if(view === "commands") search.forceActiveFocus()
    }
    property var radialItems: radial.entries.slice(overlay.radialPage*8,overlay.radialPage*8+8)
    property Connections radialEvents: Connections {
        target:radial
        function onEntriesChanged() {overlay.hot=-1;overlay.radialPage=Math.min(overlay.radialPage,Math.max(0,Math.ceil(radial.entries.length/8)-1))}
        function onLaunchFailed() {root.reopen("radial-settings")}
    }
    property Connections bridge: Connections {
        target: vaela
        function onRequested(view,x,y,screen,width,height) {root.open(view,x,y,screen,width,height)}
        function onChanged() { if(!vaela.state.mode) overlay.hide() }
        function onShortcutResult(id,keys,clash) {
            if(id !== overlay.recording && (!overlay.clash || id !== overlay.clash.id)) return
            overlay.recording=""
            overlay.clash=clash ? {id:id,keys:keys,by:clash} : null
        }
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

    // A small preview of a workspace background: the picture, or a video's first frame.
    component BackgroundPreview: Rectangle {
        id: preview
        property string source
        property bool live: true
        readonly property string kind: live ? vaela.mediaKind(source) : ""
        property bool broken: false
        onSourceChanged: broken=false
        implicitWidth: 112; implicitHeight: 63; radius: 8; clip: true
        color: Theme.surfacePressed; border.color: Theme.border
        Image {
            anchors.fill: parent; anchors.margins: 1
            visible: preview.kind === "image"
            source: visible ? preview.source : ""
            asynchronous: true; fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(224,126)
            onStatusChanged: if(status === Image.Error) preview.broken=true
        }
        // Created only for videos, so the shell loads FFmpeg only once there is one to show.
        Loader {
            anchors.fill: parent; anchors.margins: 1
            active: preview.kind === "video"
            sourceComponent: Item {
                VideoOutput {id: previewOutput; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop}
                MediaPlayer {
                    id: previewPlayer
                    source: preview.source
                    videoOutput: previewOutput
                    // Plays to the first frame, then holds it.
                    Component.onCompleted: play()
                    onSourceChanged: play()
                    onErrorOccurred: preview.broken=true
                }
                Connections {
                    target: previewOutput.videoSink
                    function onVideoFrameChanged() {if(previewPlayer.playing) previewPlayer.pause()}
                }
            }
        }
        Image {
            anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(20,20)
            visible: !preview.source || preview.broken
            source: Theme.icon(preview.broken ? "dialog-warning" : "preferences-desktop-wallpaper", Theme.faint)
        }
        Rectangle {
            visible: preview.kind === "video" && !preview.broken
            anchors {left: parent.left; bottom: parent.bottom; margins: 5}
            width: 18; height: 18; radius: 9; color: Qt.rgba(0,0,0,0.55)
            Image {anchors.centerIn: parent; width: 10; height: 10; sourceSize: Qt.size(10,10); source: Theme.icon("media-playback-start", "#ffffff")}
        }
    }

    // Layout switch, on each monitor Vaela covers: a short handle on the top edge, set in from the right
    // (see Bridge::layer) so it stays clear of a maximized window's close button, until the pointer reaches it.
    property Instantiator tops: Instantiator {
        model: vaela.screens
        delegate: Window {
            id: topWindow
            required property string modelData
            property bool expanded:false
            // Shown only once placed: a layer surface keeps the monitor it is first shown on.
            property bool placed:false
            width: expanded ? switchPanel.implicitWidth + 8 : 160
            height: expanded ? 38 : 6; color: "transparent"
            visible: placed && !!vaela.state.mode
            flags: Qt.FramelessWindowHint
            Component.onCompleted: {root.applyPalette(topWindow);vaela.layer(topWindow,"top",0,0,modelData);placed=true}
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
                    VButton {iconName: "search"; flat: true; implicitWidth: 28; implicitHeight: 24; Accessible.name: "Quick Commands"; onClicked: root.open("commands",Screen.width/2,Screen.height/2,topWindow.modelData)}
                    VButton {iconName: "configure"; flat: true; implicitWidth: 28; implicitHeight: 24; Accessible.name: "Vaela Settings"; onClicked: root.open("settings",Screen.width/2,Screen.height/2,topWindow.modelData)}
                }
            }
        }
    }

    // Workspace bar, on each monitor Vaela covers: vertical tabs that slide in when the pointer reaches the right edge.
    property Instantiator tabs: Instantiator {
        model: vaela.screens
        delegate: Window {
            id: tabsWindow
            required property string modelData
            property bool expanded:false
            property bool placed:false
            property int openMenus:0
            readonly property bool opened: expanded || openMenus>0 || rename.visible
            width: opened ? 276 : 10
            height: Math.min(Screen.height-120,Math.max(170,(vaela.state.desktops || []).length*66+118))
            color: "transparent"; visible: placed && !!vaela.state.mode
            flags: Qt.FramelessWindowHint
            Component.onCompleted: {root.applyPalette(tabsWindow);vaela.layer(tabsWindow,"tabs",0,0,modelData);placed=true}
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
                                        MenuItem {text:"Background…"; onTriggered:root.chooseBackground(tab.modelData.id,tabsWindow.modelData,Screen.width/2,Screen.height/2)}
                                        MenuItem {text:"Remove background"; visible:!!tab.modelData.background; height:visible ? implicitHeight : 0; onTriggered:vaela.setBackground(tab.modelData.id,"")}
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
    }

    // Quick Commands, Vaela Settings, the radial menu and its editor share one overlay.
    property Window overlay: Window {
        id: overlay
        property string view: "commands"
        property int hot: -1
        property int radialPage: 0
        property double shownAt: 0
        // Where the overlay sits: its top-left corner on its monitor, and that monitor's name and size.
        property int originX: 0
        property int originY: 0
        property string screenName: ""
        property int areaWidth: 0
        property int areaHeight: 0
        property string recording: ""   // shortcut waiting for keys
        property int backgroundTarget: 0  // workspace whose background options Settings shows; 0 is the current one
        property var clash: null        // {id, keys, by}: keys that something else already uses
        color: "transparent"; flags:Qt.FramelessWindowHint
        onVisibleChanged: if(!visible) {
            if(recording) vaela.call("recordShortcut",[""])
            recording=""; clash=null; backgroundTarget=0
        }
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
                            width: 38; height: 38; radius: 11; color: overlay.view === "settings" ? Theme.surfacePressed : Theme.accentSoft
                            // Vaela Settings wears the Vaela mark; the other views their own icon.
                            Image {
                                visible: overlay.view === "settings"
                                anchors.centerIn: parent; width: 28; height: 28; sourceSize: Qt.size(56,56)
                                source: Qt.resolvedUrl("vaela-mark.svg")
                            }
                            Image {
                                visible: overlay.view !== "settings"
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
                                id: backgroundsCard
                                title: "Backgrounds"
                                subtitle: "A video or picture for each workspace in this activity. Workspaces without one keep your Plasma wallpaper. Click a workspace to change its options."
                                Repeater {
                                    model: vaela.state.desktops || []
                                    delegate: RowLayout {
                                        id: backgroundRow
                                        required property var modelData
                                        readonly property bool selected: backgroundsCard.optionsFor.id === modelData.id
                                        Layout.fillWidth: true; spacing: 10
                                        TapHandler {onTapped: overlay.backgroundTarget=backgroundRow.modelData.id}
                                        BackgroundPreview {
                                            source: backgroundRow.modelData.background || ""; live: overlay.visible && overlay.view === "settings"
                                            border.color: backgroundRow.selected ? Theme.accent : Theme.border; border.width: backgroundRow.selected ? 2 : 1
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text {text: backgroundRow.modelData.name; color: backgroundRow.selected ? Theme.accent : Theme.text; font.pixelSize: 13; font.weight: backgroundRow.selected ? Font.DemiBold : Font.Normal; elide: Text.ElideRight; Layout.fillWidth: true}
                                            Text {text: root.fileName(backgroundRow.modelData.background) || "Plasma wallpaper"; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideMiddle; Layout.fillWidth: true}
                                        }
                                        VButton {text: "Choose…"; iconName: "document-open"; onClicked: {backgroundPicker.desktop=backgroundRow.modelData.id;backgroundPicker.open()}}
                                        VButton {
                                            iconName: "edit-copy"; flat: true; implicitWidth: 30; visible: !!backgroundRow.modelData.background
                                            Accessible.name: "Use for all workspaces"; ToolTip.text: Accessible.name; ToolTip.visible: hovered; ToolTip.delay: 500
                                            onClicked: vaela.setBackgroundEverywhere(backgroundRow.modelData.background)
                                        }
                                        VButton {
                                            iconName: "edit-delete"; flat: true; implicitWidth: 30; visible: !!backgroundRow.modelData.background
                                            Accessible.name: "Remove background"; ToolTip.text: Accessible.name; ToolTip.visible: hovered; ToolTip.delay: 500
                                            onClicked: vaela.setBackground(backgroundRow.modelData.id,"")
                                        }
                                    }
                                }
                                // The workspace the options below apply to: the one picked above, or the current one.
                                readonly property var optionsFor: {
                                    const desktops=vaela.state.desktops || []
                                    return desktops.find(d=>d.id === overlay.backgroundTarget) || desktops.find(d=>d.current) || desktops[0] || ({id:0,name:"",options:{}})
                                }
                                readonly property var options: optionsFor.options || ({})
                                RowLayout {
                                    Layout.fillWidth: true; Layout.topMargin: 6; spacing: 8
                                    Text {text: "Options for "+backgroundsCard.optionsFor.name; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight}
                                    VButton {
                                        text: "Use on every workspace"; iconName: "edit-copy"; flat: true; implicitHeight: 28
                                        onClicked: vaela.copyBackgroundOptions(backgroundsCard.optionsFor.id)
                                    }
                                }
                                SettingRow {
                                    label: "Scaling"
                                    Repeater {
                                        model: root.fills
                                        VButton {
                                            required property var modelData
                                            text: modelData.label; iconName: modelData.icon; implicitHeight: 30
                                            active: backgroundsCard.options.fill === modelData.value
                                            onClicked: vaela.setBackgroundOption(backgroundsCard.optionsFor.id,"fill",modelData.value)
                                        }
                                    }
                                }
                                SettingRow {
                                    label: "Mute"
                                    Switch {checked: !!backgroundsCard.options.muted; onToggled: vaela.setBackgroundOption(backgroundsCard.optionsFor.id,"muted",checked)}
                                }
                                SettingRow {
                                    label: "Volume"
                                    opacity: backgroundsCard.options.muted ? 0.5 : 1
                                    Slider {from: 0; to: 100; stepSize: 5; value: backgroundsCard.options.volume || 0; enabled: !backgroundsCard.options.muted; Layout.preferredWidth: 200; onMoved: vaela.setBackgroundOption(backgroundsCard.optionsFor.id,"volume",Math.round(value))}
                                    Text {text: (backgroundsCard.options.volume || 0)+" %"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
                                }
                                SettingRow {
                                    label: "Playback speed"
                                    Slider {from: 25; to: 200; stepSize: 25; value: backgroundsCard.options.speed || 100; Layout.preferredWidth: 200; onMoved: vaela.setBackgroundOption(backgroundsCard.optionsFor.id,"speed",Math.round(value))}
                                    Text {text: ((backgroundsCard.options.speed || 100)/100).toFixed(2)+"×"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
                                }
                                SettingRow {
                                    label: "Dim"
                                    Slider {from: 0; to: 80; stepSize: 5; value: backgroundsCard.options.dim || 0; Layout.preferredWidth: 200; onMoved: vaela.setBackgroundOption(backgroundsCard.optionsFor.id,"dim",Math.round(value))}
                                    Text {text: (backgroundsCard.options.dim || 0)+" %"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
                                }
                                SettingRow {
                                    label: "Blur"
                                    Slider {from: 0; to: 100; stepSize: 5; value: backgroundsCard.options.blur || 0; Layout.preferredWidth: 200; onMoved: vaela.setBackgroundOption(backgroundsCard.optionsFor.id,"blur",Math.round(value))}
                                    Text {text: (backgroundsCard.options.blur || 0)+" %"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
                                }
                                Text {text: "All workspaces"; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.topMargin: 6}
                                SettingRow {
                                    label: "Crossfade between workspaces"
                                    Slider {from: 0; to: 2000; stepSize: 100; value: vaela.background.transition; Layout.preferredWidth: 200; onMoved: vaela.setting("BackgroundTransition",Math.round(value))}
                                    Text {text: (vaela.background.transition/1000).toFixed(1)+" s"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
                                }
                                SettingRow {
                                    label: "Pause videos while windows cover the screen"
                                    Switch {checked: vaela.background.pauseCovered; onToggled: vaela.setting("PauseWhenCovered",checked)}
                                }
                                SettingRow {
                                    label: "Pause videos while any window is open"
                                    Switch {checked: vaela.background.pauseWindows; onToggled: vaela.setting("PauseWhenWindows",checked)}
                                }
                                SettingRow {
                                    label: "Pause videos even when their sound is on"
                                    Switch {checked: !vaela.background.keepAudible; onToggled: vaela.setting("KeepAudible",!checked)}
                                }
                                SettingRow {
                                    label: "Pause videos on battery"
                                    Switch {checked: vaela.background.pauseOnBattery; onToggled: vaela.setting("PauseOnBattery",checked)}
                                }
                            }
                            Card {
                                title: "Mouse gestures"
                                subtitle: "Hold the right button still for the radial menu, move onto an item and release to open it. A quick right-click opens the app's own menu. Draw with the right button for gestures. Shift + right-click skips Vaela."
                                SettingRow {
                                    label: "Right-button gestures and radial menu"
                                    Switch {checked: vaela.gestures; onToggled: vaela.setting("Gestures",checked)}
                                }
                                SettingRow {
                                    label: "Stroke length before a gesture starts"
                                    Slider {from: 12; to: 120; stepSize: 1; value: vaela.threshold; Layout.preferredWidth: 200; onMoved: vaela.setting("Threshold",Math.round(value))}
                                    Text {text: vaela.threshold+" px"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
                                }
                                SettingRow {
                                    label: "Hold time before the radial menu opens"
                                    Slider {from: 150; to: 2000; stepSize: 50; value: vaela.radialDelay; Layout.preferredWidth: 200; onMoved: vaela.setting("RadialDelay",Math.round(value))}
                                    Text {text: (vaela.radialDelay/1000).toFixed(2)+" s"; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight}
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
                                VButton {text: "Customize radial menu…"; iconName: "view-list-icons"; accent: true; onClicked: root.reopen("radial-settings")}
                            }
                            Card {
                                title: "Monitors"
                                subtitle: "Where the layout switch, workspace bar, gestures and tiling work. Other monitors behave like plain Plasma."
                                RowLayout {
                                    spacing: 6; Layout.fillWidth: true
                                    Repeater {
                                        model: root.monitorChoices
                                        VButton {
                                            required property var modelData
                                            text: modelData.label; Layout.fillWidth: true
                                            active: root.monitorChoice === modelData.value
                                            // Choosing starts from the monitors in use now.
                                            onClicked: vaela.setting("Monitors",modelData.value !== "chosen" ? modelData.value
                                                : (vaela.state.outputs || []).filter(o=>o.covered).map(o=>o.name).join(","))
                                        }
                                    }
                                }
                                Repeater {
                                    model: vaela.state.outputs || []
                                    delegate: SettingRow {
                                        id: monitorRow
                                        required property var modelData
                                        label: (modelData.label !== modelData.name ? modelData.label+"  ·  " : "")+modelData.name+(modelData.primary ? "  ·  primary" : "")
                                        Switch {
                                            checked: monitorRow.modelData.covered
                                            enabled: root.monitorChoice === "chosen" && !(checked && (vaela.state.outputs || []).filter(o=>o.covered).length === 1)
                                            onToggled: root.toggleMonitor(monitorRow.modelData.name,checked)
                                        }
                                    }
                                }
                            }
                            Card {
                                title: "Keyboard shortcuts"
                                subtitle: "Click a shortcut, then press the new keys. Esc cancels, Backspace removes it. Layout keys take over Plasma's keys only in the layouts named."
                                Repeater {
                                    model: vaela.state.shortcuts || []
                                    delegate: ColumnLayout {
                                        id: keyRow
                                        required property var modelData
                                        readonly property bool editing: overlay.recording === modelData.id
                                        readonly property bool clashing: !!overlay.clash && overlay.clash.id === modelData.id
                                        Layout.fillWidth: true; spacing: 6
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 8
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 1
                                                Text {text: keyRow.modelData.label; color: Theme.text; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight}
                                                Text {visible: !!keyRow.modelData.layout; text: "Only in "+keyRow.modelData.layout; color: Theme.faint; font.pixelSize: 11}
                                            }
                                            VButton {
                                                visible: keyRow.modelData.keys !== keyRow.modelData["default"]
                                                iconName: "edit-undo"; flat: true; implicitWidth: 28; implicitHeight: 28
                                                Accessible.name: "Reset to "+root.keyLabel(keyRow.modelData["default"])
                                                ToolTip.text: Accessible.name; ToolTip.visible: hovered; ToolTip.delay: 600
                                                onClicked: {overlay.clash=null;vaela.call("setShortcut",[keyRow.modelData.id,keyRow.modelData["default"],false])}
                                            }
                                            VButton {
                                                text: keyRow.editing ? "Press keys…" : root.keyLabel(keyRow.modelData.keys)
                                                active: keyRow.editing; Layout.preferredWidth: 190
                                                Accessible.name: keyRow.modelData.label+": "+text
                                                onClicked: {
                                                    overlay.clash=null
                                                    overlay.recording=keyRow.editing ? "" : keyRow.modelData.id
                                                    vaela.call("recordShortcut",[overlay.recording])
                                                }
                                            }
                                        }
                                        Rectangle {
                                            visible: keyRow.clashing
                                            Layout.fillWidth: true; implicitHeight: clashRow.implicitHeight + 16; radius: Theme.radiusSmall
                                            color: Theme.accentSoft; border.color: Theme.accent
                                            RowLayout {
                                                id: clashRow
                                                anchors {fill: parent; margins: 8; leftMargin: 12}
                                                spacing: 8
                                                Text {
                                                    text: keyRow.clashing ? root.keyLabel(overlay.clash.keys)+" is used by "+overlay.clash.by+"." : ""
                                                    color: Theme.text; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true
                                                }
                                                VButton {text: "Replace"; accent: true; implicitHeight: 28; onClicked: vaela.call("setShortcut",[overlay.clash.id,overlay.clash.keys,true])}
                                                VButton {text: "Cancel"; flat: true; implicitHeight: 28; onClicked: overlay.clash=null}
                                            }
                                        }
                                    }
                                }
                                VButton {text: "All shortcuts in System Settings…"; iconName: "preferences-desktop-keyboard-shortcut"; onClicked: {overlay.hide();vaela.launch("shortcuts")}}
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

            FileDialog {
                id: backgroundPicker
                property int desktop: 0
                title: "Choose a background"
                options: FileDialog.DontUseNativeDialog
                currentFolder: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]
                nameFilters: ["Videos and pictures (*.mp4 *.m4v *.mkv *.webm *.mov *.avi *.ogv *.mpg *.mpeg *.wmv *.png *.jpg *.jpeg *.webp *.avif *.jxl *.gif *.bmp *.svg)",
                              "Videos (*.mp4 *.m4v *.mkv *.webm *.mov *.avi *.ogv *.mpg *.mpeg *.wmv)",
                              "Pictures (*.png *.jpg *.jpeg *.webp *.avif *.jxl *.gif *.bmp *.svg)", "All files (*)"]
                onAccepted: {overlay.backgroundTarget=desktop;vaela.setBackground(desktop,selectedFile.toString())}
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
                        // The Vaela mark while nothing is hovered; the hovered item's name otherwise.
                        Image {
                            visible: overlay.hot < 0 && radial.entries.length > 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 40; height: 40; sourceSize: Qt.size(80,80)
                            source: Qt.resolvedUrl("vaela-mark.svg")
                            Accessible.name: "Vaela"
                        }
                        Text {
                            visible: overlay.hot >= 0 || radial.entries.length === 0
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                            text: overlay.hot >= 0 && root.radialItems[overlay.hot] ? root.radialItems[overlay.hot].label : "Empty menu"
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
                            VButton {iconName: "configure"; flat: true; implicitWidth: 24; implicitHeight: 24; iconSize: 14; Accessible.name: "Customize radial menu"; onClicked: root.reopen("radial-settings")}
                            VButton {iconName: "go-next"; flat: true; implicitWidth: 24; implicitHeight: 24; iconSize: 12; visible: radial.entries.length>8; enabled: (overlay.radialPage+1)*8<radial.entries.length; Accessible.name: "Next page"; onClicked: {overlay.hot=-1;++overlay.radialPage}}
                        }
                    }
                }
            }
        }
    }
}
