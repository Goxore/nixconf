import QtQuick
import QtQuick.Controls
import qs.Commons

ScrollBar {
    id: root

    policy: ScrollBar.AsNeeded
    padding: 1

    contentItem: Rectangle {
        implicitWidth: Style.scrollBarWidth
        implicitHeight: Style.touchTarget / 2
        radius: width / 2
        color: root.pressed ? Theme.primary : Theme.outline
        opacity: root.size >= 1 ? 0 : root.active || root.hovered ? 1 : 0.35

        Behavior on opacity {
            NumberMotion {}
        }
    }
}
