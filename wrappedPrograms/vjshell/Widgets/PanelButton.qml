import QtQuick
import qs.Commons

Rectangle {
    id: root

    property string text: ""
    property bool accent: false
    property bool enabled: true

    signal clicked

    implicitWidth: label.implicitWidth + Style.panelPadding * 2
    implicitHeight: 26
    radius: Style.radius

    opacity: enabled ? 1.0 : 0.4

    color: {
        if (!enabled)
            return Theme.surfaceVariant;
        if (root.accent)
            return Theme.accent;
        return hover.hovered ? Theme.surfaceHigh : Theme.surfaceVariant;
    }

    Behavior on color {
        ColorAnimation {
            duration: Style.animFast
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        color: root.accent ? Theme.surface : Theme.text
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
