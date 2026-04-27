import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property int totalSeconds: 0
    property string currentApp: ""
    property var hourly: []
    property var categories: []
    property var topApps: []

    function formatDuration(secs) {
        if (!secs || secs < 0) secs = 0;
        var h = Math.floor(secs / 3600);
        var m = Math.floor((secs % 3600) / 60);
        if (h > 0) return h + "h " + m + "m";
        if (m > 0) return m + "m";
        return secs + "s";
    }

    P5Support.DataSource {
        id: query
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var raw = (data.stdout || "").trim();
                try {
                    var parsed = JSON.parse(raw);
                    root.totalSeconds = parsed.total || 0;
                    root.currentApp = parsed.current || "";
                    root.hourly = parsed.hourly || [];
                    root.categories = parsed.categories || [];
                    root.topApps = parsed.top_apps || [];
                } catch (e) {
                    console.warn("screentime parse error:", e, raw);
                }
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            var cmd = "qdbus6 org.kde.ScreenTime /ScreenTime org.kde.ScreenTime.GetTodayJson 2>/dev/null || qdbus org.kde.ScreenTime /ScreenTime org.kde.ScreenTime.GetTodayJson";
            connectSource(cmd);
        }
    }

    Timer {
        interval: Math.max(5, plasmoid.configuration.refreshSeconds) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: query.refresh()
    }

    fullRepresentation: FullRepresentation {}

    toolTipMainText: "Screen Time"
    toolTipSubText: "Today: " + formatDuration(totalSeconds)
}
