// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: editor
    property string page: "menu"
    property string editId: ""
    property string editType: "command"
    property color accent: Theme.accent
    function edit(entry) {
        editId=entry.id; editType=entry.type
        entryName.text=entry.label; command.text=entry.target
        iconName.text=entry.icon; terminal.checked=entry.terminal || false
        radial.clearError();page="command"
    }
    function newCommand() {
        editId="";editType="command";entryName.text="";command.text=""
        iconName.text="utilities-terminal";terminal.checked=false
        radial.clearError();page="command"
    }
    ColumnLayout {
        anchors.fill:parent;spacing:10
        RowLayout {
            VButton {text:"Back"; iconName:"go-previous"; flat:true; visible:editor.page!=="menu"; onClicked:{editor.page="menu";radial.clearError()}}
            Label {
                text:editor.page==="apps"?"Choose an installed application":editor.page==="command"?(editor.editId?"Edit menu item":"Add Command"):"Your radial menu"
                color:Theme.text;font.pixelSize:16;font.weight:Font.DemiBold;Layout.fillWidth:true
            }
        }
        Label {text:radial.error; visible:text.length>0; color:Theme.danger;wrapMode:Text.WordWrap;Layout.fillWidth:true}
        RowLayout {
            visible:editor.page==="menu"
            VButton {objectName:"addApplication";text:"Add Application";iconName:"list-add";accent:true;onClicked:{radial.clearError();radial.refreshApplications();appSearch.text="";editor.page="apps";appSearch.forceActiveFocus()}}
            VButton {objectName:"addCommand";text:"Add Command";iconName:"dialog-scripts";onClicked:editor.newCommand()}
        }
        Label {
            visible:editor.page==="menu";text:"Changes save immediately. Up to eight items appear on each radial page."
            color:Theme.muted;wrapMode:Text.WordWrap;Layout.fillWidth:true
        }
        ListView {
            id:menuList
            visible:editor.page==="menu";Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:5
            model:radial.entries
            delegate:Rectangle {
                required property var modelData
                required property int index
                width:menuList.width;height:64;radius:Theme.radius;color:Theme.surface;border.color:Theme.border
                RowLayout {
                    anchors.fill:parent;anchors.leftMargin:12;anchors.rightMargin:8;spacing:10
                    Image {source:modelData.type==="builtin"?Theme.icon(modelData.icon,Theme.text):Theme.appIcon(modelData.icon);sourceSize.width:36;sourceSize.height:36;Layout.preferredWidth:36;Layout.preferredHeight:36}
                    ColumnLayout {
                        Layout.fillWidth:true;spacing:2
                        Label {text:modelData.label;color:Theme.text;font.pixelSize:13;elide:Text.ElideRight;Layout.fillWidth:true}
                        Label {text:modelData.type==="application"?"Application":modelData.type==="command"?"Command":"Desktop action";color:Theme.muted;font.pixelSize:11}
                    }
                    VButton {iconName:"go-up";flat:true;implicitWidth:30;enabled:index>0;Accessible.name:"Move "+modelData.label+" up";onClicked:radial.move(modelData.id,-1)}
                    VButton {iconName:"go-down";flat:true;implicitWidth:30;enabled:index<radial.entries.length-1;Accessible.name:"Move "+modelData.label+" down";onClicked:radial.move(modelData.id,1)}
                    VButton {text:"Edit";onClicked:editor.edit(modelData)}
                    VButton {iconName:"edit-delete";flat:true;implicitWidth:30;Accessible.name:"Remove "+modelData.label;onClicked:radial.remove(modelData.id)}
                }
            }
            Label {anchors.centerIn:parent;visible:radial.entries.length===0;text:"Your menu is empty. Add an application or command above.";color:Theme.muted;width:parent.width;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter}
            ScrollBar.vertical:ScrollBar {}
        }
        TextField {
            id:appSearch;visible:editor.page==="apps";Layout.fillWidth:true
            placeholderText:"Search applications…"
        }
        ListView {
            id:appsList
            visible:editor.page==="apps";Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:4
            model:radial.applications.filter(app=>(app.label+" "+app.description).toLowerCase().includes(appSearch.text.toLowerCase()))
            delegate:ItemDelegate {
                id:appOption
                required property var modelData
                background:Rectangle {radius:Theme.radius;color:appOption.hovered?Theme.surfaceHover:Theme.surface}
                objectName:"app-"+modelData.id
                width:appsList.width;height:62
                onClicked:if(radial.addApplication(modelData.id)) editor.page="menu"
                contentItem:RowLayout {
                    Image {source:"image://menuicons/"+encodeURIComponent(modelData.icon);sourceSize.width:36;sourceSize.height:36;Layout.preferredWidth:36;Layout.preferredHeight:36}
                    ColumnLayout {
                        Layout.fillWidth:true
                        Label {text:modelData.label;color:Theme.text;elide:Text.ElideRight;Layout.fillWidth:true}
                        Label {text:modelData.description;color:Theme.muted;elide:Text.ElideRight;Layout.fillWidth:true;font.pixelSize:11}
                    }
                    Label {text:"+ Add";color:editor.accent}
                }
            }
            Label {anchors.centerIn:parent;visible:appsList.count===0;text:"No matching applications";color:Theme.muted}
            ScrollBar.vertical:ScrollBar {}
        }
        ScrollView {
            visible:editor.page==="command";Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth
            ColumnLayout {
                width:parent.width;spacing:10
                Label {text:"Name";color:Theme.text}
                TextField {id:entryName;objectName:"entryName";Layout.fillWidth:true;placeholderText:"e.g. Start my workspace"}
                Label {text:"Shell command";color:Theme.text;visible:editor.editType==="command"}
                TextArea {id:command;objectName:"command";visible:editor.editType==="command";Layout.fillWidth:true;Layout.preferredHeight:74;placeholderText:"e.g. konsole --workdir ~/Projects";wrapMode:TextEdit.Wrap}
                CheckBox {id:terminal;visible:editor.editType==="command";text:"Run in a terminal"}
                Label {text:"Image or system icon";color:Theme.text}
                RowLayout {
                    Image {source:"image://menuicons/"+encodeURIComponent(iconName.text);sourceSize.width:48;sourceSize.height:48;Layout.preferredWidth:48;Layout.preferredHeight:48}
                    TextField {id:iconName;objectName:"iconName";Layout.fillWidth:true;placeholderText:"System icon name or image path"}
                    VButton {text:"Choose Image…";iconName:"document-open";onClicked:imagePicker.open()}
                }
                Label {text:"Choose a system icon below, or select your own image. Imported images are copied into your Vaela data folder.";color:Theme.muted;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                Flow {
                    Layout.fillWidth:true;spacing:6
                    Repeater {
                        model:["utilities-terminal","application-x-executable","internet-web-browser","system-file-manager","document-edit","applications-games","multimedia-player","system-run","preferences-system","folder","camera-photo","system-search"]
                        ToolButton {
                            required property string modelData
                            width:46;height:46;Accessible.name:modelData
                            ToolTip.text:modelData;ToolTip.visible:hovered
                            contentItem:Image {source:"image://menuicons/"+encodeURIComponent(modelData);sourceSize.width:28;sourceSize.height:28;fillMode:Image.PreserveAspectFit}
                            onClicked:iconName.text=modelData
                        }
                    }
                }
                VButton {
                    objectName:"saveEntry";accent:true;text:editor.editId?"Save Changes":"Add Command"
                    enabled:entryName.text.trim().length>0 && (editor.editType!=="command" || command.text.trim().length>0)
                    onClicked: {
                        let saved=editor.editId?radial.update(editor.editId,entryName.text,iconName.text,command.text,terminal.checked):radial.addCommand(entryName.text,command.text,iconName.text,terminal.checked)
                        if(saved) editor.page="menu"
                    }
                }
            }
        }
    }
    FileDialog {
        id:imagePicker
        title:"Choose a menu image"
        nameFilters:["Images (*.png *.jpg *.jpeg *.svg *.webp *.bmp)"]
        options:FileDialog.DontUseNativeDialog
        onAccepted:iconName.text=selectedFile.toString()
    }
}
