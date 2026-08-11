import QtQuick
import qs.Commons

Item {
    id: root

    property string icon
    property color iconColor: Theme.text
    property int iconSize: Style.iconSize
    property string tooltip: ""

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int direction)

    implicitWidth: Style.itemSize
    implicitHeight: Style.itemSize

    Rectangle {
        anchors.fill: parent
        radius: Style.radius
        color: Theme.surfaceVariant
        opacity: mouse.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Style.animFast
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        font.pixelSize: root.iconSize
        color: root.iconColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.rightClicked();
            else if (event.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }

        onWheel: event => {
            root.scrolled(event.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
