import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    visible: NotificationService.popups.length > 0 && NotificationService.screenName === modelData.name
    color: "transparent"
    exclusiveZone: 0
    implicitWidth: Math.min(modelData.width, Style.panelWidth + Style.surfacePad * 2)

    anchors {
        top: true
        bottom: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-notifications"

    mask: Region {
        item: column
    }

    ColumnLayout {
        id: column

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Style.barPadding
        anchors.rightMargin: Style.barPadding
        width: Math.min(Style.panelWidth, root.width - Style.barPadding * 2)
        spacing: 0

        Repeater {
            model: NotificationService.popups

            delegate: NotificationCard {
                required property var modelData

                Layout.fillWidth: true
                notification: modelData
                onDismissed: expired => NotificationService.dismissPopup(modelData, expired)
            }
        }
    }
}
