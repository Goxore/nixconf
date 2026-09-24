import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    name: "notifications"
    title: "Notifications"

    onOpenedChanged: if (opened)
        NotificationService.markRead()

    actions: [
        IconButton {
            icon: NotificationService.dnd ? Icons.bellOff : Icons.bell
            variant: "toggle"
            selected: NotificationService.dnd
            description: "Do not disturb"
            onClicked: NotificationService.toggleDnd()
        },
        IconButton {
            icon: Icons.clear
            description: "Clear all"
            enabled: NotificationService.history.length > 0
            onClicked: NotificationService.clearHistory()
        }
    ]

    Notice {
        visible: NotificationService.dnd
        icon: Icons.bellOff
        text: "Do not disturb is on. New notifications stay here without popping up."
    }

    EmptyState {
        visible: NotificationService.history.length === 0
        icon: Icons.emptyBell
        title: "You're all caught up"
        supporting: "New notifications will show up here"
    }

    ListGroup {
        Repeater {
            model: NotificationService.history

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                property bool first: true
                property bool last: true

                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + Style.panelPadding * 2

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: row.first ? Style.radiusL : Style.radiusXs
                    topRightRadius: topLeftRadius
                    bottomLeftRadius: row.last ? Style.radiusL : Style.radiusXs
                    bottomRightRadius: bottomLeftRadius
                    color: Theme.surfaceContainerHigh
                }

                NotificationContent {
                    id: content

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.panelPadding
                    appIcon: row.modelData.appIcon
                    image: row.modelData.image
                    appName: row.modelData.appName
                    time: row.modelData.time
                    summary: row.modelData.summary
                    body: row.modelData.body
                    critical: row.modelData.urgency === NotificationUrgency.Critical
                    maxLines: 3

                    IconButton {
                        icon: Icons.close
                        compact: true
                        description: "Remove"
                        onClicked: NotificationService.removeAt(row.index)
                    }
                }
            }
        }
    }
}
