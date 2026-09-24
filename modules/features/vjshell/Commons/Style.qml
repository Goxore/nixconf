pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string barEdge: "left"
    readonly property bool barOnLeft: barEdge === "left"
    readonly property bool barExclusive: true

    readonly property int barWidth: 40
    readonly property int barPadding: 11
    readonly property int barInset: 4
    readonly property int itemSize: 32
    readonly property int clockRule: 12
    readonly property int wheelStep: 120
    readonly property int tooltipMaxWidth: 240
    readonly property int tooltipHeight: 24
    readonly property int callRing: 2
    readonly property int callBadge: 12
    readonly property int spacing: 4
    readonly property int groupSpacing: 12

    readonly property int dotSize: 18

    readonly property int agentDotSize: 5
    readonly property int projectBarHeight: 30
    readonly property int projectNameMax: 180
    readonly property int iconGridCell: 48

    readonly property int radiusXs: 4
    readonly property int radiusS: 8
    readonly property int radiusM: 12
    readonly property int radiusL: 16
    readonly property int radiusXl: 28
    readonly property int radiusFull: 999

    readonly property int buttonHeight: 40
    readonly property int buttonHeightS: 32
    readonly property int buttonPadding: 24
    readonly property int buttonPaddingLeading: 16
    readonly property int buttonPaddingCompact: 12
    readonly property int buttonGap: 8
    readonly property int touchTarget: 48
    readonly property int iconButtonSize: 40
    readonly property int iconButtonSizeS: 32
    readonly property int listItemOneLine: 48
    readonly property int listItemTwoLine: 64
    readonly property int listItemDense: 40
    readonly property int tabHeight: 48
    readonly property int tabIndicator: 3
    readonly property int musicPaneWidth: 280
    readonly property int musicWidth: 1080
    readonly property int musicHeight: 792
    readonly property int sliderTrack: 16
    readonly property int sliderHandle: 4
    readonly property int switchWidth: 52
    readonly property int switchHeight: 32
    readonly property int switchBorder: 2
    readonly property int switchHandleOff: 16
    readonly property int switchHandleOn: 24
    readonly property int switchHandlePressed: 28
    readonly property int switchIcon: 16
    readonly property int scrollBarWidth: 4
    readonly property int scrollBarInset: 5
    readonly property int progressHeight: 4
    readonly property int focusRing: 2
    readonly property int emptyIconBox: 64
    readonly property int listGap: 2
    readonly property int iconBox: 32
    readonly property int dayCell: 40
    readonly property int avatarSize: 56
    readonly property int badgeSize: 8
    readonly property int badgeInset: 3
    readonly property int gaugeSize: 76
    readonly property int gaugeStroke: 7
    readonly property int actionsWidth: 152
    readonly property int processColumn: 64

    readonly property int listMax: 380
    readonly property int listMin: 44

    readonly property int panelPadding: 16
    readonly property int panelWidth: 384
    readonly property int panelWidthL: 480
    readonly property int panelMaxHeight: 520
    readonly property int panelMaxHeightL: 660
    readonly property int launcherWidth: 600
    readonly property int menuWidth: 240
    readonly property int menuTile: 64
    readonly property int menuLabel: 112
    readonly property int osdWidth: 260
    readonly property int osdMargin: 80
    readonly property int lyricsTop: 24
    readonly property int lyricsWidth: 1200
    readonly property int lyricsHeight: 200
    readonly property real lyricsMinScale: 0.4
    readonly property real lyricsMaxScale: 3
    readonly property int osdTrack: 6
    readonly property int osdValueWidth: 40
    readonly property int osdSettle: 1000
    readonly property int osdTimeout: 2000
    readonly property int scanTimeout: 30000
    readonly property int notificationSlide: 40

    readonly property int surfacePad: 32

    readonly property int borderWidth: 1
    readonly property int dividerWidth: 1

    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.12
    readonly property real statePress: 0.12
    readonly property real stateRipple: 0.10
    readonly property real opacityDim: 0.60
    readonly property real pressScale: 0.92
    readonly property int rippleMinSize: 32

    readonly property var elevationBlur: [0, 8, 16, 28]
    readonly property var elevationSpread: [0, 0, 0, 2]
    readonly property var elevationY: [0, 1, 3, 6]

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string iconFontFamily: "Material Symbols Rounded"
    readonly property int iconSize: 18
    readonly property int iconSizeL: 20
    readonly property int iconSizeXl: 22
    readonly property int iconSizeHero: 32
    readonly property int logoSize: 22
    readonly property int iconWeight: 400
    readonly property int iconWeightActive: 500

    readonly property var typeScale: ({
            displaySmall: {
                size: 36,
                lineHeight: 44,
                weight: Font.Normal,
                tracking: 0
            },
            headlineLarge: {
                size: 32,
                lineHeight: 40,
                weight: Font.Normal,
                tracking: 0
            },
            headlineMedium: {
                size: 28,
                lineHeight: 36,
                weight: Font.Normal,
                tracking: 0
            },
            headlineSmall: {
                size: 24,
                lineHeight: 32,
                weight: Font.Normal,
                tracking: 0
            },
            titleLarge: {
                size: 22,
                lineHeight: 28,
                weight: Font.Normal,
                tracking: 0
            },
            titleMedium: {
                size: 16,
                lineHeight: 24,
                weight: Font.Medium,
                tracking: 0.15
            },
            titleSmall: {
                size: 14,
                lineHeight: 20,
                weight: Font.Medium,
                tracking: 0.1
            },
            bodyLarge: {
                size: 16,
                lineHeight: 24,
                weight: Font.Normal,
                tracking: 0.5
            },
            bodyMedium: {
                size: 14,
                lineHeight: 20,
                weight: Font.Normal,
                tracking: 0.25
            },
            bodySmall: {
                size: 12,
                lineHeight: 16,
                weight: Font.Normal,
                tracking: 0.4
            },
            labelLarge: {
                size: 14,
                lineHeight: 20,
                weight: Font.Medium,
                tracking: 0.1
            },
            labelMedium: {
                size: 12,
                lineHeight: 16,
                weight: Font.Medium,
                tracking: 0.5
            },
            labelSmall: {
                size: 11,
                lineHeight: 16,
                weight: Font.Medium,
                tracking: 0.5
            }
        })

    function typeFor(role) {
        return typeScale[role] || typeScale.bodyMedium;
    }

    readonly property int durShort2: 100
    readonly property int durShort3: 150
    readonly property int durShort4: 200
    readonly property int durMedium1: 250
    readonly property int durMedium2: 300
    readonly property int durMedium4: 400
    readonly property int durLong: 1200

    readonly property int durState: durShort2
    readonly property int durEnter: durMedium1
    readonly property int durExit: durShort4
    readonly property int durMorph: durMedium1
    readonly property int durRipple: durMedium1
    readonly property int durResize: durShort4

    readonly property int tooltipDelay: 450

    readonly property var standard: [0.20, 0.00, 0.00, 1.00, 1.00, 1.00]
    readonly property var emphasized: [0.05, 0.00, 0.133333, 0.06, 0.166666, 0.40, 0.208333, 0.82, 0.25, 1.00, 1.00, 1.00]
    readonly property var emphasizedDecelerate: [0.05, 0.70, 0.10, 1.00, 1.00, 1.00]
    readonly property var emphasizedAccelerate: [0.30, 0.00, 0.80, 0.15, 1.00, 1.00]
}
