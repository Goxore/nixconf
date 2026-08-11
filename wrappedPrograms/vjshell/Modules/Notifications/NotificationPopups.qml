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
    visible: reveal.active

    anchors {
        top: true
        bottom: true
        right: true
    }
    exclusiveZone: 0

    implicitWidth: Style.panelWidth + Style.surfacePad * 2
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-notifications"

    mask: Region {
        item: column
    }

    Reveal {
        id: reveal
        open: NotificationService.popups.length > 0
    }

    ColumnLayout {
        id: column

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Style.barPadding
        anchors.rightMargin: Style.barPadding

        width: Style.panelWidth
        height: implicitHeight
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
