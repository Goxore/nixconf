import QtQuick
import qs.Commons

QtObject {
    id: root

    property bool open: false
    property real progress: 0

    readonly property bool active: open || progress > 0
    readonly property bool closing: !open && progress > 0

    property int enterDuration: Style.durEnter
    property int exitDuration: Style.durExit
    property var enterEasing: Style.emphasizedDecelerate
    property var exitEasing: Style.emphasizedAccelerate

    onOpenChanged: progress = open ? 1 : 0

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? root.enterDuration : root.exitDuration
            easing.type: Easing.Bezier
            easing.bezierCurve: root.open ? root.enterEasing : root.exitEasing
        }
    }
}
