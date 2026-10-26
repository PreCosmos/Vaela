// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
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
    signal ready()
    signal failed()
    anchors.fill: parent
    opacity: 0

    readonly property int imageFill: background.fill === "fit" ? Image.PreserveAspectFit : background.fill === "stretch" ? Image.Stretch : Image.PreserveAspectCrop

    function load(url, position) {
        unload()
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
    Connections {
        target: media.background
        function onChanged() {media.update()}
    }

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
        speed: media.background.speed
        onStatusChanged: {
            if (status === AnimatedImage.Ready) media.shown = true
            else if (status === AnimatedImage.Error) media.failed()
        }
    }
    VideoOutput {
        id: output
        anchors.fill: parent
        visible: media.kind === "video"
        fillMode: media.background.fill === "fit" ? VideoOutput.PreserveAspectFit
                : media.background.fill === "stretch" ? VideoOutput.Stretch : VideoOutput.PreserveAspectCrop
    }
    MediaPlayer {
        id: player
        source: media.kind === "video" ? media.source : ""
        videoOutput: output
        // Squared, since loudness follows the square of the level more closely than the level.
        audioOutput: AudioOutput {
            volume: media.background.volume * media.background.volume * media.opacity * media.audible
            muted: media.background.volume === 0
        }
        loops: MediaPlayer.Infinite
        playbackRate: media.background.speed
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
