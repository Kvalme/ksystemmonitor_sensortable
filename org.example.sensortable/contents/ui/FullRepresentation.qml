import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.faces as Faces
import org.kde.ksysguard.sensors as Sensors

// Full version (for the popup): all sensors, same cells as in the compact version
Faces.SensorFace {
    id: root

    readonly property var cfg: root.controller.faceConfiguration

    // Per-sensor ranges from config. One line per sensor: "sensor/id = min, max"
    readonly property var sensorRanges: {
        const map = {}
        const lines = String(cfg.sensorRanges || "").split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (line === "" || line[0] === "#") {
                continue
            }
            const eq = line.lastIndexOf("=")
            if (eq < 0) {
                continue
            }
            const id = line.slice(0, eq).trim()
            const parts = line.slice(eq + 1).split(/[,;]/)
            if (parts.length < 2 || parts[0].trim() === "" || parts[1].trim() === "") {
                continue
            }
            const lo = Number(parts[0].trim())
            const hi = Number(parts[1].trim())
            if (isNaN(lo) || isNaN(hi)) {
                continue
            }
            map[id] = { lo: lo, hi: hi }
        }
        return map
    }

    // Sensors with inverted colors (green = high). One sensor id per line.
    readonly property var inverseSet: {
        const set = {}
        const lines = String(cfg.inverseSensors || "").split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const id = lines[i].trim()
            if (id !== "") {
                set[id] = true
            }
        }
        return set
    }

    // Sensors without history graph (flat fill, minimal height). One sensor id per line.
    readonly property var noGraphSet: {
        const set = {}
        const lines = String(cfg.noGraphSensors || "").split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const id = lines[i].trim()
            if (id !== "") {
                set[id] = true
            }
        }
        return set
    }

    // Sensors without background (no track, no fill). One sensor id per line.
    readonly property var noBgSet: {
        const set = {}
        const lines = String(cfg.noBgSensors || "").split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const id = lines[i].trim()
            if (id !== "") {
                set[id] = true
            }
        }
        return set
    }

    // All sensors of the face: normal and low priority ones
    readonly property var allSensorIds: {
        const high = root.controller.highPrioritySensorIds
        const low = root.controller.lowPrioritySensorIds
        return (high ? Array.from(high) : []).concat(low ? Array.from(low) : [])
    }

    // Sensors with dynamic range (min/max seen on the sensor). One sensor id per line.
    readonly property var dynamicSet: {
        const set = {}
        const lines = String(cfg.dynamicSensors || "").split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const id = lines[i].trim()
            if (id !== "") {
                set[id] = true
            }
        }
        return set
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

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

    contentItem: GridLayout {
        flow: GridLayout.TopToBottom
        rowSpacing: cfg.rowSpacing
        columnSpacing: cfg.rowSpacing

        Repeater {
            model: root.allSensorIds
            delegate: ColumnLayout {
                id: cell
                required property string modelData

                spacing: 0

                // In the popup cells have a fixed height (the popup has no size of its own)
                readonly property bool fixedHeight: true
                readonly property real graphHeight:
                    cfg.cellHeight > 0 ? cfg.cellHeight : Kirigami.Units.gridUnit * 2.5
                // Without graph the cell has minimal height: one text line + name line
                readonly property real minimalHeight:
                    (cfg.noGraphHeight > 0 ? cfg.noGraphHeight : Kirigami.Units.gridUnit * 1.2)
                    + (cfg.showNames ? nameText.implicitHeight : 0)

                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                Layout.fillHeight: hasGraph && !fixedHeight
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                Layout.minimumHeight: hasGraph ? Kirigami.Units.gridUnit * 0.8 : minimalHeight
                // Maximum = minimum, so the layout can not stretch a cell without graph
                Layout.maximumHeight: hasGraph ? Number.POSITIVE_INFINITY : minimalHeight
                Layout.preferredHeight: !hasGraph
                    ? minimalHeight
                    : (fixedHeight
                        ? graphHeight + (cfg.showNames ? nameText.implicitHeight : 0)
                        : -1)

                Sensors.Sensor {
                    id: sensor
                    sensorId: cell.modelData
                }

                readonly property bool dynamic: root.dynamicSet[cell.modelData] === true

                // Lowest and highest value in the window that is shown now
                // (the last sampleCount values of the history)
                readonly property var windowRange: {
                    let lo = NaN
                    let hi = NaN
                    if (dynamic) {
                        const h = cell.history
                        for (let i = Math.max(0, h.length - cell.sampleCount); i < h.length; ++i) {
                            const v = h[i]
                            if (!isFinite(v)) {
                                continue
                            }
                            if (isNaN(lo) || v < lo) {
                                lo = v
                            }
                            if (isNaN(hi) || v > hi) {
                                hi = v
                            }
                        }
                    }
                    return { lo: lo, hi: hi }
                }

                // Converts a sensor value to a level from 0 to 1
                function levelOf(value) {
                    if (!isFinite(value)) {
                        return 0
                    }
                    let lo = cfg.rangeFrom
                    let hi = cfg.rangeTo
                    const own = root.sensorRanges[cell.modelData]
                    if (dynamic) {
                        // Dynamic range wins over everything else
                        lo = windowRange.lo
                        hi = windowRange.hi
                    } else if (own) {
                        lo = own.lo
                        hi = own.hi
                    } else if (cfg.rangeAuto && sensor.maximum > sensor.minimum) {
                        lo = sensor.minimum
                        hi = sensor.maximum
                    }
                    const v = hi > lo ? (value - lo) / (hi - lo) : 0
                    return Math.max(0, Math.min(1, v))
                }

                readonly property real level: levelOf(Number(sensor.value))

                readonly property bool inverse: root.inverseSet[cell.modelData] === true

                readonly property bool hasGraph: root.noGraphSet[cell.modelData] !== true

                readonly property bool hasBg: root.noBgSet[cell.modelData] !== true

                // History of sensor values, newest value is last
                property var history: []
                // One bar per pixel of graph width
                readonly property int sampleCount: Math.max(2, Math.floor(graph.width))

                Timer {
                    interval: Math.max(100, cfg.sampleInterval)
                    running: cell.hasGraph || cell.dynamic
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        let h = cell.history.slice()
                        h.push(Number(sensor.value))
                        if (h.length > cell.sampleCount) {
                            h = h.slice(h.length - cell.sampleCount)
                        }
                        cell.history = h
                    }
                }

                // Sensor name line
                Text {
                    id: nameText
                    visible: cfg.showNames
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? implicitHeight : 0
                    font.pixelSize: Math.max(5, cfg.nameFontSize)
                    elide: Text.ElideRight
                    color: Kirigami.Theme.textColor
                    opacity: 0.8
                    text: {
                        const labels = root.controller.sensorLabels
                        const label = labels ? labels[cell.modelData] : ""
                        return label ? label : sensor.name
                    }
                }

                // Graph cell
                Rectangle {
                    id: graph
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: cell.hasBg ? Qt.alpha(Kirigami.Theme.textColor, 0.12) : "transparent"
                    clip: true

                    // Without graph: fill from the left, as wide as the sensor level
                    Rectangle {
                        visible: !cell.hasGraph && cell.hasBg
                        x: 0
                        y: 0
                        width: graph.width * cell.level
                        height: graph.height
                        color: root.levelColor(cell.inverse ? 1 - cell.level : cell.level)
                    }

                    Repeater {
                        model: cell.hasGraph ? cell.sampleCount : 0
                        delegate: Rectangle {
                            id: bar
                            required property int index

                            // Oldest sample on the left, newest on the right
                            readonly property int sampleIndex:
                                cell.history.length - (cell.sampleCount - index)
                            readonly property real v:
                                sampleIndex >= 0 ? cell.levelOf(cell.history[sampleIndex]) : -1

                            visible: v >= 0
                            x: index
                            width: 1
                            height: Math.max(1, graph.height * Math.max(0, v))
                            anchors.bottom: parent.bottom
                            color: root.levelColor(cell.inverse ? 1 - v : v)
                        }
                    }

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 6
                        font.pixelSize: cfg.fontSize > 0 ? cfg.fontSize : 64
                        font.bold: cfg.boldValue
                        // Plain text when nothing is drawn behind it
                        readonly property bool plain: !cell.hasGraph && !cell.hasBg
                        color: plain ? Kirigami.Theme.textColor : "white"
                        style: plain ? Text.Normal : Text.Outline
                        styleColor: "black"
                        text: sensor.formattedValue
                    }
                }
            }
        }
    }
}
