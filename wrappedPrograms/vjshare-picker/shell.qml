import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

ShellRoot {
    id: root

    property string listPath: Quickshell.env("VJSHARE_LIST") || ""
    property string resultPath: Quickshell.env("VJSHARE_RESULT") || ""
    property var lines: []
    property bool done: false

    readonly property var items: root.lines.map(root.parseLine)

    function parseLine(line) {
        if (line.startsWith("Monitor: "))
            return {
                raw: line,
                kind: "Monitor",
                icon: "desktop_windows",
                label: line.slice("Monitor: ".length),
                captureSource: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
            };

        if (line.startsWith("Window: "))
            return {
                raw: line,
                kind: "Window",
                icon: "web_asset",
                label: line.slice("Window: ".length).replace(/ \([0-9a-f]+\)$/, ""),
                captureSource: null
            };

        return {
            raw: line,
            kind: "",
            icon: "web_asset",
            label: line,
            captureSource: null
        };
    }

    function finish(raw) {
        if (root.done)
            return;
        root.done = true;
        writer.command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "_", raw || "", root.resultPath];
        writer.running = true;
    }

    function activateSelected() {
        const item = root.items[list.currentIndex];
        root.finish(item ? item.raw : "");
    }

    FileView {
        id: listFile
        path: root.listPath
        preload: true
        blockLoading: true
    }

    Process {
        id: writer
        onExited: Qt.quit()
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        color: "transparent"
        exclusiveZone: 0
        visible: !root.done

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "vjshell-screenshare-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Component.onCompleted: {
            root.lines = listFile.text().split("\n").map(l => l.trim()).filter(l => l.length > 0);
            list.forceActiveFocus();
        }

        Item {
            anchors.fill: parent

            TapHandler {
                onTapped: root.finish("")
            }

            Surface {
                id: panel
                anchors.centerIn: parent
                width: Style.launcherWidth
                height: Math.min(column.implicitHeight + Style.panelPadding * 2, Style.panelMaxHeight)

                level: 3
                radius: Style.radiusL

                TapHandler {}

                ColumnLayout {
                    id: column
                    anchors.fill: parent
                    anchors.margins: Style.panelPadding
                    spacing: Style.panelPadding

                    Text {
                        Layout.fillWidth: true
                        text: "Share your screen"
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeXl
                        color: Theme.text
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Style.dividerWidth
                        color: Theme.surfaceHigh
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(Style.listMin, Math.min(contentHeight, Style.listMax))

                        clip: true
                        spacing: 2
                        model: root.items
                        currentIndex: 0
                        keyNavigationEnabled: false
                        focus: true

                        delegate: ShareRow {
                            required property var modelData
                            required property int index

                            width: list.width
                            item: modelData
                            selected: index === list.currentIndex

                            onActivated: {
                                list.currentIndex = index;
                                root.activateSelected();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: list.count === 0
                            text: "Nothing to share"
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSize
                            color: Theme.textDim
                        }

                        Keys.onEscapePressed: root.finish("")
                        Keys.onReturnPressed: root.activateSelected()
                        Keys.onEnterPressed: root.activateSelected()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onDownPressed: list.incrementCurrentIndex()
                    }
                }
            }
        }
    }
}
