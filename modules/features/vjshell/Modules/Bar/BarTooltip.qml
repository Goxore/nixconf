import QtQuick
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
    color: "transparent"
    exclusiveZone: 0
    implicitWidth: Style.tooltipMaxWidth

    anchors {
        top: true
        bottom: true
        left: Style.barOnLeft
        right: !Style.barOnLeft
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-tooltip"

    mask: Region {}

    Reveal {
        id: reveal
        open: TooltipService.shown && TooltipService.screenName === root.modelData.name
        enterDuration: Style.durShort3
        exitDuration: Style.durShort2
    }

    Rectangle {
        id: box

        readonly property real slide: Style.buttonGap * reveal.progress

        x: Style.barOnLeft ? Style.spacing + slide : parent.width - width - Style.spacing - slide
        y: Math.max(Style.spacing, Math.min(TooltipService.anchorY - height / 2, parent.height - height - Style.spacing))
        width: Math.min(label.implicitWidth + Style.buttonGap * 2, root.width - Style.panelPadding)
        height: Math.max(Style.tooltipHeight, label.implicitHeight + Style.spacing * 2)
        radius: Style.radiusXs
        color: Theme.inverseSurface
        opacity: reveal.progress

        Label {
            id: label

            anchors.fill: parent
            anchors.leftMargin: Style.buttonGap
            anchors.rightMargin: Style.buttonGap
            text: TooltipService.text
            role: "bodySmall"
            color: Theme.inkInverseSurface
        }
    }
}
