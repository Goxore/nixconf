import QtQuick
import qs.Commons

Pressable {
    id: root

    property string icon: ""
    property string variant: "standard"
    property string tone: "primary"
    property bool compact: false

    readonly property var palette: Theme.tone(tone)
    readonly property bool filled: variant === "filled" || (variant === "toggle" && selected)
    readonly property bool tonal: variant === "tonal"
    readonly property bool outlined: variant === "outlined"
    readonly property int boxSize: compact ? Style.iconButtonSizeS : Style.iconButtonSize

    readonly property color containerColor: {
        if (!enabled)
            return filled || tonal ? Theme.disabledContainer : "transparent";
        if (filled)
            return palette.color;
        if (tonal)
            return palette.container;
        return "transparent";
    }

    readonly property color contentColor: {
        if (!enabled)
            return Theme.disabledContent;
        if (filled)
            return palette.ink;
        if (tonal)
            return palette.inkContainer;
        if (selected)
            return palette.color;
        return Theme.inkSurfaceVariant;
    }

    implicitWidth: Math.max(boxSize, Style.touchTarget)
    implicitHeight: Math.max(boxSize, Style.touchTarget)

    Accessible.role: variant === "toggle" ? Accessible.CheckBox : Accessible.Button

    layerWidth: boxSize
    layerHeight: boxSize
    cornerRadius: box.radius
    layerColor: contentColor

    Rectangle {
        id: box

        anchors.centerIn: parent
        width: root.boxSize
        height: root.boxSize
        radius: root.pressed ? Style.radiusS : height / 2
        color: root.containerColor
        border.width: root.outlined ? Style.borderWidth : 0
        border.color: root.enabled ? Theme.outlineVariant : Theme.disabledOutline

        Behavior on color {
            ColorMotion {}
        }

        Behavior on radius {
            NumberMotion {
                easing.bezierCurve: Style.emphasizedDecelerate
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            font.pixelSize: root.compact ? Style.iconSize : Style.iconSizeXl
            fill: root.selected || root.filled ? 1 : 0
            color: root.contentColor
        }
    }
}
