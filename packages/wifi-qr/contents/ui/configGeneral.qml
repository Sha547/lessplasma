import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_cornerRadius: cornerSlider.value

    property alias cfg_glassBlur: blurSlider.value
    property alias cfg_glassTintOpacity: tintSlider.value

    property alias cfg_ssidOverride: ssidField.text
    property string cfg_security: "WPA"
    property alias cfg_password: pwField.text
    property alias cfg_ssidPollIntervalMs: pollSpin.value
    property alias cfg_qrSize: qrSizeSpin.value
    property alias cfg_qrMargin: qrMarginSpin.value

    QQC2.TextField {
        id: ssidField
        Kirigami.FormData.label: "SSID override:"
        placeholderText: "Leave empty to auto-detect"
    }

    QQC2.ComboBox {
        id: secField
        Kirigami.FormData.label: "Security:"
        model: ["WPA", "WEP", "nopass"]
        currentIndex: model.indexOf(page.cfg_security)
        onActivated: page.cfg_security = model[currentIndex]
    }

    QQC2.TextField {
        id: pwField
        Kirigami.FormData.label: "Password:"
        echoMode: TextInput.Password
    }

    QQC2.SpinBox {
        id: pollSpin
        Kirigami.FormData.label: "SSID poll interval (ms):"
        from: 5000
        to: 120000
        stepSize: 1000
    }

    QQC2.SpinBox {
        id: qrSizeSpin
        Kirigami.FormData.label: "QR size:"
        from: 4
        to: 20
    }

    QQC2.SpinBox {
        id: qrMarginSpin
        Kirigami.FormData.label: "QR margin:"
        from: 0
        to: 10
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
