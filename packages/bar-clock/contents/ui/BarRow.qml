import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row
    property string label: ""
    property int value: 0
    property int max: 60
    property color color: "white"

    spacing: 10

    Text {
        text: row.label
        color: "white"
        opacity: 0.55
        font.pixelSize: 11
        font.weight: Font.Medium
        Layout.preferredWidth: 14
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.08)

        Rectangle {
            width: parent.width * Math.min(1, row.value / row.max)
            height: parent.height
            radius: parent.radius
            color: row.color
            Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutQuad } }
        }
    }

    Text {
        text: (row.value < 10 ? "0" : "") + row.value
        color: "white"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        Layout.preferredWidth: 22
        horizontalAlignment: Text.AlignRight
    }
}
