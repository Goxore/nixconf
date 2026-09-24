import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Pressable {
    id: root

    required property int project
    required property int carrying
    required property int landing

    property real homeX: 0
    property real grabbedAt: 0

    readonly property bool dragging: drag.active
    readonly property real carriedCentre: x + width / 2
    readonly property string name: ProjectService.named(project)
    readonly property bool here: ProjectService.active === project
    readonly property var lead: ProjectService.leadFor(project)
    readonly property bool lifted: carrying === project
    readonly property bool targeted: carrying > 0 && landing === project && !lifted

    signal openEditor

    implicitWidth: body.implicitWidth + Style.groupSpacing * 2
    width: implicitWidth
    x: dragging ? grabbedAt + drag.activeTranslation.x : homeX
    z: dragging ? 1 : 0
    opacity: lifted ? 0.85 : 1
    scale: lifted ? 1.06 : 1

    description: name || "Project " + project
    selected: here
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    layerWidth: width
    layerHeight: height - Style.barInset * 2
    cornerRadius: Style.radiusS

    onDraggingChanged: if (dragging)
        grabbedAt = homeX
    onClicked: ProjectService.switchTo(project)
    onRightClicked: openEditor()

    Behavior on x {
        enabled: !root.dragging

        NumberMotion {
            duration: Style.durMorph
            easing.bezierCurve: Style.emphasized
        }
    }

    Behavior on opacity {
        NumberMotion {}
    }

    Behavior on scale {
        NumberMotion {}
    }

    DragHandler {
        id: drag
        target: null
        yAxis.enabled: false
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Style.barInset
        anchors.bottomMargin: Style.barInset
        radius: Style.radiusS
        color: root.here ? Theme.secondaryContainer : root.targeted ? Theme.withAlpha(Theme.primary, 0.25) : "transparent"

        Behavior on color {
            ColorMotion {}
        }

        PulseLayer {
            radius: parent.radius
            color: Theme.agentColor(root.lead.signal, root.lead.kind)
            running: root.lead.signal === "alert" || root.lead.signal === "done"
        }
    }

    RowLayout {
        id: body

        anchors.centerIn: parent
        spacing: Style.spacing + Style.listGap

        MaterialIcon {
            text: ProjectService.iconOf(root.project)
            fill: root.here ? 1 : 0
            color: root.here ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant
        }

        Label {
            Layout.maximumWidth: Style.projectNameMax
            visible: root.name !== ""
            text: root.name
            role: "labelMedium"
            font.weight: root.here ? Font.Bold : Font.Medium
            color: root.here ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant
        }

        AgentDots {
            Layout.alignment: Qt.AlignVCenter
            agents: ProjectService.agentsFor(root.project)
        }
    }
}
