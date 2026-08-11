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

    spacing: Style.spacing

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry

            required property SystemTrayItem modelData

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Style.itemSize
            implicitHeight: Style.itemSize

            StateLayer {
                id: state
                cornerRadius: Style.radiusS
                hovered: mouse.containsMouse
                pressed: mouse.pressed
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: Style.iconSize
                source: entry.modelData.icon

                scale: mouse.pressed ? Style.pressScale : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Style.durShort2
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Style.standard
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onPressed: event => state.press(event.x, event.y)
                onReleased: state.release()
                onCanceled: state.release()

                onClicked: event => {
                    switch (event.button) {
                    case Qt.LeftButton:
                        entry.modelData.activate();
                        break;
                    case Qt.MiddleButton:
                        entry.modelData.secondaryActivate();
                        break;
                    case Qt.RightButton:
                        if (entry.modelData.hasMenu) {
                            const pos = entry.mapToItem(null, 0, 0);
                            TrayMenuService.show(entry.modelData.menu, pos.y);
                        }
                        break;
                    }
                }
            }
        }
    }
}
