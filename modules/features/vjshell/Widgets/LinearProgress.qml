import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
    id: root

    property real value: 0
    property bool indeterminate: false
    property color color: Theme.primary
    property color trackColor: Theme.surfaceContainerHighest

    readonly property real clamped: Math.max(0, Math.min(1, value))

    Layout.fillWidth: true
    implicitHeight: Style.progressHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
    }

    Rectangle {
        visible: !root.indeterminate
        width: parent.width * root.clamped
        height: parent.height
        radius: height / 2
        color: root.color

        Behavior on width {
            NumberMotion {
                duration: Style.durShort3
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.indeterminate
        clip: true

        Rectangle {
            id: sweep
            width: parent.width * 0.35
            height: parent.height
            radius: height / 2
            color: root.color

            NumberAnimation on x {
                running: root.indeterminate && root.visible
                loops: Animation.Infinite
                from: -sweep.width
                to: root.width
                duration: Style.durLong
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.emphasized
            }
        }
    }
}
