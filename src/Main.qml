// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

QtObject {
    id: root
    property color background: "#242630"
    property color accent: "#d58b66"
    property var modes: ["Float", "Auto Tiling", "Scrollable"]
    property var commands: [
        {label:"Move column left",action:"column-left"}, {label:"Move column right",action:"column-right"},
        {label:"Widen window / column",action:"widen"}, {label:"Narrow window / column",action:"narrow"},
        {label:"Increase row height",action:"taller"}, {label:"Decrease row height",action:"shorter"},
        {label:"Disabled",action:""},
        {label:"Send window to next workspace",action:"send-next"}, {label:"Send window to previous workspace",action:"send-previous"}, {label:"Quick Commands",action:"commands"},
        {label:"New terminal", action:"terminal"}, {label:"Files", action:"files"},
        {label:"Web browser", action:"browser"}, {label:"Screenshot", action:"screenshot"},
        {label:"Previous workspace", action:"previous"}, {label:"Next workspace", action:"next"},
        {label:"Maximize / restore window", action:"maximize"}, {label:"Minimize window", action:"minimize"},
        {label:"Close window", action:"close"}, {label:"Cycle layout", action:"cycle-layout"},
        {label:"Focus next window", action:"focus-next"}, {label:"Focus previous window", action:"focus-previous"},
        {label:"Activities", action:"activities"}, {label:"Vela Settings", action:"settings"},
        {label:"System Settings", action:"system"}]
    function run(action) {
        overlay.hide()
        if (action === "settings" || action === "commands") open(action,0,0)
        else if (action === "system") vela.launch("system")
        else vela.call("action",[action])
    }
    function open(view,x,y) {
        if(view === "radial-release") {
            if(overlay.visible && overlay.view === "radial" && overlay.hot >= 0) run(radialItems[overlay.hot].action)
            return
        }
        overlay.hide(); overlay.view=view; overlay.hot=-1; search.text=""
        overlay.width=view === "radial" ? 440 : 620
        overlay.height=view === "radial" ? 440 : 580
        vela.layer(overlay,"overlay",x || Screen.width/2,y || Screen.height/2)
        overlay.show(); overlay.requestActivate()
        if(view === "commands") search.forceActiveFocus()
    }
    property var radialItems: [
        {label:"Terminal",action:"terminal"},{label:"Web",action:"browser"},
        {label:"Files",action:"files"},{label:"Layout",action:"cycle-layout"},
        {label:"Settings",action:"settings"},{label:"Activities",action:"activities"},
        {label:"Screenshot",action:"screenshot"},{label:"Commands",action:"commands"}]
    property Connections bridge: Connections {
        target: vela
        function onRequested(view,x,y) {root.open(view,x,y)}
        function onChanged() { if(!vela.state.mode) overlay.hide() }
    }
    property Window top: Window {
        width: 380; height: 34; color: root.background
        visible: !!vela.state.mode
        flags: Qt.FramelessWindowHint
        Component.onCompleted: vela.layer(top,"top")
        RowLayout {
            anchors.fill: parent; spacing: 2
            Repeater {
                model: root.modes
                Button {
                    required property string modelData
                    text: modelData; highlighted: vela.state.mode === modelData
                    onClicked: vela.call("setMode",[modelData])
                    Layout.fillWidth: true
                }
            }
            ToolButton {text:"⌕"; ToolTip.text:"Quick Commands · F2"; ToolTip.visible:hovered; onClicked:root.open("commands",0,0)}
            ToolButton {text:"⚙"; onClicked:root.open("settings",0,0)}
        }
    }
    property Window tabs: Window {
        id: tabsWindow
        width: tabsHover.hovered || tabsContent.activeFocus ? 220 : 6
        height: Math.min(Screen.height-100,Math.max(120,((vela.state.desktops || []).length+1)*78))
        color: root.background; visible: !!vela.state.mode
        flags: Qt.FramelessWindowHint
        Component.onCompleted: vela.layer(tabsWindow,"tabs")
        HoverHandler { id: tabsHover }
        ColumnLayout {
            id: tabsContent
            anchors.fill: parent; anchors.margins: 6; visible: tabsWindow.width>6
            Repeater {
                model: vela.state.desktops || []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 70; radius: 8
                    color: modelData.current ? "#74513f" : "#343640"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 5
                        Button {
                            text:modelData.id+"  "+modelData.name+"\n"+modelData.windows.length+" windows"
                            Layout.fillWidth:true
                            onClicked:vela.call("desktop",[modelData.id])
                            ToolTip.text: modelData.windows.join("\n") || "Empty workspace"
                            ToolTip.visible:hovered
                        }
                        ToolButton {text:"⋮"; onClicked: workspaceMenu.popup(); Menu {
                            id: workspaceMenu
                            MenuItem {text:"Rename…"; onTriggered:{rename.workspaceId=modelData.id;renameName.text=modelData.name;rename.open()}}
                            MenuItem {text:"Remove workspace"; enabled:(vela.state.desktops || []).length>1; onTriggered:vela.call("removeDesktop",[modelData.id])}
                        }}
                    }
                }
            }
            Button {text:"+ Workspace"; Layout.fillWidth:true; onClicked:vela.call("addDesktop")}
        }
        Dialog {
            id:rename; property int workspaceId:0; title:"Rename workspace"; modal:true
            standardButtons:Dialog.Ok | Dialog.Cancel
            TextField {id:renameName; placeholderText:"Workspace name"}
            onAccepted:vela.call("renameDesktop",[workspaceId,renameName.text])
        }
    }
    property Window overlay: Window {
        id: overlay
        property string view: "commands"
        property int hot: -1
        color: root.background; flags:Qt.FramelessWindowHint
        title: view === "settings" ? "Vela Settings" : view === "radial" ? "Vela Radial Menu" : "Quick Commands"
        onActiveChanged: if(!active) hide()
        Item {
            anchors.fill:parent; focus:true
            Keys.onEscapePressed:overlay.hide()
            ColumnLayout {
                anchors.fill:parent; anchors.margins:20; visible:overlay.view !== "radial"
                RowLayout {
                    Label {text:overlay.title; font.pixelSize:24; color:"white"; Layout.fillWidth:true}
                    ToolButton {text:"×"; onClicked:overlay.hide()}
                }
                TextField {
                    id:search; visible:overlay.view === "commands"; Layout.fillWidth:true
                    placeholderText:"Search commands…"; onTextChanged:commandList.currentIndex=0
                    Keys.onDownPressed:commandList.incrementCurrentIndex()
                    Keys.onUpPressed:commandList.decrementCurrentIndex()
                    onAccepted:if(commandList.currentItem) root.run(commandList.currentItem.modelData.action)
                }
                ListView {
                    id:commandList; visible:overlay.view === "commands"; Layout.fillWidth:true; Layout.fillHeight:true; clip:true
                    model:root.commands.filter(c=>c.action && c.label.toLowerCase().includes(search.text.toLowerCase()))
                    currentIndex:0; spacing:4
                    delegate:Button {
                        required property var modelData
                        required property int index
                        width:commandList.width; text:modelData.label; highlighted:commandList.currentIndex === index
                        onClicked:root.run(modelData.action)
                    }
                    ScrollBar.vertical:ScrollBar {}
                }
                ScrollView {
                    visible:overlay.view === "settings"; Layout.fillHeight:true; Layout.fillWidth:true
                    contentWidth:availableWidth
                    ColumnLayout {
                        width:parent.width; spacing:12
                        Label {text:"Window layout · current activity"; color:root.accent}
                        ComboBox {model:root.modes; currentIndex:root.modes.indexOf(vela.state.mode); onActivated:vela.call("setMode",[currentText])}
                        Label {text:"Window spacing: "+vela.gap+" px"; color:"white"}
                        SpinBox {from:0; to:40; value:vela.gap; onValueModified:vela.setting("Gap",value)}
                        Switch {text:"Right-button gestures and hold menu"; checked:vela.gestures; onToggled:vela.setting("Gestures",checked)}
                        Label {text:"Gesture stroke threshold: "+vela.threshold+" px"; color:"white"}
                        SpinBox {from:12; to:120; value:vela.threshold; onValueModified:vela.setting("Threshold",value)}
                        Label {text:"Hold right-click for 1 second to open the radial menu.\nShift + right-click bypasses gestures. Escape closes menus."; wrapMode:Text.WordWrap; Layout.fillWidth:true; color:"#dddddd"}
                        Label {text:"Mouse gestures"; color:root.accent}
                        Label {
                            text:"← / →   Previous / next workspace\n↑   Maximize / restore     ↓   Minimize\n↓ →   Close window     ↑ ↓   Cycle layout\n↓ ↑   Terminal     ↑ ←   Activities\n↑ →   Quick Commands\n→ ↑ / ← ↑   Move window to next / previous workspace"
                            color:"white"; wrapMode:Text.WordWrap; Layout.fillWidth:true
                        }
                        Repeater {
                            model:["L","R","U","D","DR","UD","DU","UL","UR","RU","LU"]
                            RowLayout {
                                required property string modelData
                                Label {text:modelData; color:"white"; Layout.preferredWidth:50}
                                ComboBox {
                                    model:root.commands; textRole:"label"; valueRole:"action"; Layout.fillWidth:true
                                    currentIndex:root.commands.findIndex(c=>c.action === vela.bindings[modelData])
                                    onActivated:vela.bind(modelData,currentValue)
                                }
                            }
                        }
                        Label {text:"Keyboard shortcuts"; color:root.accent}
                        Label {text:"F2   Quick Commands\nMeta+Ctrl+Space   Cycle layout\nMeta+Ctrl+R   Radial menu\nMeta+Ctrl+S   Vela Settings\nMeta+Alt+Left / Right   Focus scrollable windows\nMeta+Plus / Minus   Widen / narrow tiled column\nCtrl+Meta+Left / Right   Move column left / right"; color:"white"}
                        Button {text:"Displays, HDR, audio, power and other system settings"; onClicked:vela.launch("system")}
                        Button {text:"Customize keyboard shortcuts"; onClicked:vela.launch("shortcuts")}
                    }
                }
            }
            Item {
                anchors.fill:parent; visible:overlay.view === "radial"
                Label {anchors.centerIn:parent; text:"Vela\n"+vela.state.mode; horizontalAlignment:Text.AlignHCenter; font.pixelSize:20; color:"white"}
                HoverHandler {
                    onPointChanged: {
                        let dx=point.position.x-220, dy=point.position.y-220
                        overlay.hot=Math.hypot(dx,dy)<65 ? -1 : Math.round((Math.atan2(dx,-dy)+2*Math.PI)/(Math.PI/4))%8
                    }
                }
                Repeater {
                    model:root.radialItems
                    Button {
                        required property var modelData
                        required property int index
                        x:220+150*Math.sin(index*Math.PI/4)-width/2
                        y:220-150*Math.cos(index*Math.PI/4)-height/2
                        width:105; height:52; text:modelData.label
                        highlighted:overlay.hot === index
                        onHoveredChanged:if(hovered) overlay.hot=index
                        onClicked:root.run(modelData.action)
                    }
                }
                ToolButton {anchors.right:parent.right; text:"×"; onClicked:overlay.hide()}
            }
        }
    }
}
