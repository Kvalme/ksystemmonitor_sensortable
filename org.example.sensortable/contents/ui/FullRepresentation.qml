import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.faces as Faces
import org.kde.ksysguard.sensors as Sensors

Faces.SensorFace {
    id: root

    readonly property var cfg: root.controller.faceConfiguration

    readonly property var sensorIds: {
        const high = Array.from(root.controller.highPrioritySensorIds)
        if (!cfg.showLowPriority) {
            return high
        }
        return high.concat(Array.from(root.controller.lowPrioritySensorIds))
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    // level: 0..1
    function levelColor(level) {
        const x = Math.max(0, Math.min(1, level))
        if (!cfg.useMidColor) {
            return mix(cfg.lowColor, cfg.highColor, x)
        }
        if (x < 0.5) {
            return mix(cfg.lowColor, cfg.midColor, x * 2)
        }
        return mix(cfg.midColor, cfg.highColor, (x - 0.5) * 2)
    }

    function textColorFor(c) {
        const lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        return lum > 0.6 ? "black" : "white"
    }

    contentItem: ColumnLayout {
        spacing: cfg.rowSpacing

        Repeater {
            model: root.sensorIds

            delegate: RowLayout {
                id: row
                required property string modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 1.4
                spacing: cfg.rowSpacing

                Sensors.Sensor {
                    id: sensor
                    sensorId: row.modelData
                }

                readonly property real level: {
                    let lo = cfg.rangeFrom
                    let hi = cfg.rangeTo
                    if (cfg.rangeAuto && sensor.maximum > sensor.minimum) {
                        lo = sensor.minimum
                        hi = sensor.maximum
                    }
                    return hi > lo ? (Number(sensor.value) - lo) / (hi - lo) : 0
                }

                readonly property color fillColor: root.levelColor(level)

                // Left cell: name from settings
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: cfg.nameRatio
                    color: Kirigami.Theme.alternateBackgroundColor

                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: Kirigami.Theme.textColor
                        font.pixelSize: cfg.fontSize > 0
                            ? cfg.fontSize
                            : Math.max(8, parent.height * 0.5)
                        text: root.controller.sensorLabels[row.modelData] || sensor.name
                    }
                }

                // Right cell: value, filled by level
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 100 - cfg.nameRatio
                    color: row.fillColor

                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 6
                        color: root.textColorFor(row.fillColor)
                        font.bold: cfg.boldValue
                        font.pixelSize: cfg.fontSize > 0
                            ? cfg.fontSize
                            : Math.max(8, parent.height * 0.5)
                        text: sensor.formattedValue
                    }
                }
            }
        }
    }
}
