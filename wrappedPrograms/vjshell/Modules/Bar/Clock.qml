import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component Line: Text {
        Layout.alignment: Qt.AlignHCenter
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        font.weight: Font.Bold
        color: Theme.textBright
    }

    Line {
        text: Qt.formatDateTime(clock.date, "HH")
    }
    Line {
        text: Qt.formatDateTime(clock.date, "mm")
    }
    Line {
        text: "-"
        color: Theme.textDim
    }
    Line {
        text: Qt.formatDateTime(clock.date, "dd")
    }
    Line {
        text: Qt.formatDateTime(clock.date, "MM")
        color: Theme.textDim
    }
}
