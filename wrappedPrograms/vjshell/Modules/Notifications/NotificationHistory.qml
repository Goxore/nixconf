import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    panelName: "notifications"
    title: "Notifications"

    onVisibleChanged: if (visible)
        NotificationService.markRead()

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        Text {
            Layout.fillWidth: true
            text: NotificationService.history.length === 0 ? "" : NotificationService.history.length + (NotificationService.history.length === 1 ? " notification" : " notifications")
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: Theme.textDim
        }

        PanelButton {
            text: NotificationService.dnd ? "DND on" : "DND off"
            accent: NotificationService.dnd
            onClicked: {
                NotificationService.dnd = !NotificationService.dnd;
                if (NotificationService.dnd)
                    NotificationService.clearPopups();
            }
        }

        PanelButton {
            text: "Clear"
            enabled: NotificationService.history.length > 0
            onClicked: NotificationService.clearHistory()
        }
    }

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(56, Math.min(contentHeight, 380))

        clip: true
        spacing: Style.spacing
        model: NotificationService.history

        delegate: HistoryRow {
            required property var modelData
            required property int index

            width: list.width
            record: modelData
            onDismissed: NotificationService.removeAt(index)
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: "Nothing here"
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: Theme.textDim
        }
    }

    component HistoryRow: Rectangle {
        id: row

        required property var record

        signal dismissed

        readonly property bool critical: record.urgency === NotificationUrgency.Critical

        implicitHeight: rowLayout.implicitHeight + Style.panelPadding * 2
        radius: Style.radius
        color: hover.hovered ? Theme.surfaceHigh : Theme.surfaceVariant

        Behavior on color {
            ColorAnimation {
                duration: Style.animFast
            }
        }

        HoverHandler {
            id: hover
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: width / 2
            color: row.critical ? Theme.urgent : Theme.accent
        }

        RowLayout {
            id: rowLayout

            anchors.fill: parent
            anchors.margins: Style.panelPadding
            anchors.leftMargin: Style.panelPadding + 4
            spacing: Style.spacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.spacing

                    Text {
                        Layout.fillWidth: true
                        text: row.record.summary
                        elide: Text.ElideRight
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        font.weight: Font.Bold
                        color: row.critical ? Theme.urgent : Theme.textBright
                    }

                    Text {
                        text: row.record.time
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        color: Theme.textDim
                    }

                    MaterialIcon {
                        opacity: hover.hovered ? 1 : 0
                        text: Icons.close
                        font.pixelSize: Style.fontSize
                        color: dismissHover.hovered ? Theme.urgent : Theme.textDim

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Style.animFast
                            }
                        }

                        HoverHandler {
                            id: dismissHover
                        }

                        TapHandler {
                            onTapped: row.dismissed()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.record.body
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.record.appName
                    elide: Text.ElideRight
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    color: Theme.textDim
                }
            }
        }
    }
}
