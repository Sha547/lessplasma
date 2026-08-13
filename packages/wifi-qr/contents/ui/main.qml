import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    readonly property int qrSize: plasmoid.configuration.qrSize
    readonly property int qrMargin: plasmoid.configuration.qrMargin

    // True once we have enough to build a QR that actually connects. An open
    // network needs no password; a secured one is not encodable without it, and
    // encoding it as "nopass" would produce a code that silently fails to join.
    readonly property bool payloadReady: effectiveSsid.length > 0
        && (security === "nopass" || password.length > 0)

    function buildPayload() {
        if (!payloadReady) return "";
        if (security === "nopass") {
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
            if (!payload) {
                root.qrPath = "";
                return;
            }
            var safePayload = payload.replace(/'/g, "'\\''");
            var cmd =
                'if ! command -v qrencode >/dev/null; then echo MISSING; exit 0; fi; ' +
                'D="$HOME/.cache/plasma-wifi-qr"; mkdir -p "$D"; ' +
                'F="$D/qr.png"; ' +
                "qrencode -t PNG -s " + root.qrSize + " -m " + root.qrMargin + " -o \"$F\" '" + safePayload + "' 2>/dev/null && echo \"$F\"";
            connectSource(cmd);
        }
    }

    Timer {
        interval: root.qrPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ssidDS.refresh()
    }

    readonly property int qrPollInterval: plasmoid.configuration.ssidPollIntervalMs

    onPasswordChanged: qrDS.regenerate()
    onSecurityChanged: qrDS.regenerate()
    onQrSizeChanged: qrDS.regenerate()
    onQrMarginChanged: qrDS.regenerate()
    Connections {
        target: plasmoid.configuration
        function onSsidOverrideChanged() { qrDS.regenerate(); }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 240
        Layout.preferredHeight: 280
        Layout.minimumWidth: 180
        Layout.minimumHeight: 200

        GlassCard {
            anchors.fill: parent
            anchors.margins: 10
            cornerRadius: Math.min(plasmoid.configuration.cornerRadius, height / 2)
            blurAmount: plasmoid.configuration.glassBlur
            tintOpacity: plasmoid.configuration.glassTintOpacity

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
                        width: parent.width - 16
                        visible: !root.qrencodeMissing && !root.payloadReady
                        text: root.effectiveSsid.length === 0
                              ? "No Wi-Fi network detected"
                              : "Right-click → Configure\nto set the password"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Text {
                    text: root.payloadReady ? "Scan to connect" : ""
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignHCenter
                    visible: text.length > 0
                }
            }
        }
    }
}
