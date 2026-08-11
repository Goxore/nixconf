import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool mine: TooltipService.shown && TooltipService.screenName === modelData.name

    screen: modelData
    visible: reveal.active

    anchors {
        top: true
        bottom: true
        left: Style.barOnLeft
        right: !Style.barOnLeft
    }
    exclusiveZone: 0

    implicitWidth: 240
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-tooltip"

    mask: Region {}

    Reveal {
        id: reveal
        open: root.mine
        enterDuration: Style.durShort3
        exitDuration: Style.durShort2
    }

    Surface {
        id: box

        x: Style.barOnLeft ? Style.spacing + 8 * reveal.progress : parent.width - width - Style.spacing - 8 * reveal.progress
        y: Math.max(Style.spacing, Math.min(TooltipService.anchorY - height / 2, parent.height - height - Style.spacing))

        width: label.implicitWidth + Style.panelPadding * 2
        height: label.implicitHeight + Style.spacing * 2

        level: 2
        radius: Style.radiusS

        opacity: reveal.progress

        Text {
            id: label
            anchors.centerIn: parent
            text: TooltipService.text
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: Theme.text
        }
    }
}
