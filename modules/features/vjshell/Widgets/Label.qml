import QtQuick
import qs.Commons

Text {
    id: root

    property string role: "bodyMedium"

    readonly property var spec: Style.typeFor(role)

    font.family: Style.fontFamily
    font.pixelSize: spec.size
    font.weight: spec.weight
    font.letterSpacing: spec.tracking
    lineHeight: spec.lineHeight
    lineHeightMode: Text.FixedHeight
    color: Theme.inkSurface
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
