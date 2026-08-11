import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
    id: root

    required property string screenName

    readonly property string layout: MangoService.kbLayoutFor(screenName)

    readonly property string short: layout.substring(0, 2).toUpperCase()

    spacing: 0
    visible: layout !== ""

    MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
        text: Icons.keyboard
        color: Theme.text
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: root.short
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        font.weight: Font.Bold
        color: Theme.textDim
    }
}
