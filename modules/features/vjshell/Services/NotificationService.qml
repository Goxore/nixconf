pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var history: []

    property var popups: []

    property bool dnd: false
    property int unread: 0
    property string screenName: ""

    readonly property int maxPopups: 3

    readonly property int maxHistory: 100

    function timeoutFor(notification) {
        if (notification && notification.expireTimeout >= 0)
            return notification.expireTimeout;
        switch (notification?.urgency) {
        case NotificationUrgency.Low:
            return 5000;
        case NotificationUrgency.Critical:
            return 0;
        default:
            return 8000;
        }
    }

    function snapshot(n) {
        return {
            id: n.id,
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            summary: n.summary || "",
            body: n.body || "",
            image: n.image || "",
            urgency: n.urgency,
            time: Qt.formatDateTime(new Date(), "HH:mm")
        };
    }

    function dismissPopup(notification, expired) {
        popups = popups.filter(n => n !== notification);
        if (notification) {
            if (expired)
                notification.expire();
            else
                notification.dismiss();
        }
    }

    function clearPopups() {
        const current = popups;
        popups = [];
        for (const n of current)
            n.dismiss();
    }

    function clearHistory() {
        history = [];
        unread = 0;
    }

    function removeAt(index) {
        const next = history.slice();
        next.splice(index, 1);
        history = next;
        unread = Math.min(unread, history.length);
    }

    function markRead() {
        unread = 0;
    }

    function toggleDnd() {
        dnd = !dnd;
        if (dnd)
            clearPopups();
    }

    NotificationServer {
        id: server

        keepOnReload: true

        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;

            root.history = [root.snapshot(notification)].concat(root.history.filter(n => n.id !== notification.id)).slice(0, root.maxHistory);
            root.unread = PanelService.isOpen("notifications") ? 0 : Math.min(root.unread + 1, root.maxHistory);

            if (root.dnd) {
                notification.expire();
                return;
            }
            if (root.popups.length === 0)
                root.screenName = MangoService.targetScreen;
            while (root.popups.length >= root.maxPopups)
                root.dismissPopup(root.popups[0], true);
            root.popups = root.popups.concat([notification]);

            notification.closed.connect(() => {
                root.popups = root.popups.filter(n => n !== notification);
            });
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            PanelService.toggle("notifications");
        }
        function open(): void {
            PanelService.open("notifications");
        }
        function close(): void {
            PanelService.close("notifications");
        }
        function clear(): void {
            root.clearHistory();
            root.clearPopups();
        }
        function dnd(): void {
            root.toggleDnd();
        }
    }
}
