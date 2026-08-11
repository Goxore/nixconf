import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    visible: NotificationService.popups.length > 0

    anchors {
        top: true
        right: true
    }
    margins {
        top: Style.barPadding
        right: Style.barPadding
    }
    exclusiveZone: 0

    implicitWidth: Style.panelWidth
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-notifications"

    mask: Region {
        item: column
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: Style.spacing

        Repeater {
            model: NotificationService.popups

            delegate: NotificationCard {
                required property var modelData

                Layout.fillWidth: true
                notification: modelData

                onDismissed: NotificationService.dismissPopup(modelData)
            }
        }
    }
}
