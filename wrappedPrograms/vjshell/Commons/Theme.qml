pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property color surface: Colors.base00
    readonly property color surfaceVariant: Colors.base01
    readonly property color surfaceHigh: Colors.base02
    readonly property color outline: Colors.base03

    readonly property color textDim: Colors.base04
    readonly property color text: Colors.base06
    readonly property color textBright: Colors.base07

    readonly property color accent: Colors.base0D
    readonly property color active: Colors.base0B
    readonly property color occupied: Colors.base0A
    readonly property color warning: Colors.base09
    readonly property color urgent: Colors.base08

    readonly property color scrim: Qt.rgba(0, 0, 0, 0.55)

    readonly property color stateLayer: text

    readonly property var shadowLevels: [Qt.rgba(0, 0, 0, 0.00), Qt.rgba(0, 0, 0, 0.22), Qt.rgba(0, 0, 0, 0.30), Qt.rgba(0, 0, 0, 0.38)]

    function shadowFor(level) {
        return shadowLevels[Math.max(0, Math.min(3, level))];
    }
}
