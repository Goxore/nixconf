import QtQuick
import qs.Commons
import qs.Services

Row {
    id: root

    property var agents: []
    property int max: 4

    spacing: Style.listGap
    visible: agents.length > 0

    Repeater {
        model: root.agents.slice(0, root.max)

        delegate: Rectangle {
            required property var modelData

            width: Style.agentDotSize
            height: Style.agentDotSize
            radius: width / 2
            color: Theme.agentColor(ProjectService.agentSignal(modelData), modelData.kind)

            Behavior on color {
                ColorMotion {}
            }
        }
    }
}
