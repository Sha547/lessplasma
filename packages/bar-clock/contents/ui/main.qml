import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property int hours: 0
    property int minutes: 0
    property int seconds: 0

    function pad(n) { return n < 10 ? "0" + n : "" + n; }

    function update() {
        var d = new Date();
        root.hours = d.getHours();
        root.minutes = d.getMinutes();
        root.seconds = d.getSeconds();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.update()
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 320
        Layout.preferredHeight: 160
        Layout.minimumWidth: 220
        Layout.minimumHeight: 100

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#1a1a1a"
            radius: 22
            opacity: 0.96
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Text {
                    text: root.pad(root.hours) + ":" + root.pad(root.minutes)
                    color: "white"
                    font.pixelSize: 26
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    BarRow {
                        Layout.fillWidth: true
                        label: "H"
                        value: root.hours
                        max: 24
                        color: "#FF9F0A"
                    }
                    BarRow {
                        Layout.fillWidth: true
                        label: "M"
                        value: root.minutes
                        max: 60
                        color: "#5AC8FA"
                    }
                    BarRow {
                        Layout.fillWidth: true
                        label: "S"
                        value: root.seconds
                        max: 60
                        color: "#34C759"
                    }
                }
            }
        }
    }
}
