pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Overlay {
    id: root

    readonly property int columns: Math.max(1, Math.min(4, Math.floor((modelData.width - Style.panelPadding * 4) / (Style.menuLabel + Style.groupSpacing))))
    property int selectedIndex: 0

    function move(step) {
        selectedIndex = Math.max(0, Math.min(MenuService.entries.length - 1, selectedIndex + step));
    }

    name: "menu"
    surfaceWidth: grid.implicitWidth + Style.panelPadding * 2
    surfaceHeight: grid.implicitHeight + Style.panelPadding * 2

    onOpenedChanged: if (opened) {
        selectedIndex = 0;
        keys.forceActiveFocus();
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
        Keys.onUpPressed: root.move(-root.columns)
        Keys.onDownPressed: root.move(root.columns)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                const selected = MenuService.entries[root.selectedIndex];
                if (selected)
                    MenuService.run(selected);
                event.accepted = true;
                return;
            }
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                return;
            const entry = MenuService.find(event.key === Qt.Key_Tab ? "Tab" : event.text);
            if (entry) {
                MenuService.run(entry);
                event.accepted = true;
            }
        }

        GridLayout {
            id: grid

            anchors.centerIn: parent
            columns: root.columns
            rowSpacing: Style.groupSpacing
            columnSpacing: Style.groupSpacing

            Repeater {
                model: MenuService.entries

                delegate: ColumnLayout {
                    id: tile

                    required property var modelData
                    required property int index

                    readonly property bool selected: root.selectedIndex === index

                    Layout.alignment: Qt.AlignHCenter
                    spacing: Style.buttonGap

                    Pressable {
                        id: box

                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Style.menuTile
                        implicitHeight: Style.menuTile

                        description: tile.modelData.desc
                        selected: tile.selected
                        cornerRadius: shape.radius
                        layerColor: tile.selected ? Theme.inkSecondaryContainer : Theme.inkSurface

                        onHoveredChanged: if (hovered)
                            root.selectedIndex = tile.index
                        onClicked: MenuService.run(tile.modelData)

                        Rectangle {
                            id: shape

                            anchors.fill: parent
                            radius: tile.selected ? Style.radiusXl : Style.radiusL
                            color: tile.selected ? Theme.secondaryContainer : Theme.surfaceContainerHigh

                            Behavior on color {
                                ColorMotion {}
                            }

                            Behavior on radius {
                                NumberMotion {
                                    duration: Style.durShort4
                                    easing.bezierCurve: Style.emphasizedDecelerate
                                }
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: tile.modelData.icon
                            font.pixelSize: Style.iconSizeXl
                            fill: tile.selected ? 1 : 0
                            color: tile.selected ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Style.spacing
                            implicitWidth: Math.max(height, key.implicitWidth + Style.buttonGap)
                            implicitHeight: key.implicitHeight + Style.listGap
                            radius: height / 2
                            color: tile.selected ? Theme.secondary : Theme.surfaceContainerHighest

                            Behavior on color {
                                ColorMotion {}
                            }

                            Label {
                                id: key

                                anchors.centerIn: parent
                                text: tile.modelData.key
                                role: "labelSmall"
                                color: tile.selected ? Theme.inkSecondary : Theme.primary
                            }
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Style.menuLabel
                        text: tile.modelData.desc
                        role: "labelMedium"
                        horizontalAlignment: Text.AlignHCenter
                        color: tile.selected ? Theme.inkSurface : Theme.inkSurfaceVariant
                    }
                }
            }
        }
    }
}
