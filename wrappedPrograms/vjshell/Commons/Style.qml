pragma Singleton

import Quickshell

Singleton {
    readonly property string barEdge: "left"
    readonly property bool barOnLeft: barEdge === "left"
    readonly property bool barExclusive: true

    readonly property int barWidth: 40
    readonly property int barPadding: 11
    readonly property int barInset: 4
    readonly property int itemSize: 24
    readonly property int spacing: 4
    readonly property int groupSpacing: 16

    readonly property int dotSize: 18
    readonly property int pillLength: 37

    readonly property int radiusXs: 4
    readonly property int radiusS: 8
    readonly property int radiusM: 12
    readonly property int radiusL: 16
    readonly property int radiusXl: 28
    readonly property int radiusFull: 999

    readonly property int rowHeightS: 28
    readonly property int rowHeight: 44
    readonly property int rowHeightM: 48
    readonly property int rowHeightL: 52
    readonly property int buttonHeight: 28
    readonly property int separatorHeight: 8
    readonly property int iconBoxS: 28
    readonly property int iconBox: 32
    readonly property int badgeSize: 8

    readonly property int listMax: 380
    readonly property int listMaxM: 320
    readonly property int listMaxS: 300
    readonly property int listMin: 44
    readonly property int listMinS: 40

    readonly property int panelPadding: 12
    readonly property int panelWidth: 360
    readonly property int panelMaxHeight: 520
    readonly property int launcherWidth: 560
    readonly property int menuWidth: 240
    readonly property int osdWidth: 260
    readonly property int osdHeight: 56
    readonly property int osdMargin: 80

    readonly property int surfacePad: 32

    readonly property int borderWidth: 1
    readonly property int dividerWidth: 1
    readonly property int accentBarWidth: 3

    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.10
    readonly property real statePress: 0.12
    readonly property real stateRipple: 0.10
    readonly property real opacityDisabled: 0.38
    readonly property real opacityDim: 0.60
    readonly property real pressScale: 0.92
    readonly property int rippleMinSize: 32

    readonly property var elevationBlur: [0, 8, 16, 28]
    readonly property var elevationSpread: [0, 0, 0, 2]
    readonly property var elevationY: [0, 1, 3, 6]

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string iconFontFamily: "Material Symbols Rounded"
    readonly property int fontSize: 12
    readonly property int fontSizeSmall: 10
    readonly property int fontSizeLarge: 14
    readonly property int fontSizeXl: 16
    readonly property int fontSizeXxl: 20
    readonly property int iconSize: 16
    readonly property int iconSizeM: 18
    readonly property int iconSizeL: 20
    readonly property int iconSizeXl: 22
    readonly property int logoSize: 22
    readonly property int iconWeight: 400
    readonly property int iconWeightActive: 500

    readonly property int durShort1: 50
    readonly property int durShort2: 100
    readonly property int durShort3: 150
    readonly property int durShort4: 200
    readonly property int durMedium1: 250
    readonly property int durMedium2: 300
    readonly property int durMedium3: 350
    readonly property int durMedium4: 400

    readonly property int durState: durShort2
    readonly property int durEnter: durMedium1
    readonly property int durExit: durShort4
    readonly property int durMorph: durMedium1
    readonly property int durRipple: durMedium1
    readonly property int durResize: durShort4

    readonly property int staggerStep: 30
    readonly property int tooltipDelay: 450

    readonly property var standard: [0.20, 0.00, 0.00, 1.00, 1.00, 1.00]
    readonly property var standardDecelerate: [0.00, 0.00, 0.00, 1.00, 1.00, 1.00]
    readonly property var standardAccelerate: [0.30, 0.00, 1.00, 1.00, 1.00, 1.00]
    readonly property var emphasized: [0.05, 0.00, 0.133333, 0.06, 0.166666, 0.40, 0.208333, 0.82, 0.25, 1.00, 1.00, 1.00]
    readonly property var emphasizedDecelerate: [0.05, 0.70, 0.10, 1.00, 1.00, 1.00]
    readonly property var emphasizedAccelerate: [0.30, 0.00, 0.80, 0.15, 1.00, 1.00]
}
