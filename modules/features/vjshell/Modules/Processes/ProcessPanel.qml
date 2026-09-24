pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    name: "processes"
    title: "Processes"
    subtitle: ProcessService.paused ? "Paused while you point at the list" : ProcessService.results.length + " running"
    panelWidth: Style.panelWidthL
    maxPanelHeight: Style.panelMaxHeightL

    onOpenedChanged: if (opened) {
        search.clear();
        search.take();
        list.positionViewAtBeginning();
    }

    actions: IconButton {
        icon: Icons.terminal
        description: "Open btop"
        onClicked: {
            LauncherService.runInTerminal(["btop"]);
            root.close();
        }
    }

    Binding {
        target: ProcessService
        property: "paused"
        value: listHover.hovered && root.opened
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: gauges.implicitHeight + Style.panelPadding * 2
        radius: Style.radiusXl
        color: Theme.surfaceContainerHigh

        ColumnLayout {
            id: gauges

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.panelPadding
            spacing: Style.panelPadding

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacing

                Gauge {
                    Layout.fillWidth: true
                    value: SystemService.cpuUsage
                    label: "CPU"
                    sub: SystemService.cpuTemp > 0 ? Math.round(SystemService.cpuTemp) + "°C" : SystemService.cpuCount + " cores"
                }

                Gauge {
                    Layout.fillWidth: true
                    value: SystemService.memFraction
                    label: "RAM"
                    sub: SystemService.formatBytes(SystemService.memUsed) + " of " + SystemService.formatBytes(SystemService.memTotal)
                }

                Gauge {
                    Layout.fillWidth: true
                    visible: SystemService.hasGpu
                    value: SystemService.gpuUsage
                    label: "GPU"
                    sub: SystemService.gpuTemp > 0 ? Math.round(SystemService.gpuTemp) + "°C" : ""
                }

                Gauge {
                    Layout.fillWidth: true
                    visible: SystemService.hasVram
                    value: SystemService.vramFraction
                    label: "VRAM"
                    sub: SystemService.formatBytes(SystemService.vramUsed) + " of " + SystemService.formatBytes(SystemService.vramTotal)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: SystemService.disks.length > 0
                spacing: Style.spacing

                Repeater {
                    model: SystemService.disks

                    delegate: Gauge {
                        required property var modelData

                        Layout.fillWidth: true
                        value: modelData.used / modelData.total
                        label: modelData.mount
                        sub: SystemService.formatBytes(modelData.free) + " free"
                    }
                }
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Style.buttonGap

        Stat {
            icon: Icons.load
            text: "Load " + SystemService.load1.toFixed(2)
        }

        Stat {
            icon: Icons.uptime
            text: "Up " + SystemService.formatUptime(SystemService.uptime)
        }

        Stat {
            visible: SystemService.swapTotal > 0
            icon: Icons.swap
            text: "Swap " + SystemService.formatBytes(SystemService.swapUsed)
        }

        Stat {
            visible: SystemService.gpuPower > 0
            icon: Icons.gpu
            text: Math.round(SystemService.gpuPower) + " W"
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.buttonGap

        TextField {
            id: search

            icon: Icons.search
            placeholder: "Name or pid"
            onEdited: value => {
                ProcessService.query = value;
                list.positionViewAtBeginning();
            }
            onEscaped: root.close()
        }

        Button {
            icon: Icons.sort
            text: ProcessService.sortLabels[ProcessService.sortKey]
            variant: "tonal"
            onClicked: ProcessService.cycleSort()
        }

        Chip {
            text: "Kernel"
            selected: ProcessService.showKernel
            onClicked: ProcessService.showKernel = !ProcessService.showKernel
        }
    }

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Style.listItemTwoLine, Math.min(contentHeight, Style.listMax))
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: Style.listGap
        model: ProcessService.results
        Controls.ScrollBar.vertical: ListScrollBar {}

        HoverHandler {
            id: listHover
        }

        delegate: ProcessRow {}

        EmptyState {
            anchors.centerIn: parent
            width: parent.width
            visible: list.count === 0
            icon: Icons.emptySearch
            title: "No matching processes"
        }
    }

    component Stat: Rectangle {
        id: stat

        property string icon: ""
        property string text: ""

        implicitWidth: statRow.implicitWidth + Style.groupSpacing * 2
        implicitHeight: Style.buttonHeightS
        radius: height / 2
        color: Theme.surfaceContainerHigh

        RowLayout {
            id: statRow

            anchors.centerIn: parent
            spacing: Style.spacing + Style.listGap

            MaterialIcon {
                text: stat.icon
                color: Theme.inkSurfaceVariant
            }

            Label {
                text: stat.text
                role: "labelLarge"
            }
        }
    }

    component ProcessRow: ListRow {
        id: row

        required property var modelData
        required property int index

        readonly property var entry: modelData
        readonly property bool stopped: entry.state === "T" || entry.state === "t"
        readonly property bool reveal: hovered || pause.activeFocus || end.activeFocus || force.activeFocus

        width: ListView.view.width
        first: index === 0
        last: index === ListView.view.count - 1
        dense: true
        interactive: false
        headline: entry.name
        supporting: [entry.pid, entry.user, ProcessService.stateLabel(entry.state), entry.threads > 1 ? entry.threads + " threads" : ""].filter(part => part !== "" && part !== undefined).join(" · ")

        leading: Rectangle {
            implicitWidth: Style.badgeSize
            implicitHeight: Style.badgeSize
            radius: width / 2
            color: {
                if (row.entry.state === "R")
                    return Theme.success;
                if (row.entry.state === "Z")
                    return Theme.error;
                if (row.stopped)
                    return Theme.warning;
                return Theme.outlineVariant;
            }
        }

        Item {
            Layout.preferredWidth: Style.actionsWidth
            Layout.fillHeight: true

            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: Style.buttonGap
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.groupSpacing
                opacity: row.reveal ? 0 : 1

                Behavior on opacity {
                    NumberMotion {}
                }

                Label {
                    Layout.preferredWidth: Style.processColumn
                    horizontalAlignment: Text.AlignRight
                    text: row.entry.cpu.toFixed(1) + "%"
                    role: "labelLarge"
                }

                Label {
                    Layout.preferredWidth: Style.processColumn
                    horizontalAlignment: Text.AlignRight
                    text: SystemService.formatBytes(row.entry.memory)
                    role: "labelLarge"
                    font.weight: Font.Normal
                    color: Theme.inkSurfaceVariant
                }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                opacity: row.reveal ? 1 : 0

                Behavior on opacity {
                    NumberMotion {}
                }

                IconButton {
                    id: pause

                    icon: row.stopped ? Icons.resume : Icons.pause
                    compact: true
                    description: row.stopped ? "Resume" : "Pause"
                    onClicked: ProcessService.toggleStopped(row.entry)
                }

                IconButton {
                    id: end

                    icon: Icons.close
                    compact: true
                    tone: "error"
                    description: "End process"
                    onClicked: ProcessService.terminate(row.entry.pid)
                }

                IconButton {
                    id: force

                    icon: Icons.forceKill
                    compact: true
                    variant: "tonal"
                    tone: "error"
                    description: "Force quit"
                    onClicked: ProcessService.forceKill(row.entry.pid)
                }
            }
        }
    }
}
