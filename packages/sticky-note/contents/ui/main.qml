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

        GlassCard {
            anchors.fill: parent
            anchors.margins: 10
            cornerRadius: Math.min(plasmoid.configuration.cornerRadius, height / 2)
            tintColor: plasmoid.configuration.tintColorHex
            blurAmount: plasmoid.configuration.glassBlur
            tintOpacity: plasmoid.configuration.glassTintOpacity

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
                        font.pixelSize: plasmoid.configuration.fontSize
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        background: null
                        placeholderText: "Type a note…"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.3)

                        Timer {
                            id: saveTimer
                            interval: plasmoid.configuration.autosaveDebounceMs
                            onTriggered: plasmoid.configuration.noteText = editor.text
                        }

                        onTextChanged: saveTimer.restart()
                    }
                }
            }
        }
    }
}
