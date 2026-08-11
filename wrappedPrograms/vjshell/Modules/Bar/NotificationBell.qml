import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    id: root

    icon: NotificationService.dnd ? Icons.bellOff : Icons.bell
    iconColor: NotificationService.dnd ? Theme.textDim : Theme.text

    onClicked: PanelService.toggle("notifications")
    onRightClicked: {
        NotificationService.dnd = !NotificationService.dnd;
        if (NotificationService.dnd)
            NotificationService.clearPopups();
    }

    Rectangle {
        visible: NotificationService.unread > 0 && !NotificationService.dnd

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 2
        anchors.topMargin: 2

        width: 8
        height: 8
        radius: 4
        color: Theme.occupied
    }
}
