import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // [{name, mount, total, used, free, pct}]
    property var drives: []

    function fmtBytes(b) {
        if (b >= 1024 * 1024 * 1024 * 1024) return (b / (1024 * 1024 * 1024 * 1024)).toFixed(1) + " TB";
        if (b >= 1024 * 1024 * 1024) return (b / (1024 * 1024 * 1024)).toFixed(1) + " GB";
        if (b >= 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MB";
        if (b >= 1024) return (b / 1024).toFixed(1) + " KB";
        return b + " B";
    }

    function colorFor(pct) {
        if (pct > plasmoid.configuration.criticalThreshold) return "#FF3B30";
        if (pct > plasmoid.configuration.warnThreshold) return "#FF9F0A";
        return "#34C759";
    }

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var raw = (data.stdout || "").trim();
                var lines = raw.split("\n");
                var out = [];
                lines.forEach(function(l) {
                    // df -P -B1K format: Filesystem 1K-blocks Used Available Capacity Mountpoint
                    var parts = l.trim().split(/\s+/);
                    if (parts.length < 6) return;
                    var fs = parts[0];
                    var total = parseInt(parts[1]) * 1024;
                    var used  = parseInt(parts[2]) * 1024;
                    var free  = parseInt(parts[3]) * 1024;
                    var mount = parts.slice(5).join(" ");
                    if (total <= 0 || fs === "efivarfs") return;
                    if (mount.indexOf("/sys/") === 0) return;
                    if (mount.indexOf("/proc/") === 0) return;
                    if (mount.indexOf("/run/") === 0) return;
                    if (mount.indexOf("/var/snap/") === 0) return;
                    if (mount.indexOf("/snap/") === 0) return;
                    var excludes = plasmoid.configuration.excludedMounts
                        .split(",")
                        .map(function(s) { return s.trim(); })
                        .filter(function(s) { return s.length > 0; });
                    for (var i = 0; i < excludes.length; ++i) {
                        if (mount.indexOf(excludes[i]) !== -1) return;
                    }
                    var name = mount === "/" ? "Root" :
                               mount.split("/").pop() || mount;
                    out.push({
                        name: name,
                        mount: mount,
                        total: total,
                        used: used,
                        free: free,
                        pct: used / total
                    });
                });
                out.sort(function(a, b) { return b.total - a.total; });
                root.drives = out;
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            var cmd =
                "df -P -B1K -x tmpfs -x devtmpfs -x squashfs -x overlay " +
                "-x proc -x sysfs -x cgroup2 -x devpts -x mqueue -x debugfs " +
                "-x tracefs -x securityfs -x ramfs -x autofs -x efivarfs " +
                "-x fuse.gvfsd-fuse -x fuse.portal 2>/dev/null | tail -n +2";
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
        id: view
        Layout.preferredWidth: 320
        Layout.preferredHeight: Math.max(120, 40 + root.drives.length * 56)
        Layout.minimumWidth: 240
        Layout.minimumHeight: 90

        readonly property bool compact: height < 160

        GlassCard {
            anchors.fill: parent
            anchors.margins: 10
            cornerRadius: Math.min(plasmoid.configuration.cornerRadius, height / 2)
            blurAmount: plasmoid.configuration.glassBlur
            tintOpacity: plasmoid.configuration.glassTintOpacity

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: view.compact ? 6 : 12

                Text {
                    text: "Storage"
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    opacity: 0.55
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: view.compact ? 6 : 10

                    Repeater {
                        model: root.drives

                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: modelData.name
                                    color: "white"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: root.fmtBytes(modelData.free) + " free"
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                    font.pixelSize: 11
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 5
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.1)

                                Rectangle {
                                    width: parent.width * Math.min(1, modelData.pct)
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.colorFor(modelData.pct)
                                    Behavior on width { NumberAnimation { duration: 400 } }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.drives.length === 0
                        text: "No drives detected."
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
