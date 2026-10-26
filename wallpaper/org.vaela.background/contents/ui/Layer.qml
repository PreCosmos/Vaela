// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Effects
import QtMultimedia

// One background: a picture, an animated picture or a looping video. It says when it can be seen,
// so the wallpaper only fades it in once there is something to show.
Item {
    id: media
    required property QtObject background
    property url source
    property string kind
    property int startAt: 0
    property bool shown: false
    property real audible: 1
    // The workspace this background belongs to. Its options follow the settings only while that
    // workspace is current, so one fading out keeps its own scaling, dim, blur and sound.
    property string owner
    property var options: ({fill: "fill", volume: 0, speed: 1, dim: 0, blur: 0})
    signal ready()
    signal failed()
    anchors.fill: parent
    opacity: 0

    readonly property int imageFill: options.fill === "fit" ? Image.PreserveAspectFit : options.fill === "stretch" ? Image.Stretch : Image.PreserveAspectCrop

    function load(url, position, workspace) {
        unload()
        owner = workspace
        follow()
        kind = background.kind(url)
        startAt = position
        source = url
        update()
    }
    function unload() {
        player.stop()
        source = ""
        kind = ""
        shown = false
        opacity = 0
        audible = 1
    }
    function position() {return player.position}
    function follow() {
        if (owner === background.workspace)
            options = {fill: background.fill, volume: background.volume, speed: background.speed, dim: background.dim, blur: background.blur}
    }
    // A paused video still plays up to its first frame, so it can be shown.
    function update() {
        if (kind !== "video" || source.toString() === "") return
        if (background.playing || !shown) player.play()
        else player.pause()
    }
    onShownChanged: {
        update()
        if (shown) ready()
    }
    onOwnerChanged: follow()
    Connections {
        target: media.background
        function onChanged() {
            media.follow()
            media.update()
        }
    }

    Item {
        id: content
        anchors.fill: parent
        layer.enabled: media.options.blur > 0
        layer.effect: MultiEffect {blurEnabled: true; blur: media.options.blur; blurMax: 64; autoPaddingEnabled: false}
        Image {
            anchors.fill: parent
            visible: media.kind === "image"
            source: visible ? media.source : ""
            asynchronous: true
            cache: false
            fillMode: media.imageFill
            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
            onStatusChanged: {
                if (status === Image.Ready) media.shown = true
                else if (status === Image.Error) media.failed()
            }
        }
        AnimatedImage {
            anchors.fill: parent
            visible: media.kind === "animated"
            source: visible ? media.source : ""
            cache: false
            fillMode: media.imageFill
            playing: media.background.playing
            speed: media.options.speed
            onStatusChanged: {
                if (status === AnimatedImage.Ready) media.shown = true
                else if (status === AnimatedImage.Error) media.failed()
            }
        }
        VideoOutput {
            id: output
            anchors.fill: parent
            visible: media.kind === "video"
            fillMode: media.options.fill === "fit" ? VideoOutput.PreserveAspectFit
                    : media.options.fill === "stretch" ? VideoOutput.Stretch : VideoOutput.PreserveAspectCrop
        }
    }
    Rectangle {anchors.fill: parent; color: "black"; opacity: media.options.dim}

    // Qt keeps a player on the device that was the default when it started; following the default
    // moves the sound when Plasma's output changes, say to headphones.
    MediaDevices {id: devices}
    MediaPlayer {
        id: player
        source: media.kind === "video" ? media.source : ""
        videoOutput: output
        // Squared, since loudness follows the square of the level more closely than the level.
        audioOutput: AudioOutput {
            device: devices.defaultAudioOutput
            volume: media.options.volume * media.options.volume * media.opacity * media.audible
            muted: media.options.volume === 0
        }
        loops: MediaPlayer.Infinite
        playbackRate: media.options.speed
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && media.startAt > 0 && duration > 0) setPosition(media.startAt % duration)
            if (mediaStatus === MediaPlayer.InvalidMedia) media.failed()
        }
        onErrorOccurred: media.failed()
    }
    Connections {
        target: output.videoSink
        function onVideoFrameChanged() {if (!media.shown && media.kind === "video") media.shown = true}
    }
}
