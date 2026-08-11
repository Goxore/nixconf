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

    property int maxPanelHeight: Style.panelMaxHeight

    readonly property bool opened: reveal.open

    default property alias content: column.data

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
    WlrLayershell.namespace: "vjshell-panel"
    WlrLayershell.keyboardFocus: reveal.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function close() {
        PanelService.close(panelName);
    }

    Reveal {
        id: reveal
        open: PanelService.isOpen(root.panelName)
    }

    TapHandler {
        enabled: reveal.open
        onTapped: root.close()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }

    Surface {
        id: box

        y: parent.height - height - Style.barPadding
        x: Style.barOnLeft ? Style.barPadding : parent.width - width - Style.barPadding

        width: Style.panelWidth
        height: Math.min(column.implicitHeight + Style.panelPadding * 2, root.maxPanelHeight, parent.height - Style.barPadding * 2)

        level: 3
        radius: Style.radiusL

        opacity: reveal.progress
        scale: 0.96 + 0.04 * reveal.progress
        transformOrigin: Style.barOnLeft ? Item.BottomLeft : Item.BottomRight

        transform: Translate {
            x: (Style.barOnLeft ? -1 : 1) * 16 * (1 - reveal.progress)
        }

        Behavior on height {
            NumberAnimation {
                duration: Style.durResize
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.standard
            }
        }

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
                font.pixelSize: Style.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.textBright
            }
        }
    }
}
