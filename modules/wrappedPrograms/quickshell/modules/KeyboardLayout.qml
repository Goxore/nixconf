import QtQuick 2.15
import "../services"

Text {
    anchors.horizontalCenter: parent.horizontalCenter
    text: LayoutService.currentLayout

    color: "#fbf1c7"
}
