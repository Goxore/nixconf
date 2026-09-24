import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string supporting: ""

    Layout.fillWidth: true
    Layout.topMargin: Style.groupSpacing * 2
    Layout.bottomMargin: Style.groupSpacing * 2
    spacing: Style.buttonGap

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Style.spacing
        implicitWidth: Style.emptyIconBox
        implicitHeight: Style.emptyIconBox
        radius: width / 2
        color: Theme.surfaceContainerHigh

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            font.pixelSize: Style.iconSizeHero
            color: Theme.inkSurfaceVariant
        }
    }

    Label {
        Layout.fillWidth: true
        text: root.title
        role: "titleSmall"
        horizontalAlignment: Text.AlignHCenter
    }

    Label {
        Layout.fillWidth: true
        visible: root.supporting !== ""
        text: root.supporting
        role: "bodyMedium"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        color: Theme.inkSurfaceVariant
    }
}
