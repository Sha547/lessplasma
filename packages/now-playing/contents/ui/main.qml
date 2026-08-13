import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property string service: ""
    property string status: ""
    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property real position: 0      // seconds
    property real duration: 0      // seconds

    readonly property bool hasTrack: title.length > 0 || artist.length > 0
    readonly property bool playing: status === "Playing"

    function fmtTime(s) {
        if (!s || s < 0) s = 0;
        var m = Math.floor(s / 60);
        var sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    // MPRIS metadata arrives from qdbus as "key: value"; list-valued fields such as
    // xesam:artist come wrapped in braces, so strip that decoration off.
    function clean(v) {
        return (v || "").replace(/^\{|\}$/g, "").replace(/^"|"$/g, "").trim();
    }

    P5Support.DataSource {
        id: poll
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var raw = (data.stdout || "").trim();
                if (raw.length === 0) {
                    root.service = "";
                    root.status = "";
                    root.title = "";
                    root.artist = "";
                    root.album = "";
                    root.artUrl = "";
                    root.position = 0;
                    root.duration = 0;
                } else {
                    var info = {};
                    raw.split("\n").forEach(function (line) {
                        var i = line.indexOf("=");
                        if (i < 0) return;
                        info[line.substr(0, i)] = line.substr(i + 1);
                    });
                    root.service = info["svc"] || "";
                    root.status = info["status"] || "";
                    root.title = root.clean(info["xesam:title"]);
                    root.artist = root.clean(info["xesam:artist"]);
                    root.album = root.clean(info["xesam:album"]);
                    root.artUrl = root.clean(info["mpris:artUrl"]);
                    root.position = (parseInt(info["pos"]) || 0) / 1000000;
                    root.duration = (parseInt(info["mpris:length"]) || 0) / 1000000;
                }
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            var cmd =
                'QD=$(command -v qdbus6 || command -v qdbus); [ -z "$QD" ] && exit 0; ' +
                'SVC=""; ST=""; ' +
                // qdbus indents its service list, so strip leading whitespace
                // before anchoring the match.
                'for s in $($QD 2>/dev/null | sed "s/^[[:space:]]*//" | grep "^org\\.mpris\\.MediaPlayer2\\."); do ' +
                '  st=$($QD "$s" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlaybackStatus 2>/dev/null); ' +
                '  if [ "$st" = "Playing" ]; then SVC="$s"; ST="$st"; break; fi; ' +
                '  if [ -z "$SVC" ]; then SVC="$s"; ST="$st"; fi; ' +
                'done; ' +
                '[ -z "$SVC" ] && exit 0; ' +
                'echo "svc=$SVC"; echo "status=$ST"; ' +
                'echo "pos=$($QD "$SVC" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Position 2>/dev/null)"; ' +
                '$QD "$SVC" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Metadata 2>/dev/null | sed "s/: /=/"';
            connectSource(cmd);
        }
    }

    P5Support.DataSource {
        id: control
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName) => {
            disconnectSource(sourceName);
            poll.refresh();
        }

        function send(method) {
            if (!root.service) return;
            var qd = "$(command -v qdbus6 || command -v qdbus)";
            connectSource(qd + " " + root.service +
                          " /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player." + method);
        }
    }

    Timer {
        interval: plasmoid.configuration.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.refresh()
    }

    toolTipMainText: root.hasTrack ? root.title : "Now Playing"
    toolTipSubText: root.hasTrack ? root.artist : "Nothing playing"

    fullRepresentation: Item {
        id: view

        // Square by default, because cover art is the point of this widget. Stretch it
        // wide and it rearranges into a row; anything near 1:1 keeps the poster
        // layout with the art on top and controls underneath.
        Layout.preferredWidth: 220
        Layout.preferredHeight: 220
        Layout.minimumWidth: 160
        Layout.minimumHeight: 150

        readonly property bool wide: width > height * 1.35

        // In poster mode the art takes whatever is left after the text and
        // controls have had their share, clamped so it stays square.
        readonly property real artSide: Math.max(0, Math.min(width - 56, height - 140))

        GlassCard {
            id: card
            anchors.fill: parent
            anchors.margins: 10
            cornerRadius: Math.min(plasmoid.configuration.cornerRadius, height / 2)
            blurAmount: plasmoid.configuration.glassBlur
            tintOpacity: plasmoid.configuration.glassTintOpacity

            // Cover art, blurred and masked to the card, so the album becomes the
            // backdrop the rest of the widget sits on.
            Item {
                id: artSource
                anchors.fill: parent
                visible: false
                Image {
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
            }

            Item {
                id: artMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: card.cornerRadius
                    color: "black"
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: artSource
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                blurMultiplier: 1.2
                brightness: -0.2
                saturation: 0.25
                maskEnabled: true
                maskSource: artMask
                autoPaddingEnabled: false
                visible: plasmoid.configuration.artBackdrop && root.artUrl.length > 0
                opacity: 0.55
            }

            // ---- poster layout (square-ish) ----
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6
                visible: !view.wide && root.hasTrack

                RoundedArt {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: view.artSide
                    Layout.preferredHeight: view.artSide
                    // Concentric with the card: same centre of curvature, inset by
                    // the gap between the cover and the card edge.
                    cornerRadius: Math.max(0, card.cornerRadius - 14)
                    placeholderSize: Math.min(32, view.artSide * 0.4)
                    artUrl: root.artUrl
                    // Below about this size the cover reads as a smudge, so drop it
                    // and give the text the room instead.
                    visible: plasmoid.configuration.showArt && view.artSide >= 40
                }

                Text {
                    text: root.title || "Unknown track"
                    color: "white"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                }

                Text {
                    text: root.artist
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.artist.length > 0
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    height: 3
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.15)
                    visible: root.duration > 0

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.position / root.duration))
                        height: parent.height
                        radius: parent.radius
                        color: plasmoid.configuration.accentColorHex
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    spacing: 16

                    Repeater {
                        model: [
                            { icon: "media-skip-backward", method: "Previous", size: 16 },
                            { icon: root.playing ? "media-playback-pause" : "media-playback-start", method: "PlayPause", size: 24 },
                            { icon: "media-skip-forward", method: "Next", size: 16 }
                        ]

                        delegate: Kirigami.Icon {
                            required property var modelData
                            source: modelData.icon
                            width: modelData.size
                            height: modelData.size
                            color: "white"
                            opacity: posterHover.containsMouse ? 1.0 : 0.7

                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            MouseArea {
                                id: posterHover
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: control.send(modelData.method)
                            }
                        }
                    }
                }
            }

            // ---- row layout (stretched wide) ----
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14
                visible: view.wide && root.hasTrack

                RoundedArt {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: Math.max(0, card.cornerRadius - 14)
                    placeholderSize: 24
                    artUrl: root.artUrl
                    visible: plasmoid.configuration.showArt
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        text: root.title || "Unknown track"
                        color: "white"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.artist
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        visible: root.artist.length > 0
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        height: 3
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.15)
                        visible: root.duration > 0

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.position / root.duration))
                            height: parent.height
                            radius: parent.radius
                            color: plasmoid.configuration.accentColorHex
                            Behavior on width { NumberAnimation { duration: 400 } }
                        }
                    }

                    Text {
                        text: root.fmtTime(root.position) + " / " + root.fmtTime(root.duration)
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 10
                        visible: root.duration > 0
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    Repeater {
                        model: [
                            { icon: "media-skip-backward", method: "Previous", size: 15 },
                            { icon: root.playing ? "media-playback-pause" : "media-playback-start", method: "PlayPause", size: 20 },
                            { icon: "media-skip-forward", method: "Next", size: 15 }
                        ]

                        delegate: Kirigami.Icon {
                            required property var modelData
                            source: modelData.icon
                            width: modelData.size
                            height: modelData.size
                            color: "white"
                            opacity: rowHover.containsMouse ? 1.0 : 0.7

                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: control.send(modelData.method)
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.hasTrack
                text: "Nothing playing"
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 12
            }
        }
    }
}
