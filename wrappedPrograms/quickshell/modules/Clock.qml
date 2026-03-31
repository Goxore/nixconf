import QtQuick 2.15
import QtQuick.Layouts 1.15

ColumnLayout {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 0

    Text {
        id: clockHours
        font.pixelSize: 14
        color: "#fbf1c7"
        text: Qt.formatTime(new Date(), "hh")
        font.weight: 900
    }

    Text {
        id: clockMinutes
        font.pixelSize: 14
        text: Qt.formatTime(new Date(), "mm")
        font.weight: 900
        color: "#fbf1c7"
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            let now = new Date();
            clockHours.text = Qt.formatTime(now, "hh");
            clockMinutes.text = Qt.formatTime(now, "mm");
        }
    }
}
