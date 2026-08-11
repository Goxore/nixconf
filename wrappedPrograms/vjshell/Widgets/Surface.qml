import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
    id: root

    property int level: 2
    property int radius: Style.radiusM
    property color color: Theme.surface
    property color borderColor: Theme.surfaceHigh
    property int borderWidth: Style.borderWidth

    default property alias content: box.data

    RectangularShadow {
        anchors.fill: box
        radius: box.radius
        blur: Style.elevationBlur[root.level]
        spread: Style.elevationSpread[root.level]
        offset: Qt.vector2d(0, Style.elevationY[root.level])
        color: Theme.shadowFor(root.level)
        visible: root.level > 0
    }

    Rectangle {
        id: box
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.width: root.borderWidth
        border.color: root.borderColor
    }
}
