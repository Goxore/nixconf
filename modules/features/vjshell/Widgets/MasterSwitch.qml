import QtQuick
import QtQuick.Layouts
import qs.Commons

Pressable {
    id: root

    property string text: ""
    property string supporting: ""
    property bool checked: false
    property bool busy: false

    signal toggled(bool value)

    readonly property color contentColor: checked ? Theme.inkPrimaryContainer : Theme.inkSurface

    Layout.fillWidth: true
    implicitHeight: Math.max(Style.listItemTwoLine + Style.buttonGap, column.implicitHeight + Style.panelPadding * 2)

    description: text
    selected: checked
    Accessible.role: Accessible.CheckBox
    cornerRadius: Style.radiusXl
    layerColor: contentColor

    onClicked: toggled(!checked)

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusXl
        color: !root.enabled ? Theme.disabledContainer : root.checked ? Theme.primaryContainer : Theme.surfaceContainerHigh

        Behavior on color {
            ColorMotion {}
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.panelPadding + Style.spacing
        anchors.rightMargin: Style.panelPadding
        spacing: Style.panelPadding

        ColumnLayout {
            id: column

            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.text
                role: "titleMedium"
                color: root.enabled ? root.contentColor : Theme.disabledContent
            }

            Label {
                Layout.fillWidth: true
                visible: root.supporting !== ""
                text: root.supporting
                role: "bodyMedium"
                color: root.checked ? Theme.withAlpha(root.contentColor, Style.opacityDim) : Theme.inkSurfaceVariant
            }
        }

        Switch {
            checked: root.checked
            enabled: root.enabled
            activeFocusOnTab: false
            description: root.text
            onToggled: value => root.toggled(value)
        }
    }

    LinearProgress {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Style.radiusXl
        anchors.rightMargin: Style.radiusXl
        visible: root.busy
        indeterminate: true
        implicitHeight: Style.dividerWidth * 2
        trackColor: "transparent"
    }
}
