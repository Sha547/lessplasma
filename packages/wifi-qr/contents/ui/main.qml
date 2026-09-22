import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property string ssid: ""
    property string qrPath: ""
    property bool qrencodeMissing: false
    property int generation: 0

    readonly property string effectiveSsid: plasmoid.configuration.ssidOverride.length > 0
        ? plasmoid.configuration.ssidOverride
        : ssid
    readonly property string password: plasmoid.configuration.password
    readonly property string security: plasmoid.configuration.security

    function buildPayload() {
        if (!effectiveSsid) return "";
        if (security === "nopass" || password.length === 0) {
            return "WIFI:T:nopass;S:" + effectiveSsid + ";;";
        }
        return "WIFI:T:" + security + ";S:" + effectiveSsid + ";P:" + password + ";;";
    }

    P5Support.DataSource {
        id: ssidDS
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                root.ssid = (data.stdout || "").trim();
            }
            disconnectSource(sourceName);
            qrDS.regenerate();
        }
        function refresh() {
            connectSource("iwgetid -r 2>/dev/null || nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}'");
        }
    }

    P5Support.DataSource {
        id: qrDS
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var raw = (data.stdout || "").trim();
                if (raw === "MISSING") {
                    root.qrencodeMissing = true;
                    root.qrPath = "";
                } else if (raw.length > 0) {
                    root.qrencodeMissing = false;
                    root.qrPath = raw;
                    root.generation += 1;
                }
            }
            disconnectSource(sourceName);
        }

        function regenerate() {
            var payload = root.buildPayload();
            if (!payload) return;
            var safePayload = payload.replace(/'/g, "'\\''");
            var cmd =
                'if ! command -v qrencode >/dev/null; then echo MISSING; exit 0; fi; ' +
                'D="$HOME/.cache/plasma-wifi-qr"; mkdir -p "$D"; ' +
                'F="$D/qr.png"; ' +
                "qrencode -t PNG -s 12 -m 2 -o \"$F\" '" + safePayload + "' 2>/dev/null && echo \"$F\"";
            connectSource(cmd);
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ssidDS.refresh()
    }

    onPasswordChanged: qrDS.regenerate()
    onSecurityChanged: qrDS.regenerate()
    Connections {
        target: plasmoid.configuration
        function onSsidOverrideChanged() { qrDS.regenerate(); }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 240
        Layout.preferredHeight: 280
        Layout.minimumWidth: 180
        Layout.minimumHeight: 200

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#1a1a1a"
            radius: 22
            opacity: 0.95
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.effectiveSsid || "No network"
                        color: "white"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "✎"
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: passwordDialog.open()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        id: qrFrame
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        color: "white"
                        radius: 10
                        visible: root.qrPath.length > 0 && !root.qrencodeMissing

                        Image {
                            anchors.fill: parent
                            anchors.margins: 6
                            source: root.qrPath ? "file://" + root.qrPath + "?v=" + root.generation : ""
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                            smooth: false
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.qrencodeMissing
                        text: "Install qrencode:\nsudo apt install qrencode"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.qrencodeMissing && root.password.length === 0 && root.security !== "nopass"
                        text: "Tap ✎ to set password"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.pixelSize: 12
                    }
                }

                Text {
                    text: root.password.length > 0 || root.security === "nopass"
                          ? "Scan to connect"
                          : ""
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignHCenter
                    visible: text.length > 0
                }
            }
        }

        Dialog {
            id: passwordDialog
            title: "WiFi credentials"
            standardButtons: Dialog.Ok | Dialog.Cancel
            modal: true
            anchors.centerIn: parent
            width: 320

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                Label { text: "SSID (leave empty to auto-detect)" }
                TextField {
                    id: ssidField
                    Layout.fillWidth: true
                    text: plasmoid.configuration.ssidOverride
                    placeholderText: root.ssid
                }

                Label { text: "Security" }
                ComboBox {
                    id: secField
                    Layout.fillWidth: true
                    model: ["WPA", "WEP", "nopass"]
                    currentIndex: model.indexOf(plasmoid.configuration.security)
                }

                Label { text: "Password" }
                TextField {
                    id: pwField
                    Layout.fillWidth: true
                    text: plasmoid.configuration.password
                    echoMode: TextInput.Password
                }
            }

            onAccepted: {
                plasmoid.configuration.ssidOverride = ssidField.text;
                plasmoid.configuration.security = secField.currentText;
                plasmoid.configuration.password = pwField.text;
                qrDS.regenerate();
            }
        }
    }
}
