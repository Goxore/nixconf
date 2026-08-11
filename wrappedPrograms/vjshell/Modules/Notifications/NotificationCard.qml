import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Commons
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    required property var notification

    signal dismissed

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical

    implicitHeight: layout.implicitHeight + Style.panelPadding * 2
    radius: Style.radius
    color: Theme.surface
    border.width: 1
    border.color: critical ? Theme.urgent : Theme.surfaceHigh

    Timer {
        running: interval > 0 && !hover.hovered
        interval: NotificationService.timeoutFor(root.notification?.urgency)
        onTriggered: root.dismissed()
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.dismissed()
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Style.panelPadding
        spacing: Style.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.panelPadding

            Item {
                implicitWidth: 32
                implicitHeight: 32
                visible: image.visible || fallback.visible

                IconImage {
                    id: image
                    anchors.fill: parent
                    source: root.notification?.image || Quickshell.iconPath(root.notification?.appIcon ?? "", true)
                    visible: status === Image.Ready
                }

                MaterialIcon {
                    id: fallback
                    anchors.centerIn: parent
                    visible: !image.visible
                    text: Icons.bell
                    font.pixelSize: 22
                    color: root.critical ? Theme.urgent : Theme.textDim
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.notification?.summary ?? ""
                        elide: Text.ElideRight
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        font.weight: Font.Bold
                        color: root.critical ? Theme.urgent : Theme.textBright
                    }

                    Text {
                        text: root.notification?.appName ?? ""
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        color: Theme.textDim
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.notification?.body ?? ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    color: Theme.text
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: repeater.count > 0
            spacing: Style.spacing

            Repeater {
                id: repeater
                model: root.notification?.actions ?? []

                delegate: PanelButton {
                    required property var modelData
                    text: modelData.text || modelData.identifier
                    onClicked: {
                        modelData.invoke();
                        root.dismissed();
                    }
                }
            }
        }
    }
}
