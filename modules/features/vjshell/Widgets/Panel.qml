import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Services

ModalWindow {
    id: root

    required property string name

    property string title: ""
    property string subtitle: ""
    property int panelWidth: Style.panelWidth
    property int maxPanelHeight: Style.panelMaxHeight
    property bool fillHeight: false
    property bool centered: false
    property bool scrollable: true

    default property alias content: column.data
    property alias pinned: pinnedSlot.data
    property alias actions: actionSlot.data

    readonly property real contentWidth: scroll.width

    function close() {
        PanelService.close(name);
    }

    namespace: "panel"
    open: PanelService.isOpen(name, modelData.name)
    surface: box
    onDismissed: close()

    Surface {
        id: box

        readonly property real edgeGap: Style.barPadding
        readonly property real available: parent.height - edgeGap * 2

        width: Math.min(root.panelWidth, parent.width - edgeGap * 2)
        height: root.fillHeight ? available : Math.min(root.scrollable ? layout.implicitHeight + Style.panelPadding * 2 : root.maxPanelHeight, root.maxPanelHeight, available)
        x: root.centered ? Math.round((parent.width - width) / 2) : Style.barOnLeft ? edgeGap : parent.width - width - edgeGap
        y: root.centered ? Math.round((parent.height - height) / 2) : parent.height - height - edgeGap

        level: 3
        radius: Style.radiusXl
        color: Theme.surfaceContainerLow

        opacity: root.progress
        scale: 0.96 + 0.04 * root.progress
        transformOrigin: root.centered ? Item.Center : Style.barOnLeft ? Item.BottomLeft : Item.BottomRight

        transform: Translate {
            x: root.centered ? 0 : (Style.barOnLeft ? -1 : 1) * Style.panelPadding * (1 - root.progress)
            y: root.centered ? 12 * (1 - root.progress) : 0
        }

        Behavior on height {
            NumberMotion {
                duration: Style.durResize
            }
        }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Style.panelPadding
            spacing: Style.panelPadding

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: Style.touchTarget
                Layout.leftMargin: Style.spacing
                visible: root.title !== "" || actionSlot.children.length > 0
                spacing: Style.spacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        text: root.title
                        role: "titleLarge"
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: root.subtitle !== ""
                        text: root.subtitle
                        role: "bodyMedium"
                        color: Theme.inkSurfaceVariant
                    }
                }

                RowLayout {
                    id: actionSlot
                    spacing: 0
                }
            }

            ColumnLayout {
                id: pinnedSlot
                Layout.fillWidth: true
                visible: children.length > 0
                spacing: Style.groupSpacing
            }

            Flickable {
                id: scroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.scrollable ? column.implicitHeight : -1
                contentHeight: root.scrollable ? column.implicitHeight : height
                interactive: root.scrollable && contentHeight > height + 1
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Controls.ScrollBar.vertical: ListScrollBar {
                    parent: box
                    x: box.width - width - Style.scrollBarInset
                    y: layout.y + scroll.y
                    height: scroll.height
                    policy: scroll.interactive ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
                }

                ColumnLayout {
                    id: column
                    width: scroll.width
                    height: root.scrollable ? implicitHeight : scroll.height
                    spacing: Style.panelPadding
                }
            }
        }
    }
}
