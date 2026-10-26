// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.wallpapers.image as Wallpaper

// The desktop's previous picture, resolved like Plasma's image wallpaper does it: a wallpaper
// package gives the size closest to the monitor, and an empty setting gives the theme's default.
Item {
    property alias source: proxy.source
    property alias targetSize: proxy.targetSize
    readonly property url resolved: proxy.modelImage
    Wallpaper.MediaProxy {id: proxy}
}
