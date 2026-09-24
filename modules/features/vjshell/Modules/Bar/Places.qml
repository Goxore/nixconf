pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Item {
    id: root

    required property string screenName

    readonly property int projectCount: ProjectService.projectCount
    readonly property int homeSlot: ProjectService.homeSlot
    readonly property int agentDotMax: 4

    property real markerY: 0

    function tagAt(real) {
        return MangoService.tagsFor(root.screenName)[real - 1] || null;
    }

    readonly property var places: {
        const list = [];
        if (!PanelService.projectBar)
            for (let project = 1; project <= root.projectCount; project++)
                list.push({
                    project: project,
                    visible: root.homeSlot,
                    real: ProjectService.realTag(project, root.homeSlot)
                });
        for (const entry of ProjectService.entries)
            if (!entry.slot)
                list.push({
                    project: 0,
                    visible: entry.visible,
                    real: entry.real
                });
        return list;
    }

    readonly property bool anchored: places.some(place => !!root.tagAt(place.real)?.active)

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.fill: parent
        spacing: Style.spacing

        Repeater {
            model: root.places

            delegate: Column {
                id: place

                required property var modelData

                readonly property bool isProject: modelData.project > 0
                readonly property var tag: root.tagAt(modelData.real)
                readonly property bool here: !!tag?.active
                readonly property bool urgent: !!tag?.urgent
                readonly property bool occupied: ProjectService.tagBusy(modelData.real)
                readonly property bool visited: isProject && ProjectService.mru.indexOf(modelData.project) >= 0
                readonly property var agents: isProject ? ProjectService.agentsFor(modelData.project) : []
                readonly property var dots: agents.length > root.agentDotMax ? agents.slice(0, root.agentDotMax - 1) : agents
                readonly property var rest: agents.slice(dots.length)
                readonly property var lead: isProject ? ProjectService.leadFor(modelData.project) : ({
                        signal: "",
                        kind: ""
                    })
                readonly property bool shown: !isProject || here || occupied || agents.length > 0

                Layout.alignment: Qt.AlignHCenter
                spacing: Style.listGap
                visible: implicitHeight > 0.5

                Binding {
                    target: root
                    property: "markerY"
                    value: place.y + pillBox.y + pillBox.height / 2
                    when: place.here
                    restoreMode: Binding.RestoreNone
                }

                Item {
                    id: pillBox

                    x: (place.width - width) / 2
                    implicitWidth: Style.dotSize
                    implicitHeight: place.shown ? Style.dotSize : 0
                    visible: implicitHeight > 0.5

                    Behavior on implicitHeight {
                        NumberMotion {
                            duration: Style.durMorph
                            easing.bezierCurve: Style.emphasized
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: place.isProject
                        width: parent.width + Style.spacing * 1.5
                        height: parent.height + Style.spacing * 1.5
                        radius: Style.radiusS
                        color: Theme.error
                        opacity: 0

                        SequentialAnimation on opacity {
                            running: place.lead.signal === "alert"
                            loops: Animation.Infinite
                            alwaysRunToEnd: true

                            NumberMotion {
                                to: 0.45
                                duration: Style.durMedium4
                            }

                            NumberMotion {
                                to: 0
                                duration: Style.durMedium4
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: place.isProject ? Style.radiusXs : width / 2
                        color: place.urgent ? Theme.error : place.lead.signal !== "" ? Theme.agentColor(place.lead.signal, place.lead.kind) : place.here ? Theme.inkSurface : Theme.inkSurfaceVariant
                        opacity: place.here ? 1 : place.isProject ? (place.visited ? 0.55 : 0.3) : (place.occupied ? 0.45 : 0.18)
                        scale: tap.pressed ? 0.9 : hover.hovered ? 1.12 : 1

                        Behavior on color {
                            ColorMotion {}
                        }

                        Behavior on opacity {
                            NumberMotion {}
                        }

                        Behavior on scale {
                            NumberMotion {}
                        }

                        HoverHandler {
                            id: hover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            id: tap
                            onTapped: place.isProject ? ProjectService.switchTo(place.modelData.project) : ProjectService.view(place.modelData.visible)
                        }
                    }
                }

                Row {
                    x: (place.width - width) / 2
                    spacing: Style.listGap
                    visible: place.shown && place.agents.length > 0

                    Repeater {
                        model: place.dots

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

                    Rectangle {
                        visible: place.rest.length > 0
                        width: Style.agentDotSize * 2
                        height: Style.agentDotSize
                        radius: height / 2
                        color: place.rest.length > 0 ? Theme.agentColor(ProjectService.agentSignal(place.rest[0]), place.rest[0].kind) : Theme.inkSurfaceVariant
                        opacity: 0.7

                        Behavior on color {
                            ColorMotion {}
                        }
                    }
                }
            }
        }
    }

    MaterialIcon {
        x: (root.width - width) / 2
        y: root.markerY - height / 2
        text: Icons.here
        fill: 1
        weight: Style.iconWeightActive
        color: Theme.surface
        opacity: root.anchored ? 1 : 0

        Behavior on y {
            NumberMotion {
                duration: Style.durMorph
                easing.bezierCurve: Style.emphasized
            }
        }

        Behavior on opacity {
            NumberMotion {}
        }
    }
}
