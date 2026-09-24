import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
    id: root

    property color color: Theme.primary
    property real strokeWidth: 2

    readonly property real radius: (Math.min(width, height) - strokeWidth) / 2

    implicitWidth: Style.iconSize
    implicitHeight: Style.iconSize

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.strokeWidth
            strokeColor: Theme.withAlpha(root.color, 0.2)
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                sweepAngle: 360
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.strokeWidth
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 100
            }
        }

        RotationAnimator on rotation {
            running: root.visible
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: Style.durLong
        }
    }
}
