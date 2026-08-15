import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    panelName: "processes"
    title: "Processes"
    icon: Icons.monitor

    panelWidth: Style.panelWidthL
    maxPanelHeight: Style.panelMaxHeightL

    readonly property int rowStride: Style.rowHeightM + 2

    onOpenedChanged: {
        SystemService.active = opened;
        ProcessService.active = opened;
        if (opened) {
            search.clear();
            search.forceActiveFocus();
            list.positionViewAtBeginning();
        }
    }

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
            sub: SystemService.formatBytes(SystemService.memUsed) + "/" + SystemService.formatBytes(SystemService.memTotal)
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
            sub: SystemService.formatBytes(SystemService.vramUsed) + "/" + SystemService.formatBytes(SystemService.vramTotal)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        Chip {
            Layout.fillWidth: true
            icon: Icons.load
            label: SystemService.load1.toFixed(2)
        }

        Chip {
            Layout.fillWidth: true
            icon: Icons.uptime
            label: SystemService.formatUptime(SystemService.uptime)
        }

        Chip {
            Layout.fillWidth: true
            visible: SystemService.swapTotal > 0
            icon: Icons.swap
            label: SystemService.formatBytes(SystemService.swapUsed) + "/" + SystemService.formatBytes(SystemService.swapTotal)
        }

        Chip {
            Layout.fillWidth: true
            visible: SystemService.gpuPower > 0
            icon: Icons.gpu
            label: Math.round(SystemService.gpuPower) + "W"
        }

        Chip {
            Layout.fillWidth: true
            icon: ProcessService.paused ? Icons.pause : Icons.processes
            label: ProcessService.paused ? "held" : ProcessService.results.length + ""
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.dividerWidth
        color: Theme.surfaceHigh
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        MaterialIcon {
            text: Icons.search
            color: Theme.textDim
        }

        TextInput {
            id: search

            Layout.fillWidth: true
            Layout.preferredHeight: Style.buttonHeight
            verticalAlignment: TextInput.AlignVCenter

            clip: true
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.surface

            onTextChanged: {
                ProcessService.query = text;
                list.positionViewAtBeginning();
            }

            Keys.onEscapePressed: root.close()

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: search.text === ""
                text: "Filter by name or pid"
                font: search.font
                color: Theme.textDim
            }
        }

        PanelButton {
            icon: Icons.sort
            text: ProcessService.sortLabels[ProcessService.sortKey]
            onClicked: ProcessService.cycleSort()
        }

        PanelButton {
            text: "Kernel"
            accent: ProcessService.showKernel
            onClicked: ProcessService.showKernel = !ProcessService.showKernel
        }
    }

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.max(root.rowStride, Math.min(contentHeight, Math.floor(Style.listMax / root.rowStride) * root.rowStride - 2))

        clip: true
        spacing: 2
        model: ProcessService.results

        HoverHandler {
            onHoveredChanged: ProcessService.paused = hovered
        }

        delegate: ProcessRow {
            required property var modelData
            width: list.width
            entry: modelData
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: list.count === 0
            spacing: Style.spacing

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: Icons.emptySearch
                font.pixelSize: Style.iconSizeXl
                color: Theme.textDim
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No matching processes"
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                color: Theme.textDim
            }
        }
    }

    PanelButton {
        Layout.fillWidth: true
        icon: Icons.terminal
        text: "Full monitor (btop)"
        onClicked: {
            Quickshell.execDetached([Quickshell.env("VJSHELL_TERMINAL") || "kitty", "-e", "btop"]);
            root.close();
        }
    }

    component Chip: RowLayout {
        id: chip

        property string icon: ""
        property string label: ""

        spacing: 2

        MaterialIcon {
            text: chip.icon
            font.pixelSize: Style.fontSize
            color: Theme.textDim
        }

        Text {
            Layout.fillWidth: true
            text: chip.label
            elide: Text.ElideRight
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: Theme.textDim
        }
    }

    component ProcessRow: Rectangle {
        id: row

        required property var entry

        readonly property bool stopped: entry.state === "T" || entry.state === "t"

        implicitHeight: Style.rowHeightM
        radius: Style.radiusS
        color: "transparent"

        StateLayer {
            cornerRadius: row.radius
            hovered: hover.hovered
        }

        HoverHandler {
            id: hover
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.spacing
            anchors.rightMargin: Style.spacing
            spacing: Style.spacing

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Style.badgeSize
                implicitHeight: Style.badgeSize
                radius: Style.radiusFull
                color: {
                    if (row.entry.state === "R")
                        return Theme.active;
                    if (row.entry.state === "Z")
                        return Theme.urgent;
                    if (row.stopped)
                        return Theme.warning;
                    return Theme.outline;
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: row.entry.name
                    elide: Text.ElideRight
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        const bits = [row.entry.pid];
                        if (row.entry.user !== "")
                            bits.push(row.entry.user);
                        bits.push(ProcessService.stateLabel(row.entry.state));
                        if (row.entry.threads > 1)
                            bits.push(row.entry.threads + " thr");
                        return bits.join("  ");
                    }
                    elide: Text.ElideRight
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    color: Theme.textDim
                }
            }

            Item {
                Layout.preferredWidth: Style.actionsWidth
                Layout.fillHeight: true

                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing

                    opacity: hover.hovered ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.durState
                        }
                    }

                    Text {
                        Layout.preferredWidth: 60
                        horizontalAlignment: Text.AlignRight
                        text: row.entry.cpu.toFixed(1) + "%"
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        color: Theme.text
                    }

                    Text {
                        Layout.preferredWidth: 60
                        horizontalAlignment: Text.AlignRight
                        text: SystemService.formatBytes(row.entry.memory)
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        color: Theme.textDim
                    }
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing

                    opacity: hover.hovered ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.durState
                        }
                    }

                    PanelButton {
                        icon: row.stopped ? Icons.resume : Icons.pause
                        accent: row.stopped
                        onClicked: ProcessService.toggleStopped(row.entry)
                    }

                    PanelButton {
                        icon: Icons.close
                        text: "Kill"
                        onClicked: ProcessService.terminate(row.entry.pid)
                    }

                    PanelButton {
                        icon: Icons.forceKill
                        text: "Force"
                        onClicked: ProcessService.forceKill(row.entry.pid)
                    }
                }
            }
        }
    }
}
