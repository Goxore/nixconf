import QtQuick
import qs.Commons

Text {
    id: root

    property real fill: 0
    property int weight: Style.iconWeight

    font.family: Style.iconFontFamily
    font.pixelSize: Style.iconSize
    font.hintingPreference: Font.PreferNoHinting
    font.variableAxes: ({
            FILL: root.fill,
            wght: root.weight,
            GRAD: 0,
            opsz: 24
        })

    renderType: Text.NativeRendering
    color: Theme.inkSurface
    elide: Text.ElideNone
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on fill {
        NumberMotion {
            duration: Style.durShort4
        }
    }

    Behavior on color {
        ColorMotion {}
    }
}
