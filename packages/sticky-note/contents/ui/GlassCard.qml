// Frosted-glass card.
//
// KWin's blur effect cannot help here: a desktop plasmoid lives inside the same
// plasmashell window that paints the wallpaper, so there is nothing "behind" it
// to composite. Instead we sample the wallpaper image ourselves, align it to this
// card's absolute screen position, blur it, and mask it to the card shape. That
// gives a real frosted pane regardless of what the wallpaper is.
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import org.kde.plasma.plasma5support as P5Support

Item {
    id: glass

    property real cornerRadius: 20
    property real blurAmount: 1.0
    property real tintOpacity: 0.42
    property color tintColor: "#0d0d10"
    // How far the edge ring magnifies the backdrop. This is what reads as refraction.
    property real refractionScale: 1.06
    property real refractionRing: 6

    default property alias cardContent: contentHolder.data

    property string wallpaperUrl: ""
    property real offX: 0
    property real offY: 0

    function syncPosition() {
        var p = glass.mapToGlobal(0, 0);
        glass.offX = p.x - Screen.virtualX;
        glass.offY = p.y - Screen.virtualY;
    }

    onXChanged: syncPosition()
    onYChanged: syncPosition()
    onWidthChanged: syncPosition()
    onHeightChanged: syncPosition()
    Component.onCompleted: syncPosition()

    // The widget can be dragged around the desktop without emitting x/y changes
    // here, so re-check its screen position periodically to keep the crop aligned.
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: glass.syncPosition()
    }

    P5Support.DataSource {
        id: wallpaperDS
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var p = (data.stdout || "").trim();
                if (p.length > 0) glass.wallpaperUrl = p;
            }
            disconnectSource(sourceName);
        }

        Component.onCompleted: {
            connectSource("grep -m1 '^Image=' \"$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc\" 2>/dev/null | cut -d= -f2-");
        }
    }

    // ---- backdrop sources (rendered offscreen, never shown directly) ----

    Component {
        id: wallpaperCrop
        Image {
            property real zoom: 1.0
            source: glass.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            // Half-res is plenty once blurred, and keeping sourceSize identical in
            // every widget lets Qt share one decoded texture across the whole pack.
            sourceSize: Qt.size(Math.round(Screen.width / 2), Math.round(Screen.height / 2))
            width: Screen.width
            height: Screen.height
            x: -glass.offX - (glass.width * (zoom - 1)) / 2
            y: -glass.offY - (glass.height * (zoom - 1)) / 2
            scale: zoom
            transformOrigin: Item.TopLeft
        }
    }

    Item {
        id: backdropSource
        anchors.fill: parent
        visible: false
        clip: true
        Loader { sourceComponent: wallpaperCrop }
    }

    Item {
        id: refractSource
        anchors.fill: parent
        visible: false
        clip: true
        Loader {
            sourceComponent: wallpaperCrop
            onLoaded: item.zoom = glass.refractionScale
        }
    }

    // ---- masks ----

    Item {
        id: cardMask
        anchors.fill: parent
        // opacity rather than visible: an invisible item gets no scene-graph
        // updates, so the mask texture would go stale and a corner-radius
        // change would never reach the screen.
        opacity: 0
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: glass.cornerRadius
            color: "black"
        }
    }

    Item {
        id: ringMask
        anchors.fill: parent
        // opacity rather than visible: an invisible item gets no scene-graph
        // updates, so the mask texture would go stale and a corner-radius
        // change would never reach the screen.
        opacity: 0
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: glass.cornerRadius
            color: "transparent"
            border.width: glass.refractionRing
            border.color: "black"
        }
    }

    // ---- the glass itself ----

    MultiEffect {
        anchors.fill: parent
        source: backdropSource
        blurEnabled: true
        blur: glass.blurAmount
        blurMax: 64
        blurMultiplier: 1.4
        saturation: 0.15
        maskEnabled: true
        maskSource: cardMask
        autoPaddingEnabled: false
    }

    // Magnified, less-blurred backdrop confined to the border ring: light bending
    // through the thick edge of a real pane of glass.
    MultiEffect {
        anchors.fill: parent
        source: refractSource
        blurEnabled: true
        blur: glass.blurAmount * 0.5
        blurMax: 64
        blurMultiplier: 1.0
        brightness: 0.05
        saturation: 0.35
        maskEnabled: true
        maskSource: ringMask
        autoPaddingEnabled: false
        opacity: 0.7
    }

    Rectangle {
        anchors.fill: parent
        radius: glass.cornerRadius
        color: glass.tintColor
        opacity: glass.tintOpacity
    }

    // Specular sheen, brighter at the top edge and falling away toward the bottom.
    Rectangle {
        anchors.fill: parent
        radius: glass.cornerRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.13) }
            GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.03) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.12) }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: glass.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.28)
    }

    Item {
        id: contentHolder
        anchors.fill: parent
        clip: true
    }
}
