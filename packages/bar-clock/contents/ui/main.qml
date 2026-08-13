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

        GlassCard {
            anchors.fill: parent
            anchors.margins: 10
            cornerRadius: Math.min(plasmoid.configuration.cornerRadius, height / 2)
            blurAmount: plasmoid.configuration.glassBlur
            tintOpacity: plasmoid.configuration.glassTintOpacity

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Text {
                    text: root.pad(root.hours) + ":" + root.pad(root.minutes)
                    color: "white"
                    font.pixelSize: plasmoid.configuration.clockFontSize
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
                        color: plasmoid.configuration.hourColorHex
                    }
                    BarRow {
                        Layout.fillWidth: true
                        label: "M"
                        value: root.minutes
                        max: 60
                        color: plasmoid.configuration.minuteColorHex
                    }
                    BarRow {
                        Layout.fillWidth: true
                        label: "S"
                        value: root.seconds
                        max: 60
                        color: plasmoid.configuration.secondColorHex
                    }
                }
            }
        }
    }
}
