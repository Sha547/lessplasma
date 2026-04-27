import QtQuick
import QtQuick.Layouts

Item {
    id: chart
    property var hourlyData: []
    property var categories: []
    property real maxSeconds: 3600

    // Cap chart axis so typical activity fills the bars instead of being
    // squashed by one outlier hour. Bars exceeding the cap simply hit the top.
    property real chartCap: 1800   // 30 min — most hours of normal use fit nicely

    readonly property real _maxBucket: {
        var m = 0;
        for (var i = 0; i < (hourlyData || []).length; ++i) {
            var bucket = hourlyData[i].categories || {};
            var sum = 0;
            for (var k in bucket) sum += bucket[k];
            if (sum > m) m = sum;
        }
        return m;
    }

    readonly property real effectiveMax: {
        var target = Math.min(_maxBucket, chartCap);
        if (target < 600) target = 600;
        return Math.ceil(target / 600) * 600;
    }

    readonly property var gridLines: [
        0,
        Math.round(effectiveMax / 2),
        effectiveMax
    ]

    readonly property var labels: [
        { hour: 0, text: "12 AM" },
        { hour: 6, text: "6 AM" },
        { hour: 12, text: "12 PM" },
        { hour: 18, text: "6 PM" },
    ]

    function fmtSecs(s) {
        if (s >= 3600) return Math.round(s / 3600) + "h";
        return Math.round(s / 60) + "m";
    }

    Item {
        id: plot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 36
        height: parent.height - 22
        clip: true

        Repeater {
            model: chart.gridLines
            delegate: Rectangle {
                width: plot.width
                height: 1
                y: plot.height - (modelData / chart.effectiveMax) * plot.height
                color: Qt.rgba(1, 1, 1, 0.08)
            }
        }

        Repeater {
            model: 24
            delegate: Item {
                id: barCol
                required property int index
                width: plot.width / 24
                height: plot.height
                x: index * width

                property var bucket: chart.hourlyData[index] ? (chart.hourlyData[index].categories || {}) : ({})

                Column {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 4
                    spacing: 0

                    Repeater {
                        model: chart.categories ? chart.categories.length : 0
                        delegate: Rectangle {
                            required property int index
                            width: 4
                            radius: 1
                            color: chart.categories[index].color
                            property real catSecs: barCol.bucket[chart.categories[index].name] || 0
                            height: Math.min(plot.height,
                                              (catSecs / chart.effectiveMax) * plot.height)
                            visible: height > 0
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: chart.gridLines
        delegate: Text {
            x: plot.x + plot.width + 4
            y: plot.y + plot.height - (modelData / chart.effectiveMax) * plot.height - height / 2
            text: modelData === 0 ? "0" : chart.fmtSecs(modelData)
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 10
        }
    }

    Repeater {
        model: chart.labels
        delegate: Text {
            required property var modelData
            x: plot.x + (modelData.hour / 24) * plot.width
            y: plot.y + plot.height + 4
            text: modelData.text
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 10
        }
    }
}
