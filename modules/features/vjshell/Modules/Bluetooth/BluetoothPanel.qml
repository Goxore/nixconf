pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false
    property BluetoothAdapter scanningAdapter: null

    readonly property var devices: {
        if (!adapter)
            return [];
        return [...adapter.devices.values].sort((a, b) => nameOf(a).localeCompare(nameOf(b)));
    }
    readonly property var connected: devices.filter(device => device.connected)
    readonly property var paired: devices.filter(device => !device.connected && (device.paired || device.bonded))
    readonly property var available: devices.filter(device => !device.connected && !device.paired && !device.bonded)

    function nameOf(device) {
        return device.deviceName || device.name || device.address;
    }

    function setScanning(value) {
        if (!adapter)
            return;
        adapter.discovering = value;
        scanningAdapter = value ? adapter : null;
    }

    function stopScan() {
        if (scanningAdapter)
            scanningAdapter.discovering = false;
        scanningAdapter = null;
    }

    name: "bluetooth"
    title: "Bluetooth"

    onOpenedChanged: if (!opened)
        stopScan()
    Component.onDestruction: stopScan()

    actions: IconButton {
        icon: Icons.rotate
        variant: "toggle"
        selected: root.scanning
        enabled: root.powered
        description: root.scanning ? "Stop scanning" : "Scan for devices"
        onClicked: root.setScanning(!root.scanning)
    }

    Timer {
        interval: Style.scanTimeout
        running: root.scanningAdapter !== null
        onTriggered: root.stopScan()
    }

    MasterSwitch {
        text: "Use Bluetooth"
        supporting: root.adapter ? (root.scanning ? "Looking for devices" : root.adapter.name) : "No adapter found"
        checked: root.powered
        busy: root.scanning
        enabled: root.adapter !== null
        onToggled: value => root.adapter.enabled = value
    }

    EmptyState {
        visible: root.powered && root.devices.length === 0
        icon: Icons.bluetooth
        title: "No devices yet"
        supporting: "Scan to find devices nearby"
    }

    DeviceSection {
        title: "Connected"
        model: root.connected
    }

    DeviceSection {
        title: "Paired"
        model: root.paired
    }

    DeviceSection {
        title: "Available"
        model: root.available
    }

    Button {
        Layout.alignment: Qt.AlignHCenter
        icon: Icons.terminal
        text: "Pair with a PIN in bluetoothctl"
        variant: "text"
        onClicked: {
            LauncherService.runInTerminal(["bluetoothctl"]);
            root.close();
        }
    }

    component DeviceSection: Section {
        id: section

        property var model: []

        visible: root.powered && model.length > 0

        ListGroup {
            Repeater {
                model: section.model

                DeviceRow {}
            }
        }
    }

    component DeviceRow: ListRow {
        id: row

        required property BluetoothDevice modelData

        readonly property BluetoothDevice device: modelData
        readonly property bool changing: device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting || device.pairing

        Layout.fillWidth: true
        icon: Icons.forBluetoothDevice(device.icon)
        headline: root.nameOf(device)
        supporting: {
            const state = changing ? BluetoothDeviceState.toString(device.state) : device.connected ? "Connected" : device.paired ? "Tap to connect" : "Tap to pair";
            return device.batteryAvailable ? state + " · " + Math.round(device.battery * 100) + "%" : state;
        }
        selected: device.connected

        onClicked: {
            if (device.pairing)
                device.cancelPair();
            else if (device.connected)
                device.disconnect();
            else if (device.paired)
                device.connect();
            else
                device.pair();
        }

        Spinner {
            visible: row.changing
            Layout.rightMargin: Style.buttonGap
        }

        IconButton {
            visible: !row.changing && (row.device.paired || row.device.bonded)
            icon: Icons.remove
            compact: true
            description: "Forget"
            onClicked: row.device.forget()
        }
    }
}
