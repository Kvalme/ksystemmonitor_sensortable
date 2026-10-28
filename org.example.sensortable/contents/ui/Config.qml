import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    id: page

    property alias cfg_rangeAuto: rangeAutoBox.checked
    property alias cfg_rangeFrom: fromSpin.value
    property alias cfg_rangeTo: toSpin.value
    property alias cfg_lowColor: lowButton.color
    property alias cfg_midColor: midButton.color
    property alias cfg_highColor: highButton.color
    property alias cfg_useMidColor: useMidBox.checked
    property alias cfg_nameRatio: ratioSpin.value
    property alias cfg_fontSize: fontSpin.value
    property alias cfg_boldValue: boldBox.checked
    property alias cfg_rowSpacing: spacingSpin.value
    property alias cfg_showLowPriority: lowPrioBox.checked
    property alias cfg_showNames: showNamesBox.checked
    property alias cfg_nameFontSize: nameFontSpin.value
    property alias cfg_cellHeight: cellHeightSpin.value
    property alias cfg_noGraphHeight: noGraphHeightSpin.value
    property alias cfg_sampleInterval: intervalSpin.value
    // Per-sensor ranges, stored as text: one line "sensor/id = min, max"
    // Sensors with inverted colors, one sensor id per line
    property string cfg_inverseSensors
    readonly property var inverseSet: parseInverse(cfg_inverseSensors)

    function parseInverse(text) {
        const set = {}
        const lines = String(text || "").split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const id = lines[i].trim()
            if (id !== "") {
                set[id] = true
            }
        }
        return set
    }

    function setInverse(id, on) {
        const set = parseInverse(cfg_inverseSensors)
        if (on) {
            set[id] = true
        } else {
            delete set[id]
        }
        cfg_inverseSensors = Object.keys(set).join("\n")
    }

    // Sensors without history graph, one sensor id per line
    property string cfg_noGraphSensors
    readonly property var noGraphSet: parseInverse(cfg_noGraphSensors)

    function setNoGraph(id, on) {
        const set = parseInverse(cfg_noGraphSensors)
        if (on) {
            set[id] = true
        } else {
            delete set[id]
        }
        cfg_noGraphSensors = Object.keys(set).join("\n")
    }

    // Sensors without background, one sensor id per line
    property string cfg_noBgSensors
    readonly property var noBgSet: parseInverse(cfg_noBgSensors)

    function setNoBg(id, on) {
        const set = parseInverse(cfg_noBgSensors)
        if (on) {
            set[id] = true
        } else {
            delete set[id]
        }
        cfg_noBgSensors = Object.keys(set).join("\n")
    }

    // Sensors with dynamic range, one sensor id per line
    property string cfg_dynamicSensors
    readonly property var dynamicSet: parseInverse(cfg_dynamicSensors)

    function setDynamic(id, on) {
        const set = parseInverse(cfg_dynamicSensors)
        if (on) {
            set[id] = true
        } else {
            delete set[id]
        }
        cfg_dynamicSensors = Object.keys(set).join("\n")
    }

    // Dynamic range sensors that use min/max since start, one sensor id per line
    property string cfg_globalSensors
    readonly property var globalSet: parseInverse(cfg_globalSensors)

    function setGlobal(id, on) {
        const set = parseInverse(cfg_globalSensors)
        if (on) {
            set[id] = true
        } else {
            delete set[id]
        }
        cfg_globalSensors = Object.keys(set).join("\n")
    }

    property string cfg_sensorRanges
    readonly property var ranges: parseRanges(cfg_sensorRanges)

    function parseRanges(text) {
        const map = {}
        const lines = String(text || "").split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (line === "" || line[0] === "#") {
                continue
            }
            const eq = line.lastIndexOf("=")
            if (eq < 0) {
                continue
            }
            const parts = line.slice(eq + 1).split(/[,;]/)
            if (parts.length < 2 || parts[0].trim() === "" || parts[1].trim() === "") {
                continue
            }
            const lo = Number(parts[0].trim())
            const hi = Number(parts[1].trim())
            if (!isNaN(lo) && !isNaN(hi)) {
                map[line.slice(0, eq).trim()] = { lo: lo, hi: hi }
            }
        }
        return map
    }

    function serializeRanges(map) {
        return Object.keys(map).map(k => k + " = " + map[k].lo + ", " + map[k].hi).join("\n")
    }

    function setRange(id, lo, hi) {
        const map = parseRanges(cfg_sensorRanges)
        map[id] = { lo: lo, hi: hi }
        cfg_sensorRanges = serializeRanges(map)
    }

    function clearRange(id) {
        const map = parseRanges(cfg_sensorRanges)
        delete map[id]
        cfg_sensorRanges = serializeRanges(map)
    }

    // The face controller is provided by the System Monitor.
    // If it is not available, the list is empty and a text field is shown instead.
    function sensorIds() {
        try {
            return controller.highPrioritySensorIds || []
        } catch (e) {
            return []
        }
    }

    function sensorTitle(id) {
        try {
            const label = controller.sensorLabels[id]
            return label ? label : id
        } catch (e) {
            return id
        }
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Range")
    }
    QQC2.CheckBox {
        id: rangeAutoBox
        text: i18n("Use range from the sensor (if it has one)")
    }
    QQC2.SpinBox {
        id: fromSpin
        Kirigami.FormData.label: i18n("Min value:")
        from: -100000
        to: 100000
        editable: true
    }
    QQC2.SpinBox {
        id: toSpin
        Kirigami.FormData.label: i18n("Max value:")
        from: -100000
        to: 100000
        editable: true
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Range per sensor")
    }
    Repeater {
        model: page.sensorIds()
        delegate: RowLayout {
            id: row
            required property string modelData
            readonly property var own: page.ranges[modelData]
            readonly property bool dyn: page.dynamicSet[modelData] === true

            Kirigami.FormData.label: page.sensorTitle(modelData) + ":"

            QQC2.CheckBox {
                text: i18n("Graph")
                checked: page.noGraphSet[row.modelData] !== true
                onToggled: page.setNoGraph(row.modelData, !checked)
            }
            QQC2.CheckBox {
                text: i18n("Background")
                checked: page.noBgSet[row.modelData] !== true
                onToggled: page.setNoBg(row.modelData, !checked)
            }
            QQC2.CheckBox {
                text: i18n("Dynamic range")
                checked: row.dyn
                onToggled: page.setDynamic(row.modelData, checked)
            }
            QQC2.CheckBox {
                text: i18n("Global min/max")
                enabled: row.dyn
                checked: page.globalSet[row.modelData] === true
                onToggled: page.setGlobal(row.modelData, checked)
            }
            QQC2.CheckBox {
                enabled: !row.dyn
                text: i18n("Own range")
                checked: row.own !== undefined
                onToggled: {
                    if (checked) {
                        page.setRange(row.modelData, fromSpin.value, toSpin.value)
                    } else {
                        page.clearRange(row.modelData)
                    }
                }
            }
            QQC2.SpinBox {
                enabled: row.own !== undefined && !row.dyn
                from: -100000
                to: 100000
                editable: true
                value: row.own ? row.own.lo : fromSpin.value
                onValueModified: page.setRange(row.modelData, value, row.own ? row.own.hi : toSpin.value)
            }
            QQC2.Label {
                text: i18n("to")
            }
            QQC2.SpinBox {
                enabled: row.own !== undefined && !row.dyn
                from: -100000
                to: 100000
                editable: true
                value: row.own ? row.own.hi : toSpin.value
                onValueModified: page.setRange(row.modelData, row.own ? row.own.lo : fromSpin.value, value)
            }
            QQC2.CheckBox {
                text: i18n("Inverse")
                checked: page.inverseSet[row.modelData] === true
                onToggled: page.setInverse(row.modelData, checked)
            }
        }
    }
    QQC2.Label {
        visible: page.sensorIds().length === 0
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        wrapMode: Text.WordWrap
        text: i18n("Sensor list is not available. Edit ranges as text, one line per sensor: sensor id = min, max")
    }
    QQC2.TextArea {
        visible: page.sensorIds().length === 0
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        Layout.preferredHeight: Kirigami.Units.gridUnit * 6
        wrapMode: TextEdit.NoWrap
        font.family: "monospace"
        text: page.cfg_sensorRanges
        onTextChanged: {
            if (activeFocus) {
                page.cfg_sensorRanges = text
            }
        }
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Colors")
    }
    KQuickControls.ColorButton {
        id: lowButton
        Kirigami.FormData.label: i18n("Low level:")
        showAlphaChannel: false
    }
    QQC2.CheckBox {
        id: useMidBox
        text: i18n("Use a middle color")
    }
    KQuickControls.ColorButton {
        id: midButton
        Kirigami.FormData.label: i18n("Middle level:")
        enabled: useMidBox.checked
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: highButton
        Kirigami.FormData.label: i18n("High level:")
        showAlphaChannel: false
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Layout")
    }
    QQC2.SpinBox {
        id: ratioSpin
        Kirigami.FormData.label: i18n("Name column width (%):")
        from: 10
        to: 90
    }
    QQC2.SpinBox {
        id: fontSpin
        Kirigami.FormData.label: i18n("Font size in px (0 = auto):")
        from: 0
        to: 200
    }
    QQC2.SpinBox {
        id: spacingSpin
        Kirigami.FormData.label: i18n("Space between cells:")
        from: 0
        to: 30
    }
    QQC2.SpinBox {
        id: cellHeightSpin
        Kirigami.FormData.label: i18n("Cell height in px (0 = auto):")
        from: 0
        to: 500
    }
    QQC2.SpinBox {
        id: noGraphHeightSpin
        Kirigami.FormData.label: i18n("Height without graph in px (0 = auto):")
        from: 0
        to: 500
    }
    QQC2.CheckBox {
        id: showNamesBox
        text: i18n("Show sensor name above each cell")
    }
    QQC2.SpinBox {
        id: nameFontSpin
        Kirigami.FormData.label: i18n("Name font size in px:")
        enabled: showNamesBox.checked
        from: 5
        to: 40
    }
    QQC2.CheckBox {
        id: boldBox
        text: i18n("Bold value text")
    }
    QQC2.CheckBox {
        id: lowPrioBox
        text: i18n("Also show low priority sensors")
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("History graph")
    }
    QQC2.SpinBox {
        id: intervalSpin
        Kirigami.FormData.label: i18n("Time between bars (ms):")
        from: 100
        to: 60000
        stepSize: 100
    }
}
