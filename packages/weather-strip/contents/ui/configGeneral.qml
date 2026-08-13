import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_cornerRadius: cornerSlider.value

    property alias cfg_refreshMinutes: refreshSpin.value
    property alias cfg_latitude: latField.text
    property alias cfg_longitude: lonField.text
    property alias cfg_useFahrenheit: fahrenheitBox.checked
    property alias cfg_forecastDays: daysSpin.value
    property string cfg_accentColorHex: "#5AC8FA"
    property alias cfg_glassBlur: blurSlider.value
    property alias cfg_glassTintOpacity: tintSlider.value

    function toHex(c) {
        function part(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); }
        return "#" + part(c.r) + part(c.g) + part(c.b);
    }

    QQC2.Label {
        Kirigami.FormData.label: "Location:"
        text: "Leave blank to detect from your IP address."
        opacity: 0.7
        wrapMode: Text.WordWrap
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
    }

    QQC2.TextField {
        id: latField
        Kirigami.FormData.label: "Latitude:"
        placeholderText: "auto"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
    }

    QQC2.TextField {
        id: lonField
        Kirigami.FormData.label: "Longitude:"
        placeholderText: "auto"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
    }

    QQC2.CheckBox {
        id: fahrenheitBox
        Kirigami.FormData.label: "Units:"
        text: "Use Fahrenheit"
    }

    QQC2.SpinBox {
        id: daysSpin
        Kirigami.FormData.label: "Days shown:"
        from: 3
        to: 10
    }

    QQC2.SpinBox {
        id: refreshSpin
        Kirigami.FormData.label: "Refresh interval (min):"
        from: 5
        to: 240
        stepSize: 5
    }

    RowLayout {
        Kirigami.FormData.label: "Today accent color:"

        Rectangle {
            width: Kirigami.Units.gridUnit * 1.5
            height: Kirigami.Units.gridUnit * 1.5
            radius: 4
            color: page.cfg_accentColorHex
            border.color: Kirigami.Theme.textColor
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: accentDialog.open()
            }
        }

        QQC2.Label {
            text: page.cfg_accentColorHex
            opacity: 0.7
        }

        ColorDialog {
            id: accentDialog
            selectedColor: page.cfg_accentColorHex
            onAccepted: page.cfg_accentColorHex = page.toHex(selectedColor)
        }
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
