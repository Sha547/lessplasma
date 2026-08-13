import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_cornerRadius: cornerSlider.value

    property alias cfg_refreshSeconds: refreshSpin.value
    property alias cfg_vpnRegex: vpnRegexField.text
    property string cfg_vpnColorHex: "#34C759"
    property string cfg_directColorHex: "#FF9F0A"
    property alias cfg_glassBlur: blurSlider.value
    property alias cfg_glassTintOpacity: tintSlider.value

    function toHex(c) {
        function part(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); }
        return "#" + part(c.r) + part(c.g) + part(c.b);
    }

    component ColorPicker: RowLayout {
        id: pickerRoot
        property string hex: "#ffffff"
        signal picked(string hex)

        Rectangle {
            width: Kirigami.Units.gridUnit * 1.5
            height: Kirigami.Units.gridUnit * 1.5
            radius: 4
            color: pickerRoot.hex
            border.color: Kirigami.Theme.textColor
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: dialog.open()
            }
        }

        QQC2.Label {
            text: pickerRoot.hex
            opacity: 0.7
        }

        ColorDialog {
            id: dialog
            selectedColor: pickerRoot.hex
            onAccepted: pickerRoot.picked(page.toHex(selectedColor))
        }
    }

    QQC2.SpinBox {
        id: refreshSpin
        Kirigami.FormData.label: "Refresh interval (s):"
        from: 10
        to: 600
        stepSize: 10
    }

    QQC2.TextField {
        id: vpnRegexField
        Kirigami.FormData.label: "VPN interface regex:"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
    }

    ColorPicker {
        Kirigami.FormData.label: "VPN status color:"
        hex: page.cfg_vpnColorHex
        onPicked: (h) => page.cfg_vpnColorHex = h
    }

    ColorPicker {
        Kirigami.FormData.label: "Direct status color:"
        hex: page.cfg_directColorHex
        onPicked: (h) => page.cfg_directColorHex = h
    }

    QQC2.Slider {
        id: blurSlider
        Kirigami.FormData.label: "Glass blur:"
        from: 0.0
        to: 1.0
        stepSize: 0.05
    }

    QQC2.Slider {
        id: tintSlider
        Kirigami.FormData.label: "Glass tint:"
        from: 0.0
        to: 0.8
        stepSize: 0.02
    }

    RowLayout {
        Kirigami.FormData.label: "Corner radius:"

        QQC2.Slider {
            id: cornerSlider
            from: 0
            to: 48
            stepSize: 1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
        }

        QQC2.Label {
            text: cornerSlider.value === 0
                  ? "sharp"
                  : (cornerSlider.value >= 48 ? "fully blended" : Math.round(cornerSlider.value) + " px")
            opacity: 0.7
        }
    }
}
