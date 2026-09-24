pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool shown: PanelService.projectBar

    readonly property var open: {
        const list = [];
        for (let project = 1; project <= ProjectService.projectCount; project++)
            if (!ProjectService.blank(project))
                list.push(project);
        return list;
    }

    property int carrying: 0
    property int landing: 0

    screen: modelData
    visible: root.shown

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Style.projectBarHeight
    exclusiveZone: root.shown ? Style.projectBarHeight : 0
    color: Theme.surface

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "vjshell-projects"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property var shuffled: {
        const order = root.open.slice();
        const from = order.indexOf(root.carrying);
        const to = order.indexOf(root.landing);
        if (from >= 0 && to >= 0 && from !== to) {
            order.splice(from, 1);
            order.splice(to, 0, root.carrying);
        }
        return order;
    }

    property var widths: ({})

    function widthOf(project) {
        return widths[project] ?? 0;
    }

    function measure(project, width) {
        if (widths[project] === width)
            return;
        const next = Object.assign({}, widths);
        next[project] = width;
        widths = next;
    }

    function restingX(project) {
        let x = 0;
        for (const held of root.shuffled) {
            if (held === project)
                break;
            x += root.widthOf(held) + Style.spacing;
        }
        return x;
    }

    function aim(centre) {
        let nearest = 0;
        let closest = Infinity;
        for (const held of root.open) {
            const gap = Math.abs(centre - (root.restingX(held) + root.widthOf(held) / 2));
            if (gap < closest) {
                closest = gap;
                nearest = held;
            }
        }
        root.landing = nearest;
    }

    function drop() {
        if (root.carrying > 0 && root.landing > 0)
            ProjectService.reorder(root.carrying, root.landing);
        root.carrying = 0;
        root.landing = 0;
    }

    Divider {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.spacing
        anchors.rightMargin: Style.barPadding
        anchors.bottomMargin: Style.dividerWidth
        spacing: Style.spacing

        Flickable {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.maximumWidth: contentWidth
            contentWidth: tiles.width
            clip: true
            interactive: root.carrying === 0
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            WheelHandler {
                onWheel: event => {
                    parent.contentX = Math.max(0, Math.min(parent.contentWidth - parent.width, parent.contentX - (event.angleDelta.x || event.angleDelta.y) / 2));
                    event.accepted = true;
                }
            }

            Item {
                id: tiles
                height: parent.height
                width: implicitWidth
                implicitWidth: {
                    let span = 0;
                    for (const held of root.open)
                        span += root.widthOf(held) + Style.spacing;
                    return Math.max(0, span - Style.spacing);
                }

                Repeater {
                    id: strip

                    model: root.open

                    delegate: ProjectTile {
                        required property int modelData

                        anchors.top: tiles.top
                        anchors.bottom: tiles.bottom

                        project: modelData
                        onWidthChanged: root.measure(project, width)
                        Component.onCompleted: root.measure(project, width)
                        carrying: root.carrying
                        landing: root.landing
                        homeX: root.restingX(modelData)

                        onDraggingChanged: {
                            if (dragging)
                                root.carrying = project;
                            else if (root.carrying === project)
                                root.drop();
                        }
                        onCarriedCentreChanged: if (dragging)
                            root.aim(carriedCentre)
                        onOpenEditor: PanelService.edit(project)
                    }
                }
            }
        }

        Pressable {
            id: add

            Layout.fillHeight: true
            implicitWidth: Style.projectBarHeight
            description: "New project"
            layerHeight: height - Style.barInset * 2
            cornerRadius: Style.radiusS
            onClicked: PanelService.pick(ProjectService.firstFree())

            MaterialIcon {
                anchors.centerIn: parent
                text: Icons.add
                color: add.hovered ? Theme.inkSurface : Theme.inkSurfaceVariant
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Row {
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Style.spacing
            visible: machines.count > 0

            Repeater {
                id: machines

                model: ProjectService.machines.filter(name => ProjectService.agentsOn(name).length > 0)

                delegate: MachineTile {
                    required property string modelData

                    height: parent.height
                    machine: modelData
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            visible: ProjectService.limits !== null
            spacing: Style.spacing

            Label {
                text: ProjectService.limits ? "5h " + Math.round(ProjectService.limits.fiveHour) + "%" : ""
                role: "labelMedium"
                font.weight: Font.Bold
                color: ProjectService.limits ? Theme.loadColor(ProjectService.limits.fiveHour / 100) : Theme.inkSurface
            }

            Label {
                text: {
                    if (!ProjectService.limits)
                        return "";
                    const parts = [];
                    if (ProjectService.limits.sevenDay !== null)
                        parts.push("7d " + Math.round(ProjectService.limits.sevenDay) + "%");
                    if (ProjectService.limits.resetsAt)
                        parts.push("resets " + ProjectService.limits.resetsAt);
                    return parts.join(" · ");
                }
                role: "labelMedium"
                color: Theme.inkSurfaceVariant
            }
        }
    }
}
