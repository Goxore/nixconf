import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    id: root

    icon: NotificationService.dnd ? Icons.bellOff : Icons.bell
    iconColor: NotificationService.dnd ? Theme.textDim : Theme.text
    iconFill: NotificationService.unread > 0 && !NotificationService.dnd ? 1 : 0

    onClicked: PanelService.toggle("notifications")
    onRightClicked: {
        NotificationService.dnd = !NotificationService.dnd;
        if (NotificationService.dnd)
            NotificationService.clearPopups();
    }

    Rectangle {
        id: badge

        readonly property bool shown: NotificationService.unread > 0 && !NotificationService.dnd

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 2
        anchors.topMargin: 2

        width: Style.badgeSize
        height: Style.badgeSize
        radius: width / 2
        color: Theme.occupied

        transformOrigin: Item.Center
        scale: shown ? 1 : 0
        opacity: shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Style.durShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.emphasizedDecelerate
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Style.durShort4
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.standard
            }
        }
    }
}
