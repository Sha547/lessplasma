import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property real cpu: 0.0
    property real ram: 0.0
    property real netKbps: 0.0

    property var _prevCpu: null
    property var _prevNet: null

    function parseProc(text, key) {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; ++i) {
            if (lines[i].indexOf(key) === 0) return lines[i];
        }
        return "";
    }

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var raw = data.stdout || "";
                var blocks = raw.split("---SPLIT---");
                if (blocks.length >= 3) {
                    root._handleCpu(blocks[0]);
                    root._handleRam(blocks[1]);
                    root._handleNet(blocks[2]);
                }
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            connectSource("cat /proc/stat | head -1; echo ---SPLIT---; cat /proc/meminfo | head -5; echo ---SPLIT---; cat /proc/net/dev");
        }
    }

    function _handleCpu(block) {
        var line = block.split("\n")[0];
        var parts = line.trim().split(/\s+/).slice(1).map(Number);
        if (parts.length < 4) return;
        var idle = parts[3] + (parts[4] || 0);
        var nonIdle = parts[0] + parts[1] + parts[2] + (parts[5] || 0) + (parts[6] || 0) + (parts[7] || 0);
        var total = idle + nonIdle;
        if (_prevCpu) {
            var dt = total - _prevCpu.total;
            var di = idle - _prevCpu.idle;
            if (dt > 0) cpu = (dt - di) / dt;
        }
        _prevCpu = { total: total, idle: idle };
    }

    function _handleRam(block) {
        var totalLine = parseProc(block, "MemTotal:");
        var availLine = parseProc(block, "MemAvailable:");
        var total = parseInt((totalLine.match(/\d+/) || [0])[0]);
        var avail = parseInt((availLine.match(/\d+/) || [0])[0]);
        if (total > 0) ram = 1 - (avail / total);
    }

    function _handleNet(block) {
        var lines = block.split("\n");
        var rx = 0, tx = 0;
        for (var i = 2; i < lines.length; ++i) {
            var l = lines[i].trim();
            if (!l || l.indexOf("lo:") === 0) continue;
            var parts = l.split(/\s+/);
            if (parts.length < 10) continue;
            rx += parseInt(parts[1]) || 0;
            tx += parseInt(parts[9]) || 0;
        }
        var now = Date.now();
        if (_prevNet) {
            var dt = (now - _prevNet.t) / 1000;
            if (dt > 0) {
                var bytes = (rx - _prevNet.rx) + (tx - _prevNet.tx);
                netKbps = (bytes / 1024) / dt;
            }
        }
        _prevNet = { rx: rx, tx: tx, t: now };
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ds.refresh()
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 240
        Layout.preferredHeight: 80
        Layout.minimumWidth: 180
        Layout.minimumHeight: 64

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#1a1a1a"
            radius: height / 2
            opacity: 0.95

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    StatBar { label: "CPU"; value: root.cpu; suffix: "%"; displayValue: Math.round(root.cpu * 100) }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    StatBar { label: "RAM"; value: root.ram; suffix: "%"; displayValue: Math.round(root.ram * 100) }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    StatBar {
                        label: "NET"
                        value: Math.min(1, root.netKbps / 5000)
                        suffix: "k/s"
                        displayValue: Math.round(root.netKbps)
                    }
                }
            }
        }
    }
}
