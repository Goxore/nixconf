import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    id: root

    readonly property int waiting: ProjectService.alertCount + ProjectService.remoteAlertCount
    readonly property int finished: ProjectService.doneCount + ProjectService.remoteDoneCount
    readonly property int busy: ProjectService.workingCount + ProjectService.remoteWorkingCount
    readonly property bool active: busy > 0 || waiting > 0 || finished > 0

    function tally(alert, done, working, idle) {
        return [[alert, "need you"], [done, "finished"], [working, "working"], [idle, "idle"]].filter(([count]) => count > 0).map(([count, word]) => count + " " + word).join(", ");
    }

    visible: ProjectService.agents.length > 0 || ProjectService.elsewhere.length > 0

    icon: active ? Icons.agents : Icons.agentsIdle
    iconColor: waiting > 0 ? Theme.error : finished > 0 ? Theme.success : busy > 0 ? Theme.warning : Theme.inkSurfaceVariant
    iconFill: waiting > 0 || finished > 0 ? 1 : 0
    tooltip: {
        const here = tally(ProjectService.alertCount, ProjectService.doneCount, ProjectService.workingCount, ProjectService.idleCount);
        const lines = here !== "" ? [here] : [];
        for (const machine of ProjectService.machines) {
            const stack = ProjectService.agentsOn(machine);
            const count = signal => stack.filter(agent => ProjectService.agentSignal(agent) === signal).length;
            const there = tally(count("alert"), count("done"), count("working"), count("idle"));
            if (there !== "")
                lines.push(machine + " " + there);
        }
        return lines.join("\n");
    }

    onClicked: PanelService.projectBar = !PanelService.projectBar

    Badge {
        shown: root.waiting > 0 || root.finished > 0
        color: root.waiting > 0 ? Theme.error : Theme.success
    }
}
