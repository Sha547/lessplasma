import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_cornerRadius: cornerSlider.value

    property alias cfg_glassBlur: blurSlider.value
    property alias cfg_glassTintOpacity: tintSlider.value

    property alias cfg_refreshSeconds: refreshSpin.value
    property alias cfg_warnThreshold: warnSlider.value
    property alias cfg_criticalThreshold: criticalSlider.value
    property alias cfg_excludedMounts: excludedField.text

    QQC2.SpinBox {
        id: refreshSpin
        Kirigami.FormData.label: "Refresh interval (s):"
        from: 5
        to: 300
        stepSize: 5
    }

    QQC2.Slider {
        id: warnSlider
        Kirigami.FormData.label: "Warning threshold:"
        from: 0.0
        to: 1.0
        stepSize: 0.01
    }

    QQC2.Slider {
        id: criticalSlider
        Kirigami.FormData.label: "Critical threshold:"
        from: 0.0
        to: 1.0
        stepSize: 0.01
    }

    QQC2.TextField {
        id: excludedField
        Kirigami.FormData.label: "Hide mounts containing:"
        placeholderText: "comma-separated, e.g. /mnt/backup, /media"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
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
