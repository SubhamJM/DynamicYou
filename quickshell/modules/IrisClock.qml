import QtQuick
import "../"

// The iRiS time figure: tabular hours and minutes, a separator tinted
// with the secondary accent (orange), and optional seconds / AM-PM.
Row {
    id: root

    property string text: ""
    property int pixelSize: 14
    property int weight: Font.DemiBold
    property color color: Theme.colors.text_primary ?? "#f5f5f7"
    property color separatorColor: Theme.accent
    property string family: "Readex Pro"
    property real minorScale: 0.58
    property bool isScreenRecording: false

    baselineOffset: hoursText.baselineOffset

    readonly property var parts: {
        const raw = String(root.text ?? "").trim();
        const period = raw.match(/\s*([^\d:.\s]+)$/);
        const figure = period ? raw.slice(0, period.index) : raw;
        const pieces = figure.split(/[:.]/);
        return {
            hours: pieces[0] ?? "",
            minutes: pieces[1] ?? "",
            seconds: pieces[2] ?? "",
            period: period ? period[1] : ""
        };
    }

    spacing: 0

    component Figure: Text {
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.features: ({ "tnum": 1 })
        font.letterSpacing: 0
        color: root.color
        renderType: Text.NativeRendering
    }

    component Minor: Text {
        font.family: root.family
        font.pixelSize: Math.round(root.pixelSize * root.minorScale)
        font.weight: Font.Medium
        font.features: ({ "tnum": 1 })
        color: Qt.alpha(root.color, 0.55)
        renderType: Text.NativeRendering
    }

    // Hours, minutes and seconds count; the separator and period stay put.
    IrisNumber {
        id: hoursText
        text: root.parts.hours
        family: root.family
        pixelSize: root.pixelSize
        weight: root.weight
        letterSpacing: 0
        color: root.color
    }

    Figure {
        text: ":"
        visible: root.parts.minutes.length > 0
        color: root.separatorColor
        anchors.baseline: hoursText.baseline
        anchors.baselineOffset: -root.pixelSize * 0.04
        leftPadding: 1.5
        rightPadding: 1.5
    }

    IrisNumber {
        text: root.parts.minutes
        anchors.baseline: hoursText.baseline
        family: root.family
        pixelSize: root.pixelSize
        weight: root.weight
        letterSpacing: 0
        color: root.color
    }

    Item {
        visible: root.parts.seconds.length > 0
        implicitWidth: secondsText.implicitWidth + root.pixelSize * 0.12
        implicitHeight: secondsText.implicitHeight
        baselineOffset: secondsText.baselineOffset
        anchors.baseline: hoursText.baseline
        IrisNumber {
            id: secondsText
            anchors.right: parent.right
            text: root.parts.seconds
            family: root.family
            pixelSize: Math.round(root.pixelSize * root.minorScale)
            weight: Font.Medium
            color: Qt.alpha(root.color, 0.55)
        }
    }

    Minor {
        visible: root.parts.period.length > 0
        text: root.parts.period
        leftPadding: root.pixelSize * 0.16
        anchors.baseline: hoursText.baseline
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
}
