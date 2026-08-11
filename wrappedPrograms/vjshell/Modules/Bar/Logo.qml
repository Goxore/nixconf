import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Widgets

Item {
    Layout.alignment: Qt.AlignHCenter

    implicitWidth: Style.logoSize
    implicitHeight: Style.logoSize

    IconImage {
        id: logo
        anchors.fill: parent
        source: Quickshell.iconPath("nix-snowflake", true)
        visible: status === Image.Ready
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: !logo.visible
        text: Icons.application
        font.pixelSize: Style.logoSize
        color: Theme.accent
    }
}
