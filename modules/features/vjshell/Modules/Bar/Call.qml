pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
    id: root

    visible: DiscordCallService.connected
    spacing: Style.spacing

    Repeater {
        model: DiscordCallService.participants

        delegate: Item {
            id: person

            required property var modelData

            readonly property bool quiet: modelData.deafened || modelData.muted
            readonly property string badge: modelData.deafened ? Icons.headsetOff : modelData.muted ? Icons.micOff : modelData.streaming ? Icons.screenShare : ""
            readonly property string state: modelData.deafened ? "deafened" : modelData.muted ? "muted" : modelData.streaming ? "streaming" : ""

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Style.itemSize
            implicitHeight: Style.itemSize

            HoverHandler {
                id: hover
            }

            BarHint {
                target: person
                text: person.state === "" ? person.modelData.name : person.modelData.name + ", " + person.state
                hovered: hover.hovered
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + Style.callRing * 2
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Style.callRing
                border.color: Theme.success
                opacity: person.modelData.speaking ? 1 : 0

                Behavior on opacity {
                    NumberMotion {}
                }
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.surfaceContainerHighest
                opacity: person.quiet ? Style.opacityDim : 1

                Behavior on opacity {
                    NumberMotion {}
                }

                Image {
                    anchors.fill: parent
                    source: person.modelData.avatar
                    sourceSize.width: parent.width * 2
                    sourceSize.height: parent.height * 2
                    asynchronous: true
                    smooth: true
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: person.badge !== ""
                width: Style.callBadge
                height: Style.callBadge
                radius: width / 2
                color: Theme.surface

                MaterialIcon {
                    anchors.centerIn: parent
                    text: person.badge
                    font.pixelSize: Style.callBadge - 2
                    fill: 1
                    color: person.modelData.streaming ? Theme.success : Theme.error
                }
            }
        }
    }
}
