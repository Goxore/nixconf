import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
    id: root

    property real value: 0
    property string label: ""
    property string sub: ""

    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property color fillColor: clamped >= 0.90 ? Theme.urgent : clamped >= 0.75 ? Theme.warning : Theme.accent

    property real animated: clamped

    implicitWidth: Style.gaugeSize
    implicitHeight: ring.height + Style.spacing + sublabel.implicitHeight

    Behavior on animated {
        NumberAnimation {
            duration: Style.durMedium1
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.standard
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
                strokeColor: Qt.alpha(root.fillColor, 0.20)
                fillColor: "transparent"

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: (ring.width - Style.gaugeStroke) / 2
                    radiusY: (ring.height - Style.gaugeStroke) / 2
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
                    radiusX: (ring.width - Style.gaugeStroke) / 2
                    radiusY: (ring.height - Style.gaugeStroke) / 2
                    startAngle: -90
                    sweepAngle: 360 * root.animated
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(root.clamped * 100) + "%"
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.textBright
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.label
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                color: Theme.textDim
            }
        }
    }

    Text {
        id: sublabel

        anchors.top: ring.bottom
        anchors.topMargin: Style.spacing
        anchors.horizontalCenter: parent.horizontalCenter

        text: root.sub
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        color: Theme.textDim
    }
}
