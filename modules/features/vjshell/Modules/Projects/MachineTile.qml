import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Item {
    id: root

    required property string machine

    readonly property var agents: ProjectService.agentsOn(machine)
    readonly property string lead: ProjectService.leadOn(machine)

    implicitWidth: body.implicitWidth + Style.groupSpacing * 2

    PulseLayer {
        anchors.topMargin: Style.barInset
        anchors.bottomMargin: Style.barInset
        radius: Style.radiusS
        color: Theme.agentColor(root.lead, root.agents[0]?.kind ?? "")
        running: root.lead === "alert" || root.lead === "done"
    }

    RowLayout {
        id: body

        anchors.centerIn: parent
        spacing: Style.spacing + Style.listGap

        MaterialIcon {
            text: Icons.machine
            color: Theme.inkSurfaceVariant
        }

        Label {
            text: root.machine
            role: "labelMedium"
            color: Theme.inkSurfaceVariant
        }

        AgentDots {
            Layout.alignment: Qt.AlignVCenter
            agents: root.agents
            max: root.agents.length
        }
    }
}
