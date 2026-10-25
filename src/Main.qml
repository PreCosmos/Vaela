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
    function runRadial(entry) {
        if(entry.type === "builtin") run(entry.target)
        else {overlay.hide();radial.launch(entry.id)}
    }
    function open(view,x,y) {
        if(view === "dismiss") {overlay.hide();return}
        if(view === "radial-release") {
            if(overlay.visible && overlay.view === "radial" && overlay.hot >= 0) runRadial(radialItems[overlay.hot])
            return
        }
        overlay.hide(); overlay.view=view; overlay.hot=-1; overlay.radialPage=0; search.text=""
        if(view === "radial-settings") radialEditor.page="menu"
        overlay.width=view === "radial" ? 440 : 620
        overlay.height=view === "radial" ? 440 : 580
        vela.layer(overlay,"overlay",x || Screen.width/2,y || Screen.height/2)
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
        target: vela
        function onRequested(view,x,y) {root.open(view,x,y)}
        function onChanged() { if(!vela.state.mode) overlay.hide() }
    }
    property Window top: Window {
        width: 460; height: 34; color: root.background
        visible: !!vela.state.mode
        flags: Qt.FramelessWindowHint
        Component.onCompleted: vela.layer(top,"top")
        RowLayout {
            anchors.fill: parent; spacing: 2
            Repeater {
                model: root.modes
                Button {
                    required property string modelData
                    Layout.minimumWidth:60
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
        property bool expanded:false
        property int openMenus:0
        width: expanded || openMenus>0 || rename.visible ? 220 : 6
        height: Math.min(Screen.height-100,Math.max(120,(vela.state.desktops || []).length*76+54))
        color: root.background; visible: !!vela.state.mode
        flags: Qt.FramelessWindowHint
        Component.onCompleted: vela.layer(tabsWindow,"tabs")
        HoverHandler {
            id:tabsHover
            onHoveredChanged:if(hovered) {collapse.stop();tabsWindow.expanded=true} else collapse.restart()
        }
        Timer {id:collapse;interval:250;onTriggered:if(!tabsHover.hovered && !tabsWindow.openMenus && !rename.visible) tabsWindow.expanded=false}
        ScrollView {
            anchors.fill:parent;anchors.margins:6;visible:tabsWindow.width>6
            contentWidth:availableWidth
        Column {
            id:tabsContent
            width:parent.width;spacing:6
            Repeater {
                model: vela.state.desktops || []
                delegate: Rectangle {
                    required property var modelData
                    width:tabsContent.width;height:70;radius:8
                    color: modelData.current ? "#74513f" : "#343640"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 5
                        Button {
                            text:modelData.id+"  "+modelData.name+"\n"+modelData.mode+" · "+modelData.windows.length+" windows"
                            Layout.fillWidth:true
                            onClicked:vela.call("desktop",[modelData.id])
                            ToolTip.text: modelData.windows.join("\n") || "Empty workspace"
                            ToolTip.visible:hovered
                        }
                        ToolButton {text:"⋮"; onClicked: workspaceMenu.popup(); Menu {
                            id: workspaceMenu
                            onOpened:++tabsWindow.openMenus
                            onClosed:{--tabsWindow.openMenus;collapse.restart()}
                            MenuItem {text:"Rename…"; onTriggered:{rename.workspaceId=modelData.id;renameName.text=modelData.name;rename.open();tabsWindow.requestActivate();renameName.forceActiveFocus()}}
                            MenuItem {text:"Remove workspace"; enabled:(vela.state.desktops || []).length>1; onTriggered:vela.call("removeDesktop",[modelData.id])}
                        }}
                    }
                }
            }
            Button {text:"+ Workspace";width:tabsContent.width;height:36;onClicked:vela.call("addDesktop")}
        }
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
        property int radialPage: 0
        color: root.background; flags:Qt.FramelessWindowHint
        title: view === "radial-settings" ? "Radial Menu Settings" : view === "settings" ? "Vela Settings" : view === "radial" ? "Vela Radial Menu" : "Quick Commands"
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
                RadialEditor {
                    id:radialEditor
                    visible:overlay.view === "radial-settings";Layout.fillWidth:true;Layout.fillHeight:true
                }
                ScrollView {
                    visible:overlay.view === "settings"; Layout.fillHeight:true; Layout.fillWidth:true
                    contentWidth:availableWidth
                    ColumnLayout {
                        width:parent.width; spacing:12
                        Button {text:"Customize Radial Menu…";onClicked:root.open("radial-settings",0,0)}
                        Label {text:"Window layout · current workspace"; color:root.accent}
                        ComboBox {model:root.modes; currentIndex:root.modes.indexOf(vela.state.mode); onActivated:vela.call("setMode",[currentText])}
                        Label {text:"Window spacing: "+vela.gap+" px"; color:"white"}
                        SpinBox {from:0; to:40; value:vela.gap; onValueModified:vela.setting("Gap",value)}
                        Switch {text:"Right-button gestures and hold menu"; checked:vela.gestures; onToggled:vela.setting("Gestures",checked)}
                        Label {text:"Gesture stroke threshold: "+vela.threshold+" px"; color:"white"}
                        SpinBox {from:12; to:120; value:vela.threshold; onValueModified:vela.setting("Threshold",value)}
                        Label {text:"Hold right-click: context menu at 0.25 s, hidden at 0.75 s, radial menu at 1 s.\nShift + right-click bypasses gestures. Escape closes menus."; wrapMode:Text.WordWrap; Layout.fillWidth:true; color:"#dddddd"}
                        Label {text:"Mouse gestures"; color:root.accent}
                        Label {
                            text:"← / →   Previous / next workspace\n↑   Maximize / restore     ↓   Close window\n↓ →   Close window     ↑ ↓   Cycle layout\n↓ ↑   Terminal     ↑ ←   Activities\n↑ →   Quick Commands\n→ ↑ / ← ↑   Move window to next / previous workspace"
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
                Column {
                    anchors.centerIn:parent;spacing:8;width:140
                    Label {width:parent.width;text:overlay.hot>=0 && root.radialItems[overlay.hot]?root.radialItems[overlay.hot].label:"Vela";horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap;font.pixelSize:20;color:"white"}
                    Label {width:parent.width;text:radial.entries.length?(vela.state.mode || "Vela"):"Add your first item";horizontalAlignment:Text.AlignHCenter;color:"#c9c9d2"}
                }
                HoverHandler {
                    onPointChanged: {
                        let dx=point.position.x-220, dy=point.position.y-220, count=root.radialItems.length
                        overlay.hot=Math.hypot(dx,dy)<70 || Math.hypot(dx,dy)>190 || !count ? -1 : Math.round((Math.atan2(dx,-dy)+2*Math.PI)/(2*Math.PI/count))%count
                    }
                }
                Repeater {
                    model:root.radialItems
                    Item {
                        required property var modelData
                        required property int index
                        x:220+145*Math.sin(index*2*Math.PI/Math.max(1,root.radialItems.length))-width/2
                        y:220-145*Math.cos(index*2*Math.PI/Math.max(1,root.radialItems.length))-32
                        width:110;height:100
                        Button {
                            id:radialButton
                            anchors.horizontalCenter:parent.horizontalCenter;width:64;height:64
                            Accessible.name:modelData.label
                            background:Rectangle {radius:32;color:overlay.hot===index?root.accent:"#3a3d4b";border.color:overlay.hot===index?"#f7c6a6":"#55596a";border.width:2}
                            contentItem:Image {source:"image://menuicons/"+encodeURIComponent(modelData.icon);sourceSize.width:36;sourceSize.height:36;fillMode:Image.PreserveAspectFit;anchors.centerIn:parent;anchors.margins:14}
                            onHoveredChanged:if(hovered) overlay.hot=index
                            onClicked:root.runRadial(modelData)
                        }
                        Label {anchors.top:radialButton.bottom;anchors.topMargin:4;width:parent.width;text:modelData.label;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;color:"white";font.pixelSize:12}
                    }
                }
                Row {
                    anchors.bottom:parent.bottom;anchors.bottomMargin:8;anchors.horizontalCenter:parent.horizontalCenter;spacing:8
                    ToolButton {text:"‹";visible:radial.entries.length>8;enabled:overlay.radialPage>0;onClicked:{overlay.hot=-1;--overlay.radialPage}}
                    Label {text:(overlay.radialPage+1)+" / "+Math.ceil(radial.entries.length/8);visible:radial.entries.length>8;color:"white";anchors.verticalCenter:parent.verticalCenter}
                    ToolButton {text:"›";visible:radial.entries.length>8;enabled:(overlay.radialPage+1)*8<radial.entries.length;onClicked:{overlay.hot=-1;++overlay.radialPage}}
                    ToolButton {text:"⚙";Accessible.name:"Customize radial menu";onClicked:root.open("radial-settings",0,0)}
                }
                ToolButton {anchors.right:parent.right;text:"×";Accessible.name:"Close radial menu";onClicked:overlay.hide()}
            }
        }
    }
}
