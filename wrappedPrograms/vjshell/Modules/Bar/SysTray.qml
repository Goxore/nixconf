import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Services
import qs.Widgets

ColumnLayout {
    id: root

    spacing: Style.spacing

    property bool expanded: false

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Style.itemSize
        implicitHeight: Style.itemSize
        visible: SystemTray.items.values.length > 0

        StateLayer {
            id: toggleState
            cornerRadius: Style.radiusS
            hovered: toggleHover.hovered
            pressed: toggleTap.pressed
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: root.expanded ? Icons.expandLess : Icons.moreHoriz
            color: Theme.textDim

            scale: toggleTap.pressed ? Style.pressScale : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: Style.durShort2
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Style.standard
                }
            }
        }

        HoverHandler {
            id: toggleHover
        }

        TapHandler {
            id: toggleTap
            onPressedChanged: {
                if (pressed)
                    toggleState.press(point.position.x, point.position.y);
                else
                    toggleState.release();
            }
            onTapped: root.expanded = !root.expanded
        }
    }

    ColumnLayout {
        id: items

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: root.expanded ? implicitHeight : 0

        spacing: Style.spacing
        clip: true
        opacity: root.expanded ? 1 : 0

        Behavior on Layout.preferredHeight {
            NumberAnimation {
                duration: Style.durMorph
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.emphasized
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Style.durState
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.standard
            }
        }

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: entry

                required property SystemTrayItem modelData

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Style.itemSize
                implicitHeight: Style.itemSize

                StateLayer {
                    id: state
                    cornerRadius: Style.radiusS
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Style.iconSize
                    source: entry.modelData.icon

                    scale: mouse.pressed ? Style.pressScale : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Style.durShort2
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Style.standard
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onPressed: event => state.press(event.x, event.y)
                    onReleased: state.release()
                    onCanceled: state.release()

                    onClicked: event => {
                        switch (event.button) {
                        case Qt.LeftButton:
                            entry.modelData.activate();
                            break;
                        case Qt.MiddleButton:
                            entry.modelData.secondaryActivate();
                            break;
                        case Qt.RightButton:
                            if (entry.modelData.hasMenu) {
                                const pos = entry.mapToItem(null, 0, 0);
                                TrayMenuService.show(entry.modelData.menu, pos.y);
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
}
