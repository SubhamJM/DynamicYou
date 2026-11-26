import QtQuick

// Dot-matrix ShaderEffect overlay matching Nothing OS Glyph dots.frag.qsb
ShaderEffect {
    property real step: 5.5
    readonly property real pitch: step
    property bool circle: false
    readonly property real circ: circle ? 1.0 : 0.0
    readonly property size size: Qt.size(Math.max(1, width), Math.max(1, height))
    fragmentShader: Qt.resolvedUrl("shaders/dots.frag.qsb")
}
