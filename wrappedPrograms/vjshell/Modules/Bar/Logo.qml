import QtQuick
import QtQuick.Layouts
import qs.Commons

Text {
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredHeight: Style.logoSize

    text: String.fromCodePoint(0xF1105)
    font.family: Style.fontFamily
    font.pixelSize: Style.logoSize
    verticalAlignment: Text.AlignVCenter
    color: Theme.accent
}
