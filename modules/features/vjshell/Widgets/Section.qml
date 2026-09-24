import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root

    property string title: ""

    default property alias content: body.data

    Layout.fillWidth: true
    spacing: Style.buttonGap

    Label {
        Layout.fillWidth: true
        visible: root.title !== ""
        text: root.title
        role: "labelLarge"
        color: Theme.primary
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Style.spacing
    }
}
