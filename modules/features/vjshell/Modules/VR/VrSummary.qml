import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
    id: root

    readonly property var headset: VrService.headset
    readonly property bool hasBattery: headset?.battery !== null && headset?.battery !== undefined
    readonly property int battery: headset?.battery ?? 0
    readonly property bool charging: headset?.charging ?? false
    readonly property bool lowBattery: hasBattery && battery <= 15 && !charging
    readonly property bool sessionActive: VrService.state.session?.active || VrService.connected
    readonly property bool idle: VrService.online && !VrService.busy

    readonly property string status: VrService.text(VrService.connected ? "connected" : VrService.manageable ? "ready" : "waiting_headset")
    readonly property string link: VrService.manageable ? VrService.text(headset.transport) : ""

    readonly property string noticeTone: VrService.problem || !VrService.online ? "error" : VrService.busy ? "primary" : "surface"

    Layout.fillWidth: true
    spacing: Style.groupSpacing

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.spacing
        Layout.leftMargin: Style.spacing
        Layout.rightMargin: Style.spacing
        spacing: Style.panelPadding

        Rectangle {
            implicitWidth: Style.avatarSize
            implicitHeight: Style.avatarSize
            radius: width / 2
            color: VrService.connected ? Theme.successContainer : VrService.manageable ? Theme.primaryContainer : Theme.surfaceContainerHighest

            Behavior on color {
                ColorMotion {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: Icons.vr
                font.pixelSize: Style.iconSizeHero
                fill: VrService.connected ? 1 : 0
                color: VrService.connected ? Theme.inkSuccessContainer : VrService.manageable ? Theme.inkPrimaryContainer : Theme.inkSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.headset?.model || VrService.text("quest")
                role: "titleLarge"
            }

            Label {
                Layout.fillWidth: true
                text: [root.status, root.link].filter(part => part !== "").join(" · ")
                role: "bodyMedium"
                color: VrService.connected ? Theme.success : Theme.inkSurfaceVariant
            }

            Label {
                Layout.fillWidth: true
                visible: !VrService.manageable && !!root.headset?.last_seen
                text: VrService.text("last_seen_value", {
                    time: VrService.seen(root.headset?.last_seen)
                })
                role: "bodySmall"
                color: Theme.outline
            }
        }

        Rectangle {
            visible: root.hasBattery
            Layout.alignment: Qt.AlignTop
            implicitWidth: battery.implicitWidth + Style.groupSpacing * 2
            implicitHeight: Style.buttonHeightS
            radius: height / 2
            color: root.lowBattery ? Theme.errorContainer : Theme.surfaceContainerHighest

            RowLayout {
                id: battery

                anchors.centerIn: parent
                spacing: Style.spacing

                MaterialIcon {
                    text: root.charging ? Icons.batteryCharging : root.lowBattery ? Icons.batteryLow : Icons.battery
                    fill: 1
                    color: root.lowBattery ? Theme.inkErrorContainer : root.charging ? Theme.success : Theme.inkSurfaceVariant
                }

                Label {
                    text: VrService.text("percent", {
                        percent: root.battery
                    })
                    role: "labelLarge"
                    color: root.lowBattery ? Theme.inkErrorContainer : Theme.inkSurface
                }
            }
        }
    }

    Notice {
        visible: VrService.confirmation !== null
        tone: "warning"
        icon: Icons.warning
        text: VrService.text(VrService.confirmation?.key || "")

        Button {
            text: VrService.text("cancel")
            variant: "text"
            tone: "warning"
            onClicked: VrService.confirmation = null
        }

        Button {
            text: VrService.text("confirm")
            variant: "filled"
            tone: "warning"
            onClicked: VrService.accept()
        }
    }

    Notice {
        visible: !VrService.online || !!VrService.problem || VrService.busy || !VrService.manageable
        busy: VrService.busy
        tone: root.noticeTone
        icon: root.noticeTone === "error" ? Icons.error : root.noticeTone === "primary" ? Icons.hourglassTop : Icons.info
        text: {
            if (!VrService.online)
                return VrService.text("error_service_unavailable");
            if (VrService.problem)
                return VrService.errorText(VrService.problem);
            if (VrService.busy)
                return VrService.text("stage_" + VrService.state.operation.stage);
            return VrService.text(root.headset?.status === "unauthorized" ? "authorize" : "wake");
        }

        Button {
            visible: VrService.busy && (VrService.state.operation?.cancellable ?? false)
            text: VrService.text("cancel")
            variant: "text"
            tone: "primary"
            onClicked: VrService.send({
                action: "cancel"
            })
        }

        Button {
            visible: !VrService.busy && !!VrService.problem
            text: VrService.text("refresh")
            icon: Icons.reset
            variant: "tonal"
            tone: "error"
            onClicked: VrService.send({
                action: "refresh"
            })
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.buttonGap

        Button {
            Layout.fillWidth: true
            text: VrService.text(root.sessionActive ? "end_session" : "start_vr")
            icon: root.sessionActive ? Icons.stop : Icons.play
            variant: root.sessionActive ? "tonal" : "filled"
            tone: root.sessionActive ? "error" : "primary"
            enabled: root.idle
            onClicked: VrService.send({
                action: root.sessionActive ? "stop" : "start"
            })
        }

        Button {
            text: VrService.text("preview")
            icon: Icons.preview
            variant: "outlined"
            enabled: VrService.manageable && !VrService.busy
            onClicked: VrService.send({
                action: "preview"
            })
        }
    }

    ListGroup {
        ListRow {
            Layout.fillWidth: true
            icon: Icons.autoconnect
            headline: VrService.text("autoconnect")
            supporting: VrService.state.preferences?.auto_connect ? VrService.text("autoconnect_help") : VrService.state.worn === true ? VrService.text("on_head") : VrService.state.worn === false ? VrService.text("off_head") : ""
            supportingLines: 2
            interactive: root.idle
            onClicked: VrService.preference("auto_connect", !VrService.state.preferences?.auto_connect)

            Switch {
                checked: VrService.state.preferences?.auto_connect ?? false
                enabled: root.idle
                description: VrService.text("autoconnect")
                onToggled: value => VrService.preference("auto_connect", value)
            }
        }
    }

    Tabs {
        Layout.fillWidth: true
        current: VrService.tab
        onSelected: key => VrService.tab = key

        model: [
            {
                key: "connection",
                label: VrService.text("connection")
            },
            {
                key: "software",
                label: VrService.text("software")
            },
            {
                key: "applications",
                label: VrService.text("applications")
            },
            {
                key: "settings",
                label: VrService.text("settings")
            }
        ]
    }
}
