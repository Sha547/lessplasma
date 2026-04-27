import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // map "YYYYMMDD" -> count
    property var eventDates: ({})
    readonly property var today: new Date()

    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    function dateKey(d) { return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()); }
    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear() &&
               a.getMonth() === b.getMonth() &&
               a.getDate() === b.getDate();
    }
    function dayLabel(offset) {
        var d = new Date();
        d.setDate(d.getDate() + offset);
        return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()];
    }
    function dayNum(offset) {
        var d = new Date();
        d.setDate(d.getDate() + offset);
        return d.getDate();
    }

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                var lines = (data.stdout || "").split("\n").filter(function(l){ return l.length > 0; });
                var counts = {};
                lines.forEach(function(line) {
                    var k;
                    if (line.length >= 8 && line.indexOf("-") === -1) {
                        k = line.substr(0, 8);
                    } else if (line.length >= 10) {
                        k = line.substr(0,4) + line.substr(5,2) + line.substr(8,2);
                    } else {
                        return;
                    }
                    counts[k] = (counts[k] || 0) + 1;
                });
                root.eventDates = counts;
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            var cmd =
                'find ~/.local/share/calendars ~/.local/share/akonadi_icaldir_resource* ' +
                '~/.config/calendar -name "*.ics" -type f 2>/dev/null | ' +
                'xargs -r grep -h "^DTSTART" 2>/dev/null | ' +
                'grep -oE "[0-9]{8}" | sort';
            connectSource(cmd);
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ds.refresh()
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 360
        Layout.preferredHeight: 100
        Layout.minimumWidth: 260
        Layout.minimumHeight: 80

        readonly property bool monthMode: height >= 220

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#1a1a1a"
            radius: 22
            opacity: 0.95
            clip: true

            Loader {
                anchors.fill: parent
                anchors.margins: 16
                sourceComponent: parent.parent.monthMode ? monthView : stripView
            }
        }

        Component {
            id: stripView
            RowLayout {
                spacing: 6
                Repeater {
                    model: 7
                    delegate: ColumnLayout {
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4

                        Text {
                            text: root.dayLabel(parent.index)
                            color: parent.index === 0 ? "#5AC8FA" : Qt.rgba(1,1,1,0.55)
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: root.dayNum(parent.index)
                            color: "white"
                            font.pixelSize: 18
                            font.bold: parent.index === 0
                            Layout.alignment: Qt.AlignHCenter
                        }
                        RowLayout {
                            spacing: 3
                            Layout.alignment: Qt.AlignHCenter
                            Repeater {
                                model: {
                                    var d = new Date();
                                    d.setDate(d.getDate() + parent.parent.index);
                                    return Math.min(3, root.eventDates[root.dateKey(d)] || 0);
                                }
                                delegate: Rectangle {
                                    width: 4; height: 4; radius: 2
                                    color: "#FF9F0A"
                                }
                            }
                            Item {
                                visible: !root.eventDates[root.dateKey((function(){
                                    var d = new Date(); d.setDate(d.getDate() + parent.parent.index); return d;
                                })())]
                                width: 4; height: 4
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: monthView
            ColumnLayout {
                id: mv
                spacing: 10

                readonly property date monthDate: new Date(root.today.getFullYear(), root.today.getMonth(), 1)
                readonly property int firstDow: monthDate.getDay()
                readonly property int daysInMonth: new Date(root.today.getFullYear(), root.today.getMonth() + 1, 0).getDate()
                readonly property int rowCount: Math.ceil((firstDow + daysInMonth) / 7)
                readonly property string monthName: ["January","February","March","April","May","June","July","August","September","October","November","December"][monthDate.getMonth()]

                Text {
                    text: mv.monthName + " " + mv.monthDate.getFullYear()
                    color: "white"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    columns: 7
                    columnSpacing: 4
                    rowSpacing: 4
                    Layout.fillWidth: true

                    Repeater {
                        model: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                        delegate: Text {
                            required property var modelData
                            text: modelData
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                }

                GridLayout {
                    id: dayGrid
                    columns: 7
                    columnSpacing: 4
                    rowSpacing: 6
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Repeater {
                        model: mv.rowCount * 7
                        delegate: Item {
                            id: dayCell
                            required property int index
                            property int dayOfMonth: dayCell.index - mv.firstDow + 1
                            property bool isInMonth: dayOfMonth >= 1 && dayOfMonth <= mv.daysInMonth
                            property var thisDate: isInMonth ? new Date(root.today.getFullYear(), root.today.getMonth(), dayOfMonth) : null
                            property bool isToday: isInMonth && root.isSameDay(thisDate, root.today)
                            property int eventCount: isInMonth ? (root.eventDates[root.dateKey(thisDate)] || 0) : 0

                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            Layout.minimumHeight: 28

                            Rectangle {
                                visible: dayCell.isToday
                                anchors.centerIn: parent
                                width: Math.min(dayCell.width, dayCell.height) - 4
                                height: width
                                radius: width / 2
                                color: "#5AC8FA"
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: dayCell.isInMonth
                                text: dayCell.dayOfMonth
                                color: dayCell.isToday ? "#1a1a1a" : "white"
                                opacity: dayCell.isToday ? 1.0 : 0.85
                                font.pixelSize: 12
                                font.bold: dayCell.isToday
                            }

                            Rectangle {
                                visible: dayCell.eventCount > 0 && !dayCell.isToday
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 4; height: 4; radius: 2
                                color: "#FF9F0A"
                            }
                        }
                    }
                }
            }
        }
    }
}
