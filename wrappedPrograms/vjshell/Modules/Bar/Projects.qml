import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services

ColumnLayout {
    id: root

    readonly property int projectCount: ProjectService.projectCount
    readonly property var visibleSlots: ProjectService.visibleSlots

    Layout.fillWidth: true
    spacing: Style.spacing

    function blockStart(visible) {
        let start = 1;
        for (let v = 1; v < visible; v++)
            start += root.visibleSlots.includes(v) ? root.projectCount : 1;
        return start;
    }

    function realTag(project, visible) {
        const start = root.blockStart(visible);
        return root.visibleSlots.includes(visible) ? start + project - 1 : start;
    }

    function projectOccupied(project) {
        for (const visible of root.visibleSlots) {
            const real = root.realTag(project, visible);
            for (const name in MangoService.outputs) {
                const tag = (MangoService.outputs[name].tags || [])[real - 1];
                if (tag && tag.clients > 0)
                    return true;
            }
        }
        return false;
    }

    Repeater {
        model: root.projectCount

        delegate: Rectangle {
            id: slot

            required property int index
            readonly property int projectId: index + 1
            readonly property bool active: ProjectService.active === projectId
            readonly property bool visited: ProjectService.mru.indexOf(projectId) >= 0
            readonly property bool occupied: root.projectOccupied(projectId)
            readonly property bool shown: active || occupied

            Layout.alignment: Qt.AlignHCenter

            implicitWidth: Style.dotSize
            implicitHeight: shown ? (active ? Style.dotSize + 4 : Style.dotSize - 6) : 0
            visible: implicitHeight > 0.5
            radius: Style.radiusXs

            color: Theme.accent
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
