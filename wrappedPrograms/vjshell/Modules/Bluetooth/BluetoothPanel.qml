import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.Commons
import qs.Widgets

Panel {
    id: root

    panelName: "bluetooth"
    title: "Bluetooth"
    icon: Icons.bluetooth

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    readonly property var sorted: {
        if (!adapter)
            return [];
        const devices = [...adapter.devices.values];
        devices.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return (a.deviceName || a.name || "").localeCompare(b.deviceName || b.name || "");
        });
        return devices;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        MaterialIcon {
            text: root.adapter?.enabled ? Icons.bluetooth : Icons.bluetoothOff
            fill: root.adapter?.enabled ? 1 : 0
            color: root.adapter?.enabled ? Theme.accent : Theme.textDim
        }

        Text {
            Layout.fillWidth: true
            text: root.adapter ? BluetoothAdapterState.toString(root.adapter.state) : "No adapter"
            elide: Text.ElideRight
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: Theme.textDim
        }

        PanelButton {
            enabled: root.adapter !== null
            icon: Icons.power
            text: root.adapter?.enabled ? "On" : "Off"
            accent: root.adapter?.enabled ?? false
            onClicked: root.adapter.enabled = !root.adapter.enabled
        }

        PanelButton {
            enabled: root.adapter?.enabled ?? false
            icon: Icons.search
            text: root.adapter?.discovering ? "Scanning" : "Scan"
            accent: root.adapter?.discovering ?? false
            onClicked: root.adapter.discovering = !root.adapter.discovering
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.dividerWidth
        color: Theme.surfaceHigh
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Style.listMinS, Math.min(contentHeight, Style.listMaxM))
        clip: true
        spacing: 2
        model: root.sorted

        delegate: DeviceRow {
            required property var modelData
            width: list.width
            device: modelData
        }

        ColumnLayout {
            anchors.centerIn: parent
            visible: list.count === 0
            spacing: Style.spacing

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: root.adapter?.enabled ? Icons.bluetooth : Icons.bluetoothOff
                font.pixelSize: Style.iconSizeXl
                color: Theme.textDim
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.adapter?.enabled ? "No devices" : "Bluetooth is off"
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                color: Theme.textDim
            }
        }
    }

    PanelButton {
        Layout.fillWidth: true
        icon: Icons.terminal
        text: "Pair with PIN (bluetoothctl)"
        onClicked: {
            Quickshell.execDetached([Quickshell.env("VJSHELL_TERMINAL") || "kitty", "-e", "bluetoothctl"]);
            root.close();
        }
    }

    component DeviceRow: Rectangle {
        id: row

        required property BluetoothDevice device

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

            MaterialIcon {
                Layout.preferredWidth: 22
                text: Icons.forBluetoothDevice(row.device.icon)
                fill: row.device.connected ? 1 : 0
                color: row.device.connected ? Theme.active : Theme.textDim
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: row.device.deviceName || row.device.name || row.device.address
                    elide: Text.ElideRight
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    color: row.device.connected ? Theme.active : Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        const state = BluetoothDeviceState.toString(row.device.state);
                        if (row.device.batteryAvailable)
                            return state + "  " + Math.round(row.device.battery * 100) + "%";
                        return state;
                    }
                    elide: Text.ElideRight
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    color: Theme.textDim
                }
            }

            PanelButton {
                icon: row.device.connected ? Icons.linkOff : row.device.pairing ? Icons.close : Icons.link
                text: row.device.connected ? "Disconnect" : row.device.pairing ? "Cancel" : "Connect"
                accent: row.device.connected
                onClicked: {
                    if (row.device.pairing)
                        row.device.cancelPair();
                    else if (row.device.connected)
                        row.device.disconnect();
                    else if (row.device.paired)
                        row.device.connect();
                    else
                        row.device.pair();
                }
            }

            PanelButton {
                visible: row.device.paired || row.device.bonded
                icon: Icons.remove
                text: "Forget"
                onClicked: row.device.forget()
            }
        }
    }
}
