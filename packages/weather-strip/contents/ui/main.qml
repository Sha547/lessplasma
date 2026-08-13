import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // [{ date, code, max, min }]
    property var days: []
    property string city: ""
    property int currentTemp: 0
    property int currentCode: 0
    property bool isDay: true
    property bool loaded: false

    readonly property string unitSuffix: plasmoid.configuration.useFahrenheit ? "°F" : "°C"
    readonly property string scriptPath: Qt.resolvedUrl("../code/weather.py").toString().replace(/^file:\/\//, "")

    // WMO weather codes → Breeze icon names.
    function iconFor(code, daytime) {
        if (code === 0) return daytime ? "weather-clear" : "weather-clear-night";
        if (code === 1) return daytime ? "weather-few-clouds" : "weather-few-clouds-night";
        if (code === 2) return "weather-clouds";
        if (code === 3) return "weather-many-clouds";
        if (code === 45 || code === 48) return "weather-fog";
        if (code >= 51 && code <= 57) return "weather-showers-scattered";
        if (code >= 61 && code <= 67) return "weather-showers";
        if (code >= 71 && code <= 77) return "weather-snow";
        if (code >= 80 && code <= 82) return "weather-showers";
        if (code === 85 || code === 86) return "weather-snow";
        if (code >= 95) return "weather-storm";
        return "weather-clouds";
    }

    function labelFor(code) {
        if (code === 0) return "Clear";
        if (code === 1) return "Mainly clear";
        if (code === 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 57) return "Drizzle";
        if (code >= 61 && code <= 67) return "Rain";
        if (code >= 71 && code <= 77) return "Snow";
        if (code >= 80 && code <= 82) return "Showers";
        if (code === 85 || code === 86) return "Snow showers";
        if (code === 95) return "Thunderstorm";
        if (code >= 96) return "Thunderstorm, hail";
        return "Unknown";
    }

    function dayLabel(dateStr, index) {
        if (index === 0) return "Today";
        var parts = (dateStr || "").split("-");
        if (parts.length < 3) return "";
        var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()];
    }

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var raw = (data.stdout || "").trim();
                if (raw.length > 0) {
                    var info = {};
                    raw.split("\n").forEach(function (line) {
                        var i = line.indexOf("=");
                        if (i > 0) info[line.substr(0, i)] = line.substr(i + 1);
                    });

                    if (info["city"] !== undefined) root.city = info["city"];
                    root.currentTemp = parseInt(info["current_temp"]) || 0;
                    root.currentCode = parseInt(info["current_code"]) || 0;
                    root.isDay = info["is_day"] !== "0";

                    var out = [];
                    var count = parseInt(info["count"]) || 0;
                    for (var i = 0; i < count; ++i) {
                        out.push({
                            date: info["d" + i + "_date"] || "",
                            code: parseInt(info["d" + i + "_code"]) || 0,
                            max: parseInt(info["d" + i + "_max"]) || 0,
                            min: parseInt(info["d" + i + "_min"]) || 0
                        });
                    }
                    if (out.length > 0) {
                        root.days = out;
                        root.loaded = true;
                    }
                }
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            var cfg = plasmoid.configuration;
            var cmd = "python3 \"" + root.scriptPath + "\"" +
                      " \"" + cfg.latitude + "\"" +
                      " \"" + cfg.longitude + "\"" +
                      " \"" + (cfg.useFahrenheit ? "f" : "c") + "\"" +
                      " \"" + cfg.forecastDays + "\"";
            connectSource(cmd);
        }
    }

    Timer {
        interval: plasmoid.configuration.refreshMinutes * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ds.refresh()
    }

    // Coordinates or units changing should not wait for the next tick.
    Connections {
        target: plasmoid.configuration
        function onLatitudeChanged() { ds.refresh(); }
        function onLongitudeChanged() { ds.refresh(); }
        function onUseFahrenheitChanged() { ds.refresh(); }
        function onForecastDaysChanged() { ds.refresh(); }
    }

    toolTipMainText: root.city.length > 0 ? root.city : "Weather"
    toolTipSubText: root.loaded
                    ? root.currentTemp + root.unitSuffix + " · " + root.labelFor(root.currentCode)
                    : "Loading forecast…"

    fullRepresentation: Item {
        id: view
        Layout.preferredWidth: 400
        Layout.preferredHeight: 120
        Layout.minimumWidth: 280
        Layout.minimumHeight: 96

        // Tall enough and the current conditions get their own header above the strip.
        readonly property bool detailed: height >= 190

        GlassCard {
            anchors.fill: parent
            anchors.margins: 10
            cornerRadius: Math.min(plasmoid.configuration.cornerRadius, height / 2)
            blurAmount: plasmoid.configuration.glassBlur
            tintOpacity: plasmoid.configuration.glassTintOpacity

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: view.detailed && root.loaded

                    Kirigami.Icon {
                        source: root.iconFor(root.currentCode, root.isDay)
                        fallback: "weather-clouds"
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            spacing: 6
                            Text {
                                text: root.currentTemp + root.unitSuffix
                                color: "white"
                                font.pixelSize: 26
                                font.bold: true
                            }
                            Text {
                                text: root.labelFor(root.currentCode)
                                color: Qt.rgba(1, 1, 1, 0.6)
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 4
                            }
                        }

                        Text {
                            text: root.city
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 11
                            visible: root.city.length > 0
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                    visible: view.detailed && root.loaded
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4
                    visible: root.loaded

                    Repeater {
                        model: root.days

                        delegate: ColumnLayout {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 3

                            Text {
                                text: root.dayLabel(modelData.date, index)
                                color: index === 0
                                       ? plasmoid.configuration.accentColorHex
                                       : Qt.rgba(1, 1, 1, 0.55)
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Kirigami.Icon {
                                source: root.iconFor(modelData.code, true)
                                fallback: "weather-clouds"
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: modelData.max + "°"
                                color: "white"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: modelData.min + "°"
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.loaded
                    text: "Loading forecast…"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
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
