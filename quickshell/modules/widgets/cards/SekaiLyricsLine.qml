import QtQuick
import "../../../"
import "LyricsMath.js" as LM

Item {
    id: line

    property string text: ""
    property real lineStart: 0
    property real lineEnd: 0
    property real t: 0
    property int index: 0
    property int curIndex: -1
    property bool playing: false
    property real d: 0
    property bool still: false
    property bool lineOnly: false
    property var marks: []
    property string bgText: ""
    property real bgStart: 0
    property real bgEnd: 0
    property real rush: 0
    property real prevRush: 0
    property real prevEnd: 0
    property real maxW: 430
    property real poseScaleY: 0.76
    property int px: 28
    property real cx: 0
    property real cy: 0

    readonly property color colPrimary: Theme.m3.primary ?? Theme.accent
    readonly property color colSecondary: Theme.m3.secondary ?? "#67e8f9"
    readonly property color colOutline: Qt.darker(Theme.m3.surface_container_lowest ?? "#030a16", 1.35)

    readonly property real held: (line.rush > 0 && !line.still && !line.blank)
        ? LM.hold(line.t, line.lineEnd, line.rush) : 0
    readonly property real heldAbove: (line.prevRush > 0 && !line.still)
        ? LM.hold(line.t, line.prevEnd, line.prevRush) : 0
    readonly property real entryRush: (line.still || line.index <= 0)
        ? 0 : LM.rushOf(LM.overrun(line.prevEnd, line.lineStart))
    readonly property real land: (line.isCur && line.entryRush > 0)
        ? LM.landing(line.t - line.lineStart, line.entryRush) : 0
    readonly property var pose: LM.takeover(line.d, line.held)
    readonly property var toks: LM.tokens(line.text)
    readonly property bool blank: line.toks.length === 0 && !line.still
    readonly property var sp: LM.spansFor(line.toks, line.lineStart, Math.max(0.1, line.lineEnd - line.lineStart), line.marks)
    readonly property var mainIdx: LM.mainIndexes(line.toks)
    readonly property var mainSp: {
        const out = [];
        for (let i = 0; i < line.mainIdx.length; i++)
            out.push(line.sp[line.mainIdx[i]]);
        return out;
    }

    readonly property var bgToks: line.bgText !== "" ? LM.tokens(line.bgText) : []
    readonly property bool hasBg: line.bgToks.length > 0 && !line.still && !line.blank
    readonly property int bgPx: Math.max(12, Math.round(line.px * 0.5))
    readonly property var bgSp: LM.spans(line.bgToks, line.bgStart, Math.max(0.2, Math.max(line.bgEnd, line.lineEnd) - line.bgStart))
    readonly property real bgIn: !line.hasBg ? 0
        : (line.index < line.curIndex ? 1 : (line.isCur ? Math.max(0, Math.min(1, (line.t - line.bgStart + 0.12) / 0.3)) : 0))
    readonly property bool isCur: !line.still && line.index === line.curIndex
    readonly property bool carried: !line.still && line.index < line.curIndex && line.t >= line.lineStart && line.t < line.lineEnd
    readonly property bool singing: line.isCur || line.carried
    readonly property bool litOn: !line.still && (line.index === line.curIndex || line.index === line.curIndex - 1 || line.carried)
    readonly property int kmAny: LM.wordAt(line.mainSp, line.t)
    readonly property int km: line.singing ? line.kmAny : -1
    readonly property real hopP: LM.hop(line.mainSp, line.kmAny, line.t)
    readonly property real pad: Math.round(line.px * 0.90)
    readonly property real wholeLit: Math.max(0, Math.min(1, (line.t - line.lineStart) / 0.18))
    readonly property real bgWholeLit: Math.max(0, Math.min(1, (line.t - line.bgStart) / 0.18))

    property real dim: line.playing ? 1 : 0.62
    Behavior on dim { NumberAnimation { duration: 320 } }

    x: line.cx
    y: line.cy + line.pose.y * line.poseScaleY
    width: 0
    height: 0

    function center(i) {
        const it = reps.itemAt(i);
        return it ? it.x + it.gapW + it.fullW / 2 : 0;
    }

    onKmChanged: {
        if (!line.lineOnly && line.singing && line.playing && line.km >= 0) {
            puff.x = line.center(line.mainIdx[line.km]);
            puff.y = line.pad + line.px * 0.2;
            puff.fire();
        }
    }

    readonly property bool done: !line.still && line.t >= line.lineEnd
    onDoneChanged: {
        if (!line.lineOnly && line.done && line.playing && line.rush > 0.25 && line.index < line.curIndex
                && line.t - line.lineEnd < 0.35 && line.mainIdx.length > 0) {
            signoff.x = line.center(line.mainIdx[line.mainIdx.length - 1]);
            signoff.y = line.pad + line.px * 0.2;
            signoff.fire();
        }
    }

    Item {
        id: holder
        width: line.blank ? line.px * 3.4 : Math.max(1, row.implicitWidth)
        height: line.blank ? line.px * 1.4 : row.implicitHeight + 2 * line.pad
        x: -width / 2
        y: -height / 2
        transformOrigin: Item.Center
        scale: line.pose.scale * (1 + 0.06 * line.land) * LM.fit(row.implicitWidth, line.maxW)
        rotation: line.pose.rot
        opacity: line.pose.opacity * line.dim
        visible: opacity > 0.01

        Row {
            id: row
            y: line.pad
            visible: !line.blank

            Repeater {
                id: reps
                model: line.toks

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index

                    readonly property bool ad: modelData.adlib === true
                    readonly property real sizeK: cell.ad ? 0.68 : 1
                    readonly property real fullW: Math.round(wordItem.implicitWidth * cell.sizeK)
                    readonly property real gapW: modelData.gap ? Math.round(line.px * 0.28) : 0
                    readonly property var span: line.sp[index]
                    readonly property real sungV: (line.litOn && span !== undefined)
                        ? (line.lineOnly ? line.wholeLit : LM.sung(span, line.t)) : 0
                    readonly property real stagger: 0.13
                    readonly property real wave: Math.max(0, Math.min(1,
                        (1 - line.d) * (1 + stagger * (line.toks.length - 1)) - index * stagger))
                    readonly property real lift: (!line.lineOnly && line.d > -0.01 && line.d < 1)
                        ? Math.sin(Math.PI * wave) : 0
                    readonly property real hitV: (!line.lineOnly && line.singing && line.playing)
                        ? LM.hit(line.sp, index, line.t) : 0

                    width: gapW + fullW
                    height: wordItem.implicitHeight

                    SekaiLyricsWord {
                        id: wordItem
                        x: cell.gapW - (wordItem.implicitWidth - cell.fullW) / 2
                        y: -line.px * 0.22 * cell.lift + 2.5 * cell.hitV - (cell.ad ? line.px * 0.1 : 0)
                        text: cell.modelData.s
                        pixelSize: line.px
                        withFill: line.litOn
                        sung: cell.sungV
                        litColor: cell.ad ? line.colSecondary : line.colPrimary
                        scale: cell.sizeK * (1 + 0.11 * cell.lift)
                        rotation: cell.ad ? -3 : 0
                        transformOrigin: Item.Bottom

                        transform: Scale {
                            origin.x: wordItem.width / 2
                            origin.y: wordItem.height
                            xScale: 1 + 0.07 * cell.hitV
                            yScale: 1 - 0.15 * cell.hitV
                        }
                    }
                }
            }
        }

        // Bouncing diamond marker
        Item {
            id: marker
            readonly property int hereM: Math.max(0, line.kmAny)
            readonly property int thereM: Math.min(marker.hereM + 1, Math.max(0, line.mainIdx.length - 1))
            readonly property int here: line.mainIdx.length > 0 ? line.mainIdx[marker.hereM] : 0
            readonly property int there: line.mainIdx.length > 0 ? line.mainIdx[marker.thereM] : 0
            readonly property bool laidOut: row.implicitWidth > 0
            readonly property real ax: laidOut ? line.center(here) : 0
            readonly property real bx: laidOut ? line.center(there) : 0
            readonly property real arch: LM.arch(line.hopP)
            readonly property real archK: (line.hasBg ? 0.5 : 0.82) * (1 - 0.5 * line.heldAbove)
            property real presence: line.singing ? 1 : 0

            Behavior on presence {
                NumberAnimation {
                    duration: line.singing ? 200 : 260
                    easing.type: line.singing ? Easing.OutBack : Easing.InCubic
                }
            }

            visible: !line.blank && !line.lineOnly && marker.presence > 0.01
            x: ax + (bx - ax) * line.hopP
            y: line.pad - line.px * 0.15 - arch * line.px * marker.archK
            rotation: 180 * line.hopP
            scale: (1 + 0.28 * arch) * Math.max(0, marker.presence)

            SekaiDiamond {
                anchors.centerIn: parent
                lit: true
                litColor: line.colSecondary
                lineColor: line.colOutline
                size: Math.max(8, Math.round(line.px * 0.30))
            }
        }

        SekaiBurst {
            id: puff
            count: 6
            radius: line.px * 0.9
            size: Math.max(5, Math.round(line.px * 0.2))
        }

        SekaiBurst {
            id: signoff
            count: 8
            radius: line.px * 1.1
            size: Math.max(5, Math.round(line.px * 0.22))
        }

        // Simultaneous backing vocal / ad-lib row
        Row {
            id: bgRow
            visible: line.hasBg && line.bgIn > 0.01
            opacity: line.bgIn
            spacing: Math.round(line.bgPx * 0.3)
            x: Math.round((row.implicitWidth - bgRow.width) / 2)
            y: Math.round(line.pad - bgRow.height * 0.8 + line.px * 0.22 + (1 - line.bgIn) * 8)

            Repeater {
                model: line.bgToks
                delegate: SekaiLyricsWord {
                    required property var modelData
                    required property int index
                    text: modelData.s
                    pixelSize: line.bgPx
                    withFill: true
                    litColor: line.colSecondary
                    sung: line.lineOnly ? line.bgWholeLit : (line.bgSp[index] ? LM.sung(line.bgSp[index], line.t) : 0)
                }
            }
        }

        // Intro / instrumental 3-diamond breathing gap
        Row {
            visible: line.blank
            anchors.centerIn: parent
            spacing: Math.round(line.px * 0.42)

            Repeater {
                model: 3
                delegate: Item {
                    id: bead
                    required property int index
                    readonly property real room: Math.max(0.5, line.lineEnd - line.lineStart)
                    readonly property real leaving: line.isCur ? Math.max(0, Math.min(1, (line.lineEnd - line.t) / 0.5)) : 1
                    readonly property real breath: (line.isCur && line.playing) ? 1 + 0.14 * Math.sin(line.t * 5 + index * 1.1) : 1

                    width: Math.max(8, Math.round(line.px * 0.30))
                    height: width
                    scale: Math.max(0.001, leaving * breath)

                    SekaiDiamond {
                        anchors.centerIn: parent
                        size: bead.width
                        lit: line.isCur && line.t >= line.lineStart + (bead.index + 1) * bead.room / 4.2
                        litColor: line.colSecondary
                        offColor: "#FFFFFF"
                        lineColor: line.colOutline
                    }
                }
            }
        }
    }
}
