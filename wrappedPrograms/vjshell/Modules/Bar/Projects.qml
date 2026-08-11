import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services

ColumnLayout {
    id: root

    readonly property int projectCount: ProjectService.projectCount

    Layout.fillWidth: true
    spacing: Style.spacing

    Repeater {
        model: root.projectCount

        delegate: Rectangle {
            id: slot

            required property int index
            readonly property int projectId: index + 1
            readonly property bool active: ProjectService.active === projectId
            readonly property bool visited: ProjectService.mru.indexOf(projectId) >= 0

            Layout.alignment: Qt.AlignHCenter

            implicitWidth: Style.dotSize
            implicitHeight: active ? Style.dotSize + 4 : Style.dotSize - 6
            radius: Style.radiusXs

            color: active ? Theme.active : Theme.occupied
            opacity: active ? 1.0 : visited ? 0.55 : 0.25

            scale: tap.pressed ? 0.9 : hover.hovered ? 1.12 : 1.0
            transformOrigin: Item.Center

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Style.durMorph
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Style.emphasized
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Style.durState
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Style.standard
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.durState
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Style.durState
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Style.standard
                }
            }

            HoverHandler {
                id: hover
            }

            TapHandler {
                id: tap
                onTapped: ProjectService.switchTo(slot.projectId)
            }
        }
    }
}
