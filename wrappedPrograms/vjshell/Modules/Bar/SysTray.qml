import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Commons

ColumnLayout {
    id: root

    spacing: Style.spacing

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry

            required property SystemTrayItem modelData

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Style.iconSize
            implicitHeight: Style.iconSize

            IconImage {
                anchors.fill: parent
                source: entry.modelData.icon
                opacity: mouse.containsMouse ? 0.75 : 1.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Style.animFast
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: event => {
                    switch (event.button) {
                    case Qt.LeftButton:
                        entry.modelData.activate();
                        break;
                    case Qt.MiddleButton:
                        entry.modelData.secondaryActivate();
                        break;
                    case Qt.RightButton:
                        if (entry.modelData.hasMenu)
                            entry.modelData.display(QsWindow.window, entry.width, entry.y);
                        break;
                    }
                }
            }
        }
    }
}
