import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
    property bool vertical: false

    Layout.fillWidth: !vertical
    Layout.fillHeight: vertical
    implicitWidth: vertical ? Style.dividerWidth : 0
    implicitHeight: vertical ? 0 : Style.dividerWidth
    color: Theme.outlineVariant
}
