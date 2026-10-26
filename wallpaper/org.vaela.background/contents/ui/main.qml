// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.vaela.background

// Vaela's wallpaper: the current workspace's video or picture, crossfaded when workspaces change.
// Workspaces without one, monitors Vaela leaves alone and sessions without Vaela show the picture
// this desktop had before Vaela took it over.
WallpaperItem {
    id: root

    VaelaBackground {id: vaela; screenName: root.Screen.name}

    // Plasma's own resolver handles wallpaper packages and the theme default; it is optional, so a
    // Plasma without it still gets plain picture paths.
    Loader {
        id: resolver
        source: "Fallback.qml"
        onLoaded: {
            item.source = Qt.binding(() => root.configuration.Fallback)
            item.targetSize = Qt.binding(() => Qt.size(root.width * Screen.devicePixelRatio, root.height * Screen.devicePixelRatio))
        }
    }
    readonly property string fallback: {
        if (resolver.item && resolver.item.resolved.toString() !== "") return resolver.item.resolved.toString()
        const path = root.configuration.Fallback || ""
        return path.startsWith("/") ? "file://" + path : path
    }
    // Backgrounds that would not load; their workspace shows the fallback until it changes.
    property var broken: ({})
    readonly property string wanted: {
        const source = vaela.source.toString()
        return source !== "" && !broken[source] ? source : fallback
    }
    // Where each video was, so returning to a workspace carries on rather than starting over.
    property var positions: ({})
    property Item front: null

    // VaelaBackground has one change signal for everything, so these give the parts their own.
    readonly property string source: vaela.source.toString()
    readonly property string workspace: vaela.workspace
    onSourceChanged: broken = {}
    onWantedChanged: Qt.callLater(show)
    onWorkspaceChanged: Qt.callLater(show)
    Component.onCompleted: show()

    function show() {
        const back = front === first ? second : first
        if (front && front.source.toString() === wanted) {
            // The same background, maybe on another workspace with options of its own; or switched
            // back before the other one was ready, which then stops loading.
            front.owner = vaela.workspace
            if (!fade.running && back.source.toString() !== "") back.unload()
            return
        }
        if (back.source.toString() === wanted) {
            back.owner = vaela.workspace
            return
        }
        back.load(wanted, positions[wanted] || 0, vaela.workspace)
    }
    function reveal(layer) {
        if (layer === front || layer.source.toString() !== wanted) return
        if (fade.running) fade.complete()
        const old = front
        front = layer
        layer.z = 1
        if (old) old.z = 0
        fade.old = old
        fadeIn.target = layer
        fadeOut.target = old
        fade.start()
    }
    function failed(layer) {
        const source = layer.source.toString()
        layer.unload()
        if (source === fallback) return
        broken[source] = true
        brokenChanged()
    }

    ParallelAnimation {
        id: fade
        property Item old
        NumberAnimation {id: fadeIn; property: "opacity"; from: 0; to: 1; duration: vaela.transition; easing.type: Easing.InOutQuad}
        // The old video's sound fades with it rather than stopping at the end.
        NumberAnimation {id: fadeOut; property: "audible"; from: 1; to: 0; duration: vaela.transition}
        onFinished: {
            if (!old) return
            if (old.kind === "video") root.positions[old.source.toString()] = old.position()
            old.unload()
            old = null
        }
    }

    Rectangle {anchors.fill: parent; color: "black"}
    Layer {id: first; background: vaela; onReady: root.reveal(first); onFailed: root.failed(first)}
    Layer {id: second; background: vaela; onReady: root.reveal(second); onFailed: root.failed(second)}
}
