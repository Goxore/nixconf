import QtQuick
import QtQuick.Layouts
import qs.Commons

Pressable {
    id: root

    property string text: ""
    property string icon: ""
    property string trailingIcon: ""
    property string variant: "tonal"
    property string tone: "primary"
    property bool compact: false

    readonly property var palette: Theme.tone(tone)
    readonly property bool filled: variant === "filled" || (variant === "toggle" && selected)
    readonly property bool tonal: variant === "tonal"
    readonly property bool outlined: variant === "outlined" || (variant === "toggle" && !selected)

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
        return palette.color;
    }

    readonly property int leadingPad: compact ? Style.buttonPaddingCompact : icon !== "" ? Style.buttonPaddingLeading : Style.buttonPadding
    readonly property int trailingPad: compact ? Style.buttonPaddingCompact : trailingIcon !== "" ? Style.buttonPaddingLeading : Style.buttonPadding

    implicitWidth: Math.max(row.implicitWidth + leadingPad + trailingPad, Style.touchTarget)
    implicitHeight: compact ? Style.buttonHeightS : Style.buttonHeight

    description: text
    Accessible.role: variant === "toggle" ? Accessible.CheckBox : Accessible.Button

    cornerRadius: container.radius
    layerColor: contentColor

    Rectangle {
        id: container

        anchors.fill: parent
        radius: root.pressed ? Style.radiusS : height / 2
        color: root.containerColor
        border.width: root.outlined ? Style.borderWidth : 0
        border.color: !root.enabled ? Theme.disabledOutline : root.activeFocus ? root.palette.color : Theme.outlineVariant

        Behavior on color {
            ColorMotion {}
        }

        Behavior on radius {
            NumberMotion {
                easing.bezierCurve: Style.emphasizedDecelerate
            }
        }
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: (root.leadingPad - root.trailingPad) / 2
        spacing: Style.buttonGap

        MaterialIcon {
            visible: root.icon !== ""
            text: root.icon
            fill: root.filled ? 1 : 0
            color: root.contentColor
        }

        Label {
            visible: root.text !== ""
            text: root.text
            role: "labelLarge"
            color: root.contentColor
            elide: Text.ElideNone
        }

        MaterialIcon {
            visible: root.trailingIcon !== ""
            text: root.trailingIcon
            color: root.contentColor
        }
    }
}
