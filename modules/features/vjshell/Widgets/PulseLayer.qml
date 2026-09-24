import QtQuick
import qs.Commons

Rectangle {
    id: root

    property bool running: false
    property real peak: 0.3

    anchors.fill: parent
    opacity: 0

    SequentialAnimation on opacity {
        running: root.running
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberMotion {
            to: root.peak
            duration: Style.durMedium4
        }

        NumberMotion {
            to: 0
            duration: Style.durMedium4
        }
    }
}
