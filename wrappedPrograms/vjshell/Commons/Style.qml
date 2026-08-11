pragma Singleton

import Quickshell

Singleton {
    readonly property string barEdge: "left"
    readonly property bool barOnLeft: barEdge === "left"

    readonly property bool barExclusive: true

    readonly property int barWidth: 40
    readonly property int barPadding: 11
    readonly property int itemSize: 24
    readonly property int spacing: 4
    readonly property int groupSpacing: 16

    readonly property int dotSize: 18
    readonly property int pillLength: 37

    readonly property int radius: 8
    readonly property int panelPadding: 12
    readonly property int panelWidth: 360

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string iconFontFamily: "Material Symbols Rounded"
    readonly property int fontSize: 12
    readonly property int fontSizeSmall: 10
    readonly property int iconSize: 16
    readonly property int logoSize: 22

    readonly property int animFast: 120
    readonly property int animNormal: 200
}
