import QtQuick
import qs.Commons

Text {
    id: root

    property real fill: 0

    font.family: Style.iconFontFamily
    font.pixelSize: Style.iconSize

    font.variableAxes: ({
            FILL: root.fill,
            wght: 400,
            GRAD: 0,
            opsz: 24
        })

    color: Theme.text

    elide: Text.ElideNone
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation {
            duration: Style.animFast
        }
    }
}
