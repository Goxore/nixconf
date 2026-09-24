pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
    id: root

    required property var entry
    property int depth: 0
    property bool expanded: false

    spacing: 0

    Divider {
        visible: root.entry.isSeparator
        Layout.topMargin: Style.buttonGap
        Layout.bottomMargin: Style.buttonGap
    }

    Pressable {
        id: row

        readonly property bool checkable: root.entry.buttonType !== QsMenuButtonType.None
        readonly property bool checked: root.entry.checkState === Qt.Checked
        readonly property color contentColor: root.entry.enabled ? Theme.inkSurface : Theme.disabledContent

        Layout.fillWidth: true
        visible: !root.entry.isSeparator
        implicitHeight: Style.listItemDense

        enabled: root.entry.enabled
        description: root.entry.text
        Accessible.role: Accessible.MenuItem
        cornerRadius: 0

        onClicked: {
            if (root.entry.hasChildren) {
                root.expanded = !root.expanded;
                return;
            }
            root.entry.triggered();
            TrayMenuService.close();
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.groupSpacing + Math.min(root.depth, 4) * Style.panelPadding
            anchors.rightMargin: Style.groupSpacing
            spacing: Style.groupSpacing

            MaterialIcon {
                visible: row.checkable
                text: root.entry.buttonType === QsMenuButtonType.CheckBox ? (row.checked ? Icons.checkBox : Icons.checkBoxOff) : (row.checked ? Icons.radioOn : Icons.radioOff)
                fill: row.checked ? 1 : 0
                color: row.checked ? Theme.primary : Theme.inkSurfaceVariant
            }

            IconImage {
                visible: source !== "" && status === Image.Ready
                implicitSize: Style.iconSize
                source: root.entry.icon
            }

            Label {
                Layout.fillWidth: true
                text: root.entry.text
                role: "labelLarge"
                font.weight: Font.Normal
                color: row.contentColor
            }

            MaterialIcon {
                visible: root.entry.hasChildren
                text: root.expanded ? Icons.expandMore : Icons.chevronRight
                color: Theme.inkSurfaceVariant
            }
        }
    }

    Loader {
        Layout.fillWidth: true
        active: root.entry.hasChildren && root.expanded
        visible: active

        sourceComponent: ColumnLayout {
            spacing: 0

            QsMenuOpener {
                id: opener
                menu: root.entry
            }

            Repeater {
                model: opener.children

                delegate: Loader {
                    required property var modelData

                    Layout.fillWidth: true
                    Component.onCompleted: setSource(Qt.resolvedUrl("TrayMenuEntry.qml"), {
                        entry: modelData,
                        depth: root.depth + 1
                    })
                }
            }
        }
    }
}
