import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_cornerRadius: cornerSlider.value

    property alias cfg_pollIntervalMs: pollSpin.value
    property alias cfg_showArt: showArtBox.checked
    property alias cfg_artBackdrop: artBackdropBox.checked
    property string cfg_accentColorHex: "#5AC8FA"
    property alias cfg_glassBlur: blurSlider.value
    property alias cfg_glassTintOpacity: tintSlider.value

    function toHex(c) {
        function part(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); }
        return "#" + part(c.r) + part(c.g) + part(c.b);
    }

    QQC2.SpinBox {
        id: pollSpin
        Kirigami.FormData.label: "Poll interval (ms):"
        from: 250
        to: 5000
        stepSize: 250
    }

    QQC2.CheckBox {
        id: showArtBox
        Kirigami.FormData.label: "Cover thumbnail:"
        text: "Show album art"
    }

    QQC2.CheckBox {
        id: artBackdropBox
        Kirigami.FormData.label: "Cover backdrop:"
        text: "Blur album art behind the card"
    }

    RowLayout {
        Kirigami.FormData.label: "Progress color:"

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
