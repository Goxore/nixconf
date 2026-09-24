import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
    id: root

    property bool expanded: false

    visible: SystemTray.items.values.length > 0
    spacing: 0

    BarButton {
        Layout.alignment: Qt.AlignHCenter
        icon: root.expanded ? Icons.expandLess : Icons.moreHoriz
        tooltip: root.expanded ? "Hide tray" : "Show tray"
        onClicked: root.expanded = !root.expanded
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: root.expanded ? implicitHeight : 0
        spacing: Style.spacing
        clip: true
        opacity: root.expanded ? 1 : 0

        Behavior on Layout.preferredHeight {
            NumberMotion {
                duration: Style.durMorph
                easing.bezierCurve: Style.emphasized
            }
        }

        Behavior on opacity {
            NumberMotion {}
        }

        Repeater {
            model: SystemTray.items

            delegate: Pressable {
                id: entry

                required property SystemTrayItem modelData

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Style.itemSize
                implicitHeight: Style.itemSize

                description: modelData.tooltipTitle || modelData.title
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                wheelEnabled: true

                onClicked: modelData.activate()
                onMiddleClicked: modelData.secondaryActivate()
                onScrolled: direction => modelData.scroll(direction * Style.wheelStep, false)
                onRightClicked: {
                    if (!modelData.hasMenu)
                        return;
                    const pos = entry.mapToItem(null, 0, 0);
                    TrayMenuService.show(modelData.menu, pos.y + entry.height / 2, QsWindow.window?.screen?.name ?? "");
                }
                onPressedChanged: if (pressed)
                    TooltipService.hide()

                BarHint {
                    target: entry
                    text: entry.description
                    hovered: entry.hovered && !entry.pressed
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Style.iconSize
                    source: entry.modelData.icon
                    scale: entry.pressed ? Style.pressScale : 1

                    Behavior on scale {
                        NumberMotion {
                            duration: Style.durShort2
                        }
                    }
                }
            }
        }
    }
}
