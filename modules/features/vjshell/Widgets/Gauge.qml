import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
    id: root

    property real value: 0
    property string label: ""
    property string sub: ""

    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property color fillColor: Theme.loadColor(clamped)
    readonly property real arcRadius: (Style.gaugeSize - Style.gaugeStroke) / 2

    property real animated: clamped

    implicitWidth: Style.gaugeSize
    implicitHeight: ring.height + Style.spacing + sublabel.implicitHeight

    Behavior on animated {
        NumberMotion {
            duration: Style.durMedium1
        }
    }

    Item {
        id: ring

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.gaugeSize
        height: Style.gaugeSize

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: Style.gaugeStroke
                strokeColor: Theme.surfaceContainerHighest
                fillColor: "transparent"

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: root.arcRadius
                    radiusY: root.arcRadius
                    startAngle: -90
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeWidth: Style.gaugeStroke
                strokeColor: root.fillColor
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: root.arcRadius
                    radiusY: root.arcRadius
                    startAngle: -90
                    sweepAngle: 360 * root.animated
                }
            }
        }

        Column {
            anchors.centerIn: parent

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(root.clamped * 100) + "%"
                role: "titleSmall"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.label
                role: "labelSmall"
                color: Theme.inkSurfaceVariant
            }
        }
    }

    Label {
        id: sublabel

        anchors.top: ring.bottom
        anchors.topMargin: Style.spacing
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.sub
        role: "labelSmall"
        color: Theme.inkSurfaceVariant
    }
}
