import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
    id: root

    property var model: []
    property string current: ""

    signal selected(string key)

    readonly property int count: Math.max(1, model.length)
    readonly property real slot: width / count
    readonly property int index: Math.max(0, model.findIndex(entry => entry.key === current))
    readonly property Item activeTab: tabs.count > 0 ? tabs.itemAt(index) : null

    implicitWidth: Style.listMin
    implicitHeight: Style.tabHeight

    Divider {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    Row {
        anchors.fill: parent

        Repeater {
            id: tabs

            model: root.model

            Pressable {
                id: tab

                required property var modelData

                readonly property bool active: root.current === modelData.key
                readonly property color contentColor: active ? Theme.primary : Theme.inkSurfaceVariant
                readonly property real contentWidth: content.implicitWidth

                width: root.slot
                height: root.height

                description: modelData.label
                selected: active
                Accessible.role: Accessible.PageTab
                layerColor: contentColor
                cornerRadius: 0

                onClicked: root.selected(modelData.key)

                ColumnLayout {
                    id: content

                    anchors.centerIn: parent
                    spacing: 2

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !!tab.modelData.icon
                        text: tab.modelData.icon ?? ""
                        font.pixelSize: Style.iconSizeL
                        fill: tab.active ? 1 : 0
                        color: tab.contentColor
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: tab.modelData.label
                        role: "titleSmall"
                        color: tab.contentColor
                    }
                }
            }
        }
    }

    Rectangle {
        readonly property real span: root.activeTab ? root.activeTab.contentWidth : 0

        anchors.bottom: parent.bottom
        x: root.slot * root.index + (root.slot - width) / 2
        width: span
        height: Style.tabIndicator
        topLeftRadius: height
        topRightRadius: height
        color: Theme.primary

        Behavior on x {
            NumberMotion {
                duration: Style.durMedium1
                easing.bezierCurve: Style.emphasized
            }
        }

        Behavior on width {
            NumberMotion {
                duration: Style.durMedium1
                easing.bezierCurve: Style.emphasized
            }
        }
    }
}
