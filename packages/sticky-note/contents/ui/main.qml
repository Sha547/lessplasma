import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    fullRepresentation: Item {
        Layout.preferredWidth: 280
        Layout.preferredHeight: 280
        Layout.minimumWidth: 200
        Layout.minimumHeight: 200

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#1a1a1a"
            radius: 24
            opacity: 0.95

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 8

                Text {
                    text: "Note"
                    color: "white"
                    opacity: 0.55
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: editor
                        text: plasmoid.configuration.noteText
                        color: "white"
                        font.pixelSize: 14
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        background: null
                        placeholderText: "Type a note…"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.3)

                        Timer {
                            id: saveTimer
                            interval: 600
                            onTriggered: plasmoid.configuration.noteText = editor.text
                        }

                        onTextChanged: saveTimer.restart()
                    }
                }
            }
        }
    }
}
