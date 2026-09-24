import QtQuick
import qs.Commons

Rectangle {
    id: root

    property bool shown: false

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.badgeInset
    width: Style.badgeSize
    height: Style.badgeSize
    radius: width / 2
    color: Theme.error
    scale: shown ? 1 : 0
    opacity: shown ? 1 : 0

    Behavior on scale {
        NumberMotion {
            duration: Style.durShort4
            easing.bezierCurve: Style.emphasizedDecelerate
        }
    }

    Behavior on opacity {
        NumberMotion {
            duration: Style.durShort4
        }
    }

    Behavior on color {
        ColorMotion {}
    }
}
