import QtQuick
import QtQuick.Layouts
import qs.Commons

Pressable {
    id: root

    property string text: ""
    property string icon: ""

    readonly property string leadingIcon: selected ? Icons.check : icon
    readonly property color contentColor: {
        if (!enabled)
            return Theme.disabledContent;
        return selected ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant;
    }

    implicitWidth: row.implicitWidth + (leadingIcon !== "" ? Style.buttonGap : Style.panelPadding) + Style.panelPadding
    implicitHeight: Style.buttonHeightS

    description: text
    Accessible.role: Accessible.CheckBox

    cornerRadius: Style.radiusS
    layerColor: contentColor

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusS
        color: !root.selected ? "transparent" : root.enabled ? Theme.secondaryContainer : Theme.disabledContainer
        border.width: root.selected ? 0 : Style.borderWidth
        border.color: !root.enabled ? Theme.disabledOutline : root.activeFocus ? Theme.primary : Theme.outlineVariant

        Behavior on color {
            ColorMotion {}
        }
    }

    RowLayout {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        x: root.leadingIcon !== "" ? Style.buttonGap : Style.panelPadding
        spacing: Style.buttonGap

        MaterialIcon {
            visible: root.leadingIcon !== ""
            text: root.leadingIcon
            fill: root.selected ? 1 : 0
            color: root.contentColor
        }

        Label {
            text: root.text
            role: "labelLarge"
            color: root.contentColor
            elide: Text.ElideNone
        }
    }
}
