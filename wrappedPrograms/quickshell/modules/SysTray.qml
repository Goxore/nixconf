import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell.Services.SystemTray

ColumnLayout {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 10

    Repeater {
        id: root
        model: SystemTray.items

        delegate: Rectangle {
            implicitHeight: 16
            implicitWidth: 16
            color: "#00000000"

            Image {
                source: modelData.icon
                anchors.fill: parent
            }

            MouseArea {
                anchors.fill: parent
                onClicked: event => {
                    if (event.button === Qt.LeftButton) {
                        console.log(modelData.title);
                        modelData.activate();
                    } else {
                        modelData.secondaryActivate();
                    }
                    modelData.display(this, 0, 0);
                }
            }
        }
    }
}
