import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property string ip: ""
    property string city: ""
    property string region: ""
    property string country: ""
    property string org: ""
    property bool vpn: false
    property bool error: false

    function flagFor(cc) {
        if (!cc || cc.length !== 2) return "";
        var base = 0x1F1E6;
        return String.fromCodePoint(base + cc.charCodeAt(0) - 65) +
               String.fromCodePoint(base + cc.charCodeAt(1) - 65);
    }

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var raw = (data.stdout || "").trim();
                var lines = raw.split("\n");
                var info = { ip: "", city: "", region: "", country: "", org: "", vpn: false };
                lines.forEach(function(l) {
                    var idx = l.indexOf("=");
                    if (idx < 0) return;
                    var k = l.substr(0, idx);
                    var v = l.substr(idx + 1);
                    if (k === "ip") info.ip = v;
                    else if (k === "city") info.city = v;
                    else if (k === "region") info.region = v;
                    else if (k === "country") info.country = v;
                    else if (k === "org") info.org = v;
                    else if (k === "vpn") info.vpn = v === "1";
                });
                if (info.ip) {
                    root.ip = info.ip;
                    root.city = info.city;
                    root.region = info.region;
                    root.country = info.country;
                    root.org = info.org;
                    root.vpn = info.vpn;
                    root.error = false;
                } else {
                    root.error = true;
                }
            } else {
                root.error = true;
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            var safeRegex = plasmoid.configuration.vpnRegex.replace(/'/g, "'\\''");
            var cmd =
                'VPN=0; ' +
                "if ip link show 2>/dev/null | grep -qE '" + safeRegex + "'; then VPN=1; fi; " +
                'echo "vpn=$VPN"; ' +
                'BODY=$(curl -sf --max-time 5 https://ipinfo.io/json 2>/dev/null); ' +
                'if [ -n "$BODY" ]; then ' +
                '  echo "$BODY" | python3 -c "' +
                'import sys,json\n' +
                'try: d=json.load(sys.stdin)\n' +
                'except: sys.exit(0)\n' +
                'for k in (\\"ip\\",\\"city\\",\\"region\\",\\"country\\",\\"org\\"):\n' +
                '  v=d.get(k,\\"\\")\n' +
                '  if v: print(k+\\"=\\"+v)' +
                '"; ' +
                'fi';
            connectSource(cmd);
        }
    }

    Timer {
        interval: plasmoid.configuration.refreshSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ds.refresh()
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 280
        Layout.preferredHeight: 80
        Layout.minimumWidth: 200
        Layout.minimumHeight: 64

        readonly property bool wide: width >= 280

        GlassCard {
            anchors.fill: parent
            anchors.margins: 10
            cornerRadius: Math.min(plasmoid.configuration.cornerRadius, height / 2)
            blurAmount: plasmoid.configuration.glassBlur
            tintOpacity: plasmoid.configuration.glassTintOpacity

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 10

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: root.vpn ? plasmoid.configuration.vpnColorHex : plasmoid.configuration.directColorHex
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.vpn ? "VPN" : "Direct"
                    color: "white"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    opacity: 0.7
                }

                Rectangle { width: 1; Layout.fillHeight: true; Layout.topMargin: 16; Layout.bottomMargin: 16; color: Qt.rgba(1,1,1,0.1) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: root.ip || (root.error ? "Offline" : "Looking up…")
                        color: "white"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: root.country.length > 0
                        text: root.flagFor(root.country) + " " +
                              (root.city ? root.city + ", " : "") + root.country
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ds.refresh()
            }
        }
    }
}
