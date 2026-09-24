import QtQuick
import Quickshell
import qs.Commons
import qs.Services

ModalWindow {
    id: root

    required property string name

    property int surfaceWidth: 0
    property int surfaceHeight: 0
    property int surfaceLevel: 3
    property int surfaceRadius: Style.radiusXl
    property bool topAligned: false

    default property alias content: box.content

    function close() {
        PanelService.close(name);
    }

    namespace: name
    open: PanelService.isOpen(name, modelData.name)
    surface: box
    enterDuration: Style.durMedium2
    onDismissed: close()

    Surface {
        id: box

        readonly property real centeredY: root.topAligned ? parent.height / 5 : (parent.height - height) / 2

        width: Math.min(root.surfaceWidth, parent.width - Style.panelPadding * 2)
        height: Math.min(root.surfaceHeight, parent.height - Style.panelPadding * 2)
        x: Math.round((parent.width - width) / 2)
        y: Math.round(Math.max(Style.panelPadding, Math.min(centeredY, parent.height - height - Style.panelPadding)))

        level: root.surfaceLevel
        radius: root.surfaceRadius
        color: Theme.surfaceContainer

        opacity: root.progress
        scale: 0.94 + 0.06 * root.progress

        transform: Translate {
            y: 12 * (1 - root.progress)
        }

        Behavior on height {
            NumberMotion {
                duration: Style.durResize
            }
        }
    }
}
