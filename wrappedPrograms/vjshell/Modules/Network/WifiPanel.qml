import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.Commons
import qs.Widgets

Panel {
    id: root

    panelName: "wifi"
    title: "Wi-Fi"

    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;
        }
        return null;
    }

    readonly property var sorted: {
        if (!wifiDevice)
            return [];
        const networks = [...wifiDevice.networks.values];
        networks.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        return networks;
    }

    onOpenedChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = opened;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        MaterialIcon {
            text: Networking.wifiEnabled ? Icons.wifi : Icons.wifiOff
            fill: Networking.wifiEnabled ? 1 : 0
            color: Networking.wifiEnabled ? Theme.accent : Theme.textDim
        }

        Text {
            Layout.fillWidth: true
            text: {
                if (!Networking.wifiHardwareEnabled)
                    return "No Wi-Fi hardware";
                if (!root.wifiDevice)
                    return "No Wi-Fi device";
                return root.wifiDevice.name;
            }
            elide: Text.ElideRight
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: Theme.textDim
        }

        PanelButton {
            enabled: Networking.wifiHardwareEnabled
            text: Networking.wifiEnabled ? "On" : "Off"
            accent: Networking.wifiEnabled
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
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
        Layout.preferredHeight: Math.max(Style.listMinS, Math.min(contentHeight, Style.listMaxS))
        clip: true
        spacing: 2
        model: root.sorted

        delegate: NetworkRow {
            required property var modelData
            width: list.width
            network: modelData
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: Networking.wifiEnabled ? "Scanning..." : "Wi-Fi is off"
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: Theme.textDim
        }
    }

    PanelButton {
        Layout.fillWidth: true
        text: "Join a new network (nmtui)"
        onClicked: {
            Quickshell.execDetached([Quickshell.env("VJSHELL_TERMINAL") || "kitty", "-e", "nmtui"]);
            root.close();
        }
    }

    component NetworkRow: Rectangle {
        id: row

        required property var network

        implicitHeight: Style.rowHeight
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
                text: Icons.wifi
                color: Theme.text
                opacity: 0.35 + 0.65 * Math.min(1, (row.network.signalStrength || 0) / 100)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: row.network.name || "(hidden)"
                    elide: Text.ElideRight
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    color: row.network.connected ? Theme.active : Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        const bits = [];
                        if (row.network.connected)
                            bits.push("connected");
                        else if (row.network.known)
                            bits.push("saved");
                        if (row.network.stateChanging)
                            bits.push("...");
                        bits.push((row.network.signalStrength || 0) + "%");
                        return bits.join("  ");
                    }
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    color: Theme.textDim
                }
            }

            PanelButton {
                visible: row.network.connected || row.network.known
                enabled: !row.network.stateChanging
                text: row.network.connected ? "Disconnect" : "Connect"
                accent: row.network.connected
                onClicked: {
                    if (row.network.connected)
                        row.network.device.autoconnect = false;
                    else
                        row.network.connectWithSettings();
                }
            }
        }
    }
}
