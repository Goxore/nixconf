import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Widgets

RowLayout {
    id: root

    property string image: ""
    property string appIcon: ""
    property string appName: ""
    property string time: ""
    property string summary: ""
    property string body: ""
    property bool critical: false
    property int maxLines: 4

    default property alias trailing: slot.data

    readonly property string source: image || Quickshell.iconPath(appIcon, true)

    spacing: Style.groupSpacing

    Rectangle {
        Layout.alignment: Qt.AlignTop
        implicitWidth: Style.iconButtonSize
        implicitHeight: Style.iconButtonSize
        radius: width / 2
        color: root.critical ? Theme.errorContainer : Theme.surfaceContainerHighest

        IconImage {
            id: picture
            anchors.centerIn: parent
            implicitSize: Style.iconSizeXl + Style.spacing
            source: root.source
            visible: status === Image.Ready
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: !picture.visible
            text: root.critical ? Icons.error : Icons.bell
            fill: root.critical ? 1 : 0
            color: root.critical ? Theme.inkErrorContainer : Theme.inkSurfaceVariant
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.listGap

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: [root.appName, root.time].filter(part => part !== "").join(" · ")
            role: "labelMedium"
            color: root.critical ? Theme.error : Theme.inkSurfaceVariant
        }

        Label {
            Layout.fillWidth: true
            text: root.summary
            role: "titleSmall"
        }

        Label {
            Layout.fillWidth: true
            visible: root.body !== ""
            text: root.body
            role: "bodyMedium"
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: root.maxLines
            color: Theme.inkSurfaceVariant
        }
    }

    RowLayout {
        id: slot
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: -Style.spacing * 2
        Layout.rightMargin: -Style.spacing * 2
        visible: children.length > 0
        spacing: 0
    }
}
