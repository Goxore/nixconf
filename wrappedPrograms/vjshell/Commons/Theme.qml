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
}
