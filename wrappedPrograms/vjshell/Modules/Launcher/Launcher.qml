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

    screen: modelData
    visible: reveal.active

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-launcher"
    WlrLayershell.keyboardFocus: reveal.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool calcSelected: false

    readonly property bool opened: reveal.open

    Reveal {
        id: reveal
        open: PanelService.isOpen("launcher")
        enterDuration: Style.durMedium2
    }

    function close() {
        PanelService.close("launcher");
    }

    function moveDown() {
        if (calcSelected)
            calcSelected = false;
        else
            list.incrementCurrentIndex();
    }

    function moveUp() {
        if (calcSelected)
            return;
        if (list.currentIndex === 0 && CalcService.active)
            calcSelected = true;
        else
            list.decrementCurrentIndex();
    }

    function activateSelected() {
        if (calcSelected && CalcService.active) {
            Quickshell.execDetached(["wl-copy", "--", CalcService.result]);
            close();
            return;
        }

        const entry = LauncherService.results[list.currentIndex];
        if (entry) {
            LauncherService.launch(entry);
            close();
        }
    }

    onOpenedChanged: {
        if (opened) {
            LauncherService.query = "";
            CalcService.clear();
            list.currentIndex = 0;
            calcSelected = false;
            input.clear();
            input.forceActiveFocus();
        }
    }

    Connections {
        target: CalcService
        function onActiveChanged() {
            root.calcSelected = CalcService.active;
        }
    }

    Item {
        anchors.fill: parent

        TapHandler {
            enabled: reveal.open
            onTapped: root.close()
        }
    }

    Surface {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height / 5)

        width: Style.launcherWidth
        height: column.implicitHeight + Style.panelPadding * 2

        level: 3
        radius: Style.radiusL

        opacity: reveal.progress
        scale: 0.94 + 0.06 * reveal.progress
        transformOrigin: Item.Center

        transform: Translate {
            y: 12 * (1 - reveal.progress)
        }

        TapHandler {}

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Style.panelPadding
            spacing: Style.panelPadding

            Item {
                id: header
                Layout.fillWidth: true
                implicitHeight: Style.iconBox

                TextInput {
                    id: input
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter

                    focus: true
                    clip: true
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeXl
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.surface

                    onTextChanged: {
                        LauncherService.query = text;
                        CalcService.update(text);
                        list.currentIndex = 0;
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text === ""
                        text: "Search applications"
                        font: input.font
                        color: Theme.textDim
                    }

                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.activateSelected()
                    Keys.onEnterPressed: root.activateSelected()
                    Keys.onUpPressed: root.moveUp()
                    Keys.onDownPressed: root.moveDown()

                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.ControlModifier) {
                            if (event.key === Qt.Key_N) {
                                root.moveDown();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_P) {
                                root.moveUp();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.dividerWidth
                color: Theme.surfaceHigh
            }

            CalcRow {
                Layout.fillWidth: true
                visible: CalcService.active
                selected: root.calcSelected

                onActivated: {
                    root.calcSelected = true;
                    root.activateSelected();
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: CalcService.active
                implicitHeight: Style.dividerWidth
                color: Theme.surfaceHigh
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(Style.listMin, Math.min(contentHeight, Style.listMax))

                clip: true
                spacing: 2
                model: LauncherService.results
                currentIndex: 0
                keyNavigationEnabled: false

                delegate: AppRow {
                    required property var modelData
                    required property int index

                    width: list.width
                    entry: modelData
                    selected: index === list.currentIndex

                    onActivated: {
                        list.currentIndex = index;
                        root.calcSelected = false;
                        root.activateSelected();
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No matches"
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    color: Theme.textDim
                }
            }
        }
    }
}
