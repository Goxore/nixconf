pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    readonly property var device: [...Networking.devices.values].find(device => device.type === DeviceType.Wifi) ?? null
    readonly property bool powered: Networking.wifiEnabled
    readonly property var networks: device ? [...device.networks.values].sort((a, b) => (b.signalStrength || 0) - (a.signalStrength || 0)) : []
    readonly property var connected: networks.filter(network => network.connected)
    readonly property var saved: networks.filter(network => !network.connected && network.known)
    readonly property var available: networks.filter(network => !network.connected && !network.known)

    name: "wifi"
    title: "Wi-Fi"

    Binding {
        target: root.device
        property: "scannerEnabled"
        value: root.opened && root.powered
        when: root.device !== null
    }

    MasterSwitch {
        text: "Use Wi-Fi"
        supporting: {
            if (!Networking.wifiHardwareEnabled)
                return "Wi-Fi hardware is switched off";
            if (!root.device)
                return "No Wi-Fi adapter found";
            return root.connected.length > 0 ? root.connected[0].name : root.device.name;
        }
        checked: root.powered
        busy: root.powered && root.networks.length === 0
        enabled: Networking.wifiHardwareEnabled
        onToggled: value => Networking.wifiEnabled = value
    }

    EmptyState {
        visible: root.powered && root.device !== null && root.networks.length === 0
        icon: Icons.wifi
        title: "Looking for networks"
        supporting: "Networks in range will show up here"
    }

    NetworkSection {
        title: "Connected"
        model: root.connected
    }

    NetworkSection {
        title: "Saved"
        model: root.saved
    }

    NetworkSection {
        title: "Available"
        model: root.available
    }

    Button {
        Layout.alignment: Qt.AlignHCenter
        icon: Icons.terminal
        text: "Join another network in nmtui"
        variant: "text"
        onClicked: {
            LauncherService.runInTerminal(["nmtui"]);
            root.close();
        }
    }

    component NetworkSection: Section {
        id: section

        property var model: []

        visible: root.powered && model.length > 0

        ListGroup {
            Repeater {
                model: section.model

                NetworkRow {}
            }
        }
    }

    component NetworkRow: ListRow {
        id: row

        required property var modelData

        readonly property var network: modelData
        readonly property bool open: network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe
        readonly property int strength: Math.round((network.signalStrength || 0) * 100)

        Layout.fillWidth: true
        icon: Icons.forSignal(network.signalStrength || 0)
        headline: network.name || "Hidden network"
        supporting: {
            if (network.stateChanging)
                return network.connected ? "Disconnecting" : "Connecting";
            if (network.connected)
                return "Connected · " + strength + "%";
            if (network.known)
                return "Saved · " + strength + "%";
            return (open ? "Open" : "Secured") + " · " + strength + "%";
        }
        selected: network.connected
        interactive: !network.stateChanging && (network.connected || network.known)

        onClicked: network.connected ? network.disconnect() : network.connect()

        Spinner {
            visible: row.network.stateChanging
            Layout.rightMargin: Style.buttonGap
        }

        MaterialIcon {
            visible: !row.network.stateChanging && !row.open && !row.network.known
            Layout.rightMargin: Style.buttonGap
            text: Icons.lock
            color: Theme.inkSurfaceVariant
        }
    }
}
