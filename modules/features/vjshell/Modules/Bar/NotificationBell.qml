import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    readonly property bool open: PanelService.isOpen("notifications", screenName)

    icon: NotificationService.dnd ? Icons.bellOff : Icons.bell
    iconColor: open ? Theme.primary : Theme.inkSurfaceVariant
    iconFill: open || NotificationService.unread > 0 && !NotificationService.dnd ? 1 : 0
    tooltip: {
        if (NotificationService.dnd)
            return "Do not disturb";
        if (NotificationService.unread === 1)
            return "1 new notification";
        if (NotificationService.unread > 1)
            return NotificationService.unread + " new notifications";
        return "Notifications";
    }

    onClicked: PanelService.toggle("notifications", screenName)
    onRightClicked: NotificationService.toggleDnd()

    Badge {
        shown: NotificationService.unread > 0 && !NotificationService.dnd
    }
}
