import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: full
    Layout.preferredWidth: 380
    Layout.preferredHeight: 540
    Layout.minimumWidth: 240
    Layout.minimumHeight: 200

    // Responsive thresholds (full widget height including 10px card margins)
    readonly property bool showCategories: height > 340
    readonly property bool showApps: height > 410
    readonly property int appsToShow: height > 480 ? 4 : 2

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 10
        color: "#1a1a1a"
        radius: 28
        opacity: 0.97
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            Text {
                text: root.formatDuration(root.totalSeconds)
                color: "white"
                font.pixelSize: 36
                font.bold: true
            }

            HourlyChart {
                Layout.fillWidth: true
                Layout.fillHeight: !full.showCategories
                Layout.preferredHeight: 130
                Layout.minimumHeight: 80
                hourlyData: root.hourly
                categories: root.categories
                maxSeconds: 3600
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 12
                visible: full.showCategories

                Repeater {
                    model: full.showCategories ? Math.min(3, root.categories.length) : 0
                    delegate: ColumnLayout {
                        required property int index
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.categories[index].name
                            color: root.categories[index].color
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        Text {
                            text: root.formatDuration(root.categories[index].seconds)
                            color: "white"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: full.showApps
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 12
                columnSpacing: 14
                visible: full.showApps

                Repeater {
                    model: full.showApps ? root.topApps.slice(0, full.appsToShow) : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10

                        Kirigami.Icon {
                            source: modelData.app ? modelData.app.toLowerCase() : "application-x-executable"
                            fallback: "application-x-executable"
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modelData.app
                                color: "white"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.formatDuration(modelData.seconds)
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
