import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property string tone: "surface"
    property bool busy: false

    default property alias actions: slot.data

    readonly property var palette: Theme.tone(tone)
    readonly property color contentColor: palette.inkContainer

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + Style.panelPadding * 2
    radius: Style.radiusM
    color: palette.container

    Behavior on color {
        ColorMotion {}
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.panelPadding
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.panelPadding

            MaterialIcon {
                Layout.alignment: Qt.AlignTop
                visible: root.icon !== ""
                text: root.icon
                font.pixelSize: Style.iconSizeL
                fill: 1
                color: root.contentColor
            }

            Label {
                Layout.fillWidth: true
                text: root.text
                role: "bodyMedium"
                color: root.contentColor
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
        }

        LinearProgress {
            Layout.topMargin: Style.groupSpacing
            visible: root.busy
            indeterminate: true
            color: root.contentColor
            trackColor: Theme.withAlpha(root.contentColor, 0.2)
        }

        RowLayout {
            id: slot

            Layout.alignment: Qt.AlignRight
            Layout.topMargin: implicitHeight > 0 ? Style.buttonGap : 0
            spacing: Style.buttonGap
        }
    }
}
