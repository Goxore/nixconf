import QtQuick
import qs.Commons

Text {
    id: root

    property real fill: 0
    property int weight: Style.iconWeight

    font.family: Style.iconFontFamily
    font.pixelSize: Style.iconSize

    font.variableAxes: ({
            FILL: root.fill,
            wght: root.weight,
            GRAD: 0,
            opsz: 24
        })

    Behavior on fill {
        NumberAnimation {
            duration: Style.durShort4
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.standard
        }
    }

    color: Theme.text

    elide: Text.ElideNone
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation {
            duration: Style.durState
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.standard
        }
    }
}
