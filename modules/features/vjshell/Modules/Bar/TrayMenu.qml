import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

ModalWindow {
    id: root

    namespace: "traymenu"
    open: TrayMenuService.open && TrayMenuService.screenName === modelData.name
    surface: box
    exitDuration: Style.durShort3
    onDismissed: TrayMenuService.close()

    QsMenuOpener {
        id: opener
        menu: TrayMenuService.handle
    }

    Surface {
        id: box

        x: Style.barOnLeft ? Style.barPadding : parent.width - width - Style.barPadding
        y: Math.max(Style.barPadding, Math.min(TrayMenuService.anchorY - height / 2, parent.height - height - Style.barPadding))
        width: Math.min(Style.menuWidth, parent.width - Style.barPadding * 2)
        height: Math.min(column.implicitHeight + Style.buttonGap * 2, parent.height - Style.barPadding * 2)

        level: 2
        radius: Style.radiusL
        color: Theme.surfaceContainer
        opacity: root.progress

        transform: Scale {
            origin.x: Style.barOnLeft ? 0 : box.width
            origin.y: Math.max(0, Math.min(box.height, TrayMenuService.anchorY - box.y))
            xScale: 0.85 + 0.15 * root.progress
            yScale: 0.85 + 0.15 * root.progress
        }

        Behavior on height {
            NumberMotion {
                duration: Style.durMorph
                easing.bezierCurve: Style.emphasized
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.topMargin: Style.buttonGap
            anchors.bottomMargin: Style.buttonGap
            contentHeight: column.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: ListScrollBar {}

            ColumnLayout {
                id: column

                width: parent.width
                spacing: 0

                Repeater {
                    model: opener.children

                    delegate: TrayMenuEntry {
                        required property var modelData

                        Layout.fillWidth: true
                        entry: modelData
                    }
                }
            }
        }
    }
}
