import QtQuick
import QtQuick.Layouts
import qs.Commons

Text {
    id: root

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredHeight: Style.logoSize

    text: String.fromCodePoint(0xF1105)
    font.family: Style.fontFamily
    font.pixelSize: Style.logoSize
    verticalAlignment: Text.AlignVCenter
    color: hover.hovered ? Theme.active : Theme.accent

    scale: hover.hovered ? 1.12 : 1.0
    transformOrigin: Item.Center

    Behavior on color {
        ColorAnimation {
            duration: Style.durState
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.standard
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Style.durShort3
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.emphasized
        }
    }

    HoverHandler {
        id: hover
    }
}
