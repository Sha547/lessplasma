import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_cornerRadius: cornerSlider.value

    property alias cfg_autosaveDebounceMs: debounceSpin.value
    property alias cfg_fontSize: fontSizeSpin.value
    property string cfg_tintColorHex: "#0d0d10"
    property alias cfg_glassBlur: blurSlider.value
    property alias cfg_glassTintOpacity: tintSlider.value

    function toHex(c) {
        function part(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); }
        return "#" + part(c.r) + part(c.g) + part(c.b);
    }

    QQC2.SpinBox {
        id: debounceSpin
        Kirigami.FormData.label: "Autosave delay (ms):"
        from: 200
        to: 3000
        stepSize: 100
    }

    QQC2.SpinBox {
        id: fontSizeSpin
        Kirigami.FormData.label: "Font size:"
        from: 10
        to: 24
    }

    RowLayout {
        Kirigami.FormData.label: "Glass tint color:"

        Rectangle {
            width: Kirigami.Units.gridUnit * 1.5
            height: Kirigami.Units.gridUnit * 1.5
            radius: 4
            color: page.cfg_tintColorHex
            border.color: Kirigami.Theme.textColor
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: tintDialog.open()
            }
        }

        QQC2.Label {
            text: page.cfg_tintColorHex
            opacity: 0.7
        }

        ColorDialog {
            id: tintDialog
            selectedColor: page.cfg_tintColorHex
            onAccepted: page.cfg_tintColorHex = page.toHex(selectedColor)
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
