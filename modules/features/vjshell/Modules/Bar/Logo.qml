import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Text {
    id: root

    Layout.alignment: Qt.AlignHCenter
    Layout.preferredHeight: Style.logoSize

    text: String.fromCodePoint(0xF1105)
    font.family: Style.fontFamily
    font.pixelSize: Style.logoSize
    verticalAlignment: Text.AlignVCenter
    color: RecorderService.recording ? Theme.error : hover.hovered ? Theme.success : Theme.primary
    scale: hover.hovered ? 1.12 : 1

    Behavior on color {
        ColorMotion {}
    }

    Behavior on scale {
        NumberMotion {
            duration: Style.durShort3
            easing.bezierCurve: Style.emphasized
        }
    }

    HoverHandler {
        id: hover
    }
}
