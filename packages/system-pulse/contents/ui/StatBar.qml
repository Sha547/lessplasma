import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string label: ""
    property real value: 0
    property string suffix: "%"
    property real displayValue: 0
    spacing: 4
    anchors.fill: parent

    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
            text: root.label
            color: "white"
            opacity: 0.55
            font.pixelSize: 10
            font.weight: Font.Medium
            Layout.fillWidth: true
        }
        Text {
            text: root.displayValue + root.suffix
            color: "white"
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.1)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: parent.radius
            color: root.value > 0.85 ? "#FF3B30"
                 : root.value > 0.6 ? "#FF9F0A"
                 : "#34C759"
            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutQuad } }
        }
    }
}
