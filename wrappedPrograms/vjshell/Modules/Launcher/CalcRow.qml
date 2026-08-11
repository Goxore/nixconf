import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services

Rectangle {
    id: root

    required property bool selected

    signal activated

    implicitHeight: 52
    radius: Style.radius
    color: selected ? Theme.surfaceHigh : hover.hovered ? Theme.surfaceVariant : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Style.animFast
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.activated()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.panelPadding
        anchors.rightMargin: Style.panelPadding
        spacing: Style.panelPadding

        Text {
            text: "="
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize + 8
            font.weight: Font.Bold
            color: Theme.accent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: CalcService.result
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize + 4
                font.weight: Font.Bold
                color: Theme.textBright
            }

            Text {
                Layout.fillWidth: true
                text: CalcService.evaluated
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                color: Theme.textDim
            }
        }

        Text {
            text: "copy"
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: root.selected ? Theme.accent : Theme.textDim
        }
    }
}
