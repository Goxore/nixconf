import QtQuick
import Quickshell
import qs.Commons
import qs.Services

Item {
    id: root

    property string icon
    property color iconColor: Theme.text
    property int iconSize: Style.iconSize
    property real iconFill: 0
    property string tooltip: ""

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int direction)

    implicitWidth: Style.itemSize
    implicitHeight: Style.itemSize

    Timer {
        id: tooltipTimer
        interval: Style.tooltipDelay
        onTriggered: {
            const pos = root.mapToItem(null, 0, 0);
            TooltipService.show(root.tooltip, pos.y + root.height / 2, QsWindow.window?.screen?.name ?? "");
        }
    }

    onTooltipChanged: if (TooltipService.shown && mouse.containsMouse)
        TooltipService.text = tooltip

    StateLayer {
        id: state
        cornerRadius: Style.radiusS
        hovered: mouse.containsMouse
        pressed: mouse.pressed
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        font.pixelSize: root.iconSize
        color: root.iconColor
        fill: root.iconFill

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

        onContainsMouseChanged: {
            if (containsMouse && root.tooltip !== "")
                tooltipTimer.restart();
            else {
                tooltipTimer.stop();
                TooltipService.hide();
            }
        }

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
