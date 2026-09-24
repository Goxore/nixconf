import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
    readonly property string layout: MangoService.keyboardLayout

    visible: layout !== ""
    spacing: 0

    MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
        text: Icons.keyboard
        color: Theme.inkSurfaceVariant
    }

    Label {
        Layout.alignment: Qt.AlignHCenter
        text: parent.layout.substring(0, 2).toUpperCase()
        role: "labelSmall"
        font.weight: Font.Bold
        color: Theme.inkSurfaceVariant
    }
}
