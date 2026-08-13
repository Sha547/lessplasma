// Album art with genuinely rounded corners.
//
// Putting an Image inside a Rectangle with `radius` and `clip: true` does not
// work, because clipping is rectangular and ignores the radius. That leaves the cover
// with hard square corners sitting inside a rounded card. Masking is the only
// way to actually round the image.
//
// Note the content is drawn through `layer.effect` rather than being hidden and
// fed to a MultiEffect as `source`: an item with `visible: false` gets no
// scene-graph updates, so the captured texture goes stale and never shows art
// that finishes loading after the first frame, which is always, since the
// cover URL only arrives once the player has been polled. The masks use
// `opacity: 0` for the same reason: they must keep updating so a corner-radius
// change actually takes effect.
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: art

    property string artUrl: ""
    property real cornerRadius: 12
    property real placeholderSize: 24

    readonly property bool hasArt: artUrl.length > 0

    Item {
        id: mask
        anchors.fill: parent
        opacity: 0
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: art.cornerRadius
            color: "black"
        }
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            autoPaddingEnabled: false
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        Image {
            anchors.fill: parent
            source: art.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: art.hasArt
        }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: art.placeholderSize
        height: width
        source: "media-optical-audio"
        visible: !art.hasArt
        opacity: 0.5
    }
}
