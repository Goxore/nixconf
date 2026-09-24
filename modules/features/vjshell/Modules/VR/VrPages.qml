import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
    id: root

    property string encoder: "auto"
    property string codec: "auto"

    readonly property var headset: VrService.headset
    readonly property var runtime: VrService.state.runtime
    readonly property var hotspot: VrService.state.hotspot
    readonly property bool idle: VrService.online && !VrService.busy
    readonly property bool configurable: idle && !VrService.connected

    function orUnavailable(value) {
        return value ? String(value) : VrService.text("unavailable");
    }

    Layout.fillWidth: true
    spacing: Style.groupSpacing * 2

    ColumnLayout {
        Layout.fillWidth: true
        visible: VrService.tab === "connection"
        spacing: Style.groupSpacing * 2

        Section {
            title: VrService.text("network")

            ListGroup {
                ListRow {
                    Layout.fillWidth: true
                    headline: VrService.text("hotspot")
                    supporting: root.hotspot?.ssid || ""
                    interactive: root.idle
                    onClicked: VrService.toggleHotspot()

                    Switch {
                        checked: root.hotspot?.state === "active"
                        enabled: root.idle
                        description: VrService.text("hotspot")
                        onToggled: VrService.toggleHotspot()
                    }
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("password")
                    value: root.orUnavailable(root.hotspot?.passphrase)
                    muted: !root.hotspot?.passphrase
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("address")
                    value: root.orUnavailable(root.headset?.address)
                    muted: !root.headset?.address
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("channel")
                    value: root.orUnavailable(root.hotspot?.channel)
                    muted: !root.hotspot?.channel
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("channel_width")
                    value: root.hotspot?.width ? VrService.text("width_value", {
                        width: root.hotspot.width
                    }) : VrService.text("unavailable")
                    muted: !root.hotspot?.width
                }
            }
        }

        Section {
            title: VrService.text("wireless_control")

            Label {
                Layout.fillWidth: true
                Layout.bottomMargin: Style.spacing
                text: VrService.text("bootstrap")
                role: "bodyMedium"
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Theme.inkSurfaceVariant
            }

            Button {
                Layout.fillWidth: true
                text: VrService.text("enable_wireless")
                icon: Icons.link
                variant: "tonal"
                enabled: VrService.manageable && !VrService.busy
                onClicked: VrService.send({
                    action: "enable_wireless"
                })
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.buttonGap

                Button {
                    Layout.fillWidth: true
                    text: VrService.text("pair")
                    variant: "outlined"
                    enabled: root.idle
                    onClicked: VrService.send({
                        action: "pair"
                    })
                }

                Button {
                    Layout.fillWidth: true
                    text: VrService.text("launch_wivrn")
                    variant: "outlined"
                    enabled: VrService.manageable && !VrService.busy
                    onClicked: VrService.send({
                        action: "launch"
                    })
                }
            }

            Notice {
                visible: root.runtime?.pairing ?? false
                tone: "primary"
                icon: Icons.link
                text: VrService.text("pairing_code", {
                    pin: root.runtime?.pin || ""
                })
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: VrService.tab === "software"
        spacing: Style.groupSpacing * 2

        Section {
            title: VrService.text("wivrn")

            ListGroup {
                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("pc")
                    value: root.orUnavailable(root.runtime?.version)
                    muted: !root.runtime?.version
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("headset")
                    value: root.orUnavailable(VrService.client?.version)
                    muted: !VrService.client?.version
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("source")
                    value: VrService.text(VrService.client?.source || "unknown")
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("latest_release")
                    value: VrService.state.latest_version || VrService.text("not_checked")
                    muted: !VrService.state.latest_version
                }
            }

            Notice {
                visible: !!VrService.client
                tone: VrService.compatible ? "success" : "warning"
                icon: VrService.compatible ? Icons.checkCircle : Icons.warning
                text: VrService.text(VrService.compatible ? "versions_match" : "matching_help")

                Button {
                    visible: !VrService.compatible
                    text: VrService.text("install_matching")
                    icon: Icons.install
                    variant: "filled"
                    tone: "warning"
                    enabled: VrService.manageable && !VrService.busy && !VrService.connected
                    onClicked: VrService.install()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.buttonGap

                Button {
                    Layout.fillWidth: true
                    text: VrService.text("check_updates")
                    icon: Icons.update
                    variant: "outlined"
                    enabled: root.idle
                    onClicked: VrService.send({
                        action: "updates"
                    })
                }

                Button {
                    Layout.fillWidth: true
                    text: VrService.text("refresh")
                    icon: Icons.reset
                    variant: "outlined"
                    enabled: VrService.manageable && !VrService.busy
                    onClicked: VrService.send({
                        action: "refresh"
                    })
                }
            }
        }

        Section {
            title: VrService.text("headset")

            ListGroup {
                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("android")
                    value: root.orUnavailable(root.headset?.android)
                    muted: !root.headset?.android
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("os_build")
                    value: root.orUnavailable(root.headset?.os_build)
                    muted: !root.headset?.os_build
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("storage_available")
                    value: VrService.size(root.headset?.storage_available)
                }
            }

            Label {
                Layout.fillWidth: true
                visible: !!root.headset?.inventory_time
                text: VrService.manageable ? VrService.text("checked_value", {
                    time: VrService.seen(root.headset?.inventory_time)
                }) : VrService.text("stale_inventory")
                role: "bodySmall"
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Theme.outline
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: VrService.tab === "applications"
        spacing: Style.groupSpacing

        TextField {
            icon: Icons.search
            placeholder: VrService.text("search_applications")
            text: VrService.search
            onEdited: value => VrService.search = value
        }

        EmptyState {
            visible: VrService.applications.length === 0
            icon: VrService.search ? Icons.emptySearch : Icons.emptyApps
            title: VrService.text(VrService.search ? "no_matching_applications" : "no_applications")
        }

        ListGroup {
            Repeater {
                model: VrService.applications

                ListRow {
                    required property var modelData

                    Layout.fillWidth: true
                    icon: Icons.application
                    headline: modelData.package
                    supporting: modelData.version
                    interactive: false

                    IconButton {
                        icon: Icons.play
                        variant: "tonal"
                        description: VrService.text("play")
                        enabled: VrService.manageable && !VrService.busy
                        onClicked: VrService.send({
                            action: "launch_app",
                            package: modelData.package
                        })
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: VrService.tab === "settings"
        spacing: Style.groupSpacing * 2

        Section {
            title: VrService.text("when_starting")

            ListGroup {
                Preference {
                    title: VrService.text("start_hotspot_preference")
                    key: "start_hotspot"
                }

                Preference {
                    title: VrService.text("desktop_preference")
                    key: "open_desktop"
                }

                Preference {
                    title: VrService.text("headset_audio")
                    key: "headset_audio"
                }
            }
        }

        Section {
            title: VrService.text("streaming")

            ListGroup {
                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("refresh_rate")
                    value: root.runtime?.refresh_rate ? VrService.text("hz_value", {
                        rate: root.runtime.refresh_rate
                    }) : VrService.text("unavailable")
                    muted: !root.runtime?.refresh_rate
                }

                DetailRow {
                    Layout.fillWidth: true
                    headline: VrService.text("bitrate")
                    value: root.runtime?.bitrate ? VrService.text("mbps_value", {
                        rate: Math.round(root.runtime.bitrate / 1000000)
                    }) : VrService.text("unavailable")
                    muted: !root.runtime?.bitrate
                }
            }

            Choices {
                title: VrService.text("encoder")
                options: ["auto", "vaapi", "vulkan", "x264"]
                current: root.encoder
                onPicked: value => root.encoder = value
            }

            Choices {
                title: VrService.text("codec")
                options: ["auto", "h264", "h265", "av1"]
                current: root.codec
                onPicked: value => root.codec = value
            }

            Button {
                Layout.fillWidth: true
                Layout.topMargin: Style.spacing
                text: VrService.text("apply")
                variant: "filled"
                enabled: root.configurable
                onClicked: VrService.send({
                    action: "configure",
                    encoder: root.encoder,
                    codec: root.codec
                })
            }
        }

        Section {
            title: VrService.text("headset")

            Button {
                Layout.fillWidth: true
                text: VrService.text("open_desktop")
                icon: Icons.desktop
                variant: "tonal"
                enabled: VrService.connected && !VrService.busy
                onClicked: VrService.send({
                    action: "desktop"
                })
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.buttonGap

                Button {
                    Layout.fillWidth: true
                    text: VrService.text("use_headset_audio")
                    variant: "outlined"
                    enabled: VrService.connected && !VrService.busy
                    onClicked: VrService.send({
                        action: "audio",
                        headset: true
                    })
                }

                Button {
                    Layout.fillWidth: true
                    text: VrService.text("restore_audio")
                    variant: "outlined"
                    enabled: root.idle
                    onClicked: VrService.send({
                        action: "audio",
                        headset: false
                    })
                }
            }

            Label {
                Layout.fillWidth: true
                text: VrService.text("headset_settings")
                role: "bodySmall"
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Theme.outline
            }
        }
    }

    component Preference: ListRow {
        id: preference

        property string title: ""
        property string key: ""

        readonly property bool value: VrService.state.preferences?.[key] ?? false

        Layout.fillWidth: true
        headline: title
        interactive: root.idle
        onClicked: VrService.preference(key, !value)

        Switch {
            checked: preference.value
            enabled: root.idle
            description: preference.title
            onToggled: value => VrService.preference(preference.key, value)
        }
    }

    component Choices: ColumnLayout {
        id: choices

        property string title: ""
        property var options: []
        property string current: ""

        signal picked(string value)

        Layout.fillWidth: true
        Layout.topMargin: Style.buttonGap
        spacing: Style.buttonGap

        Label {
            text: choices.title
            role: "titleSmall"
            color: Theme.inkSurfaceVariant
        }

        Flow {
            Layout.fillWidth: true
            spacing: Style.buttonGap

            Repeater {
                model: choices.options

                Chip {
                    required property string modelData

                    text: modelData === "auto" ? VrService.text("automatic") : modelData
                    selected: choices.current === modelData
                    enabled: root.configurable
                    onClicked: choices.picked(modelData)
                }
            }
        }
    }
}
