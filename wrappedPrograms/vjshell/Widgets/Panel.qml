import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

PanelWindow {
    id: root

    required property ShellScreen modelData
    required property string panelName

    property string title: ""

    property int maxPanelHeight: 520

    default property alias content: column.data

    screen: modelData
    visible: PanelService.isOpen(panelName)

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-panel"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() {
        PanelService.close(panelName);
    }

    TapHandler {
        onTapped: root.close()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }

    Rectangle {
        id: box

        y: parent.height - height - Style.barPadding
        x: Style.barOnLeft ? Style.barPadding : parent.width - width - Style.barPadding

        width: Style.panelWidth
        height: Math.min(column.implicitHeight + Style.panelPadding * 2, root.maxPanelHeight, parent.height - Style.barPadding * 2)

        radius: Style.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.surfaceHigh

        TapHandler {}

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Style.panelPadding
            spacing: Style.panelPadding

            Text {
                Layout.fillWidth: true
                visible: root.title !== ""
                text: root.title
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize + 2
                font.weight: Font.Bold
                color: Theme.textBright
            }
        }
    }
}
