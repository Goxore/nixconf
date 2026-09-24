import QtQuick
import Quickshell
import qs.Commons
import qs.Services

Pressable {
    id: root

    property string icon
    property color iconColor: Theme.inkSurfaceVariant
    property real iconFill: 0
    property alias tooltip: hint.text

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    implicitWidth: Style.itemSize
    implicitHeight: Style.itemSize

    description: tooltip
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    wheelEnabled: true
    cornerRadius: Style.radiusS
    layerColor: iconColor

    onPressedChanged: if (pressed)
        TooltipService.hide()

    BarHint {
        id: hint
        target: root
        hovered: root.hovered && !root.pressed
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        fill: root.iconFill
        scale: root.pressed ? Style.pressScale : 1

        Behavior on scale {
            NumberMotion {
                duration: Style.durShort2
            }
        }
    }
}
