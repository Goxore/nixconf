import QtQuick
import qs.Commons

Pressable {
    id: root

    property bool checked: false

    signal toggled(bool value)

    readonly property real handleSize: pressed ? Style.switchHandlePressed : checked ? Style.switchHandleOn : Style.switchHandleOff

    implicitWidth: Style.switchWidth + Style.buttonGap
    implicitHeight: Style.touchTarget

    selected: checked
    Accessible.role: Accessible.CheckBox

    layerWidth: Style.touchTarget - Style.buttonGap
    layerHeight: Style.touchTarget - Style.buttonGap
    cornerRadius: layerWidth / 2
    layerOffset: track.x + handle.x + handle.width / 2 - width / 2
    layerColor: checked ? Theme.primary : Theme.inkSurface

    onClicked: toggled(!checked)

    Rectangle {
        id: track

        anchors.centerIn: parent
        width: Style.switchWidth
        height: Style.switchHeight
        radius: height / 2
        color: !root.enabled ? Theme.disabledContainer : root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : Style.switchBorder
        border.color: root.enabled ? Theme.outline : Theme.disabledOutline

        Behavior on color {
            ColorMotion {}
        }

        Rectangle {
            id: handle

            readonly property real inset: (track.height - root.handleSize) / 2

            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? track.width - width - inset : inset
            width: root.handleSize
            height: root.handleSize
            radius: height / 2
            color: {
                if (!root.enabled)
                    return root.checked ? Theme.surface : Theme.disabledContent;
                if (root.checked)
                    return root.pressed || root.hovered ? Theme.primaryContainer : Theme.inkPrimary;
                return root.pressed || root.hovered ? Theme.inkSurfaceVariant : Theme.outline;
            }

            Behavior on x {
                NumberMotion {
                    duration: Style.durShort4
                    easing.bezierCurve: Style.emphasized
                }
            }

            Behavior on width {
                NumberMotion {
                    duration: Style.durShort4
                    easing.bezierCurve: Style.emphasized
                }
            }

            Behavior on color {
                ColorMotion {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: root.checked
                text: Icons.check
                font.pixelSize: Style.switchIcon
                fill: 1
                color: root.enabled ? Theme.inkPrimaryContainer : Theme.disabledContent
            }
        }
    }
}
