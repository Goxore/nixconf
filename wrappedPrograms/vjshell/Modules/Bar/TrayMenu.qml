import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    visible: TrayMenuService.open

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-traymenu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    TapHandler {
        onTapped: TrayMenuService.close()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: TrayMenuService.close()
    }

    QsMenuOpener {
        id: opener
        menu: TrayMenuService.handle
    }

    Rectangle {
        id: box

        x: Style.barOnLeft ? Style.barPadding : parent.width - width - Style.barPadding
        y: Math.max(Style.barPadding, Math.min(TrayMenuService.anchorY - height / 2, parent.height - height - Style.barPadding))

        width: 240
        implicitHeight: column.implicitHeight + Style.spacing * 2
        height: implicitHeight

        radius: Style.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.surfaceHigh

        TapHandler {}

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Style.spacing
            spacing: 1

            Repeater {
                model: opener.children

                delegate: ColumnLayout {
                    id: node

                    required property var modelData

                    property bool expanded: false

                    Layout.fillWidth: true
                    spacing: 1

                    MenuRow {
                        Layout.fillWidth: true
                        entry: node.modelData
                        expanded: node.expanded
                        onActivated: {
                            if (node.modelData.hasChildren)
                                node.expanded = !node.expanded;
                            else {
                                node.modelData.triggered();
                                TrayMenuService.close();
                            }
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        active: node.modelData.hasChildren && node.expanded
                        visible: active

                        sourceComponent: ColumnLayout {
                            spacing: 1

                            QsMenuOpener {
                                id: subOpener
                                menu: node.modelData
                            }

                            Repeater {
                                model: subOpener.children

                                delegate: MenuRow {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    entry: modelData
                                    indent: Style.panelPadding
                                    onActivated: {
                                        modelData.triggered();
                                        TrayMenuService.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Item {
        id: row

        required property var entry
        property bool expanded: false
        property int indent: 0

        signal activated

        implicitHeight: entry.isSeparator ? 7 : 28

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.spacing
            anchors.rightMargin: Style.spacing
            visible: row.entry.isSeparator
            height: 1
            color: Theme.surfaceHigh
        }

        Rectangle {
            anchors.fill: parent
            visible: !row.entry.isSeparator
            radius: Style.radius - 2
            color: hover.hovered && row.entry.enabled ? Theme.surfaceVariant : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Style.animFast
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.spacing + row.indent
                anchors.rightMargin: Style.spacing
                spacing: Style.spacing

                MaterialIcon {
                    visible: row.entry.buttonType !== QsMenuButtonType.None
                    text: row.entry.buttonType === QsMenuButtonType.CheckBox ? (row.entry.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank") : (row.entry.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked")
                    font.pixelSize: Style.fontSize + 2
                    color: Theme.accent
                }

                IconImage {
                    visible: source !== "" && status === Image.Ready
                    implicitSize: Style.fontSize + 4
                    source: row.entry.icon
                }

                Text {
                    Layout.fillWidth: true
                    text: row.entry.text
                    elide: Text.ElideRight
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    color: row.entry.enabled ? Theme.text : Theme.outline
                }

                MaterialIcon {
                    visible: row.entry.hasChildren
                    text: row.expanded ? "expand_more" : "chevron_right"
                    font.pixelSize: Style.fontSize + 2
                    color: Theme.textDim
                }
            }

            HoverHandler {
                id: hover
                enabled: row.entry.enabled
            }

            TapHandler {
                enabled: row.entry.enabled
                onTapped: row.activated()
            }
        }
    }
}
