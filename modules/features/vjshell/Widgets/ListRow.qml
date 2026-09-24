import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Commons

Pressable {
    id: root

    property string icon: ""
    property string iconSource: ""
    property string artwork: ""
    property string headline: ""
    property string supporting: ""
    property string overline: ""
    property int supportingLines: 1
    property int supportingElide: Text.ElideRight
    property int container: 3
    property bool dense: false
    property bool filled: true
    property bool first: true
    property bool last: true
    property int trailingPadding: Style.buttonGap
    property alias leading: leadingSlot.data

    default property alias trailing: trailingSlot.data

    readonly property bool twoLine: supporting !== "" || overline !== ""
    readonly property color containerColor: selected ? Theme.secondaryContainer : filled ? Theme.containerFor(container) : Theme.withAlpha(Theme.containerFor(container), 0)
    readonly property color contentColor: selected ? Theme.inkSecondaryContainer : Theme.inkSurface
    readonly property color supportColor: selected ? Theme.withAlpha(Theme.inkSecondaryContainer, Style.opacityDim) : Theme.inkSurfaceVariant

    implicitWidth: Style.listMin
    implicitHeight: Math.max(dense ? Style.listItemDense : twoLine ? Style.listItemTwoLine : Style.listItemOneLine, row.implicitHeight + Style.buttonGap * 2)

    description: headline
    Accessible.role: Accessible.ListItem
    Accessible.description: supporting

    topRadius: first ? Style.radiusL : Style.radiusXs
    bottomRadius: last ? Style.radiusL : Style.radiusXs
    layerColor: contentColor

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
        color: root.containerColor

        Behavior on color {
            ColorMotion {}
        }
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: Style.panelPadding
        anchors.rightMargin: trailingSlot.children.length > 0 ? root.trailingPadding : Style.panelPadding
        spacing: Style.panelPadding

        Artwork {
            visible: root.artwork !== ""
            Layout.preferredWidth: Style.iconBox
            Layout.preferredHeight: Style.iconBox
            source: root.artwork
        }

        IconImage {
            visible: root.iconSource !== "" && root.artwork === ""
            implicitSize: Style.iconBox
            source: root.iconSource
            asynchronous: true
        }

        MaterialIcon {
            visible: root.icon !== "" && root.artwork === "" && root.iconSource === ""
            Layout.preferredWidth: Style.iconBox
            text: root.icon
            font.pixelSize: Style.iconSizeXl
            fill: root.selected ? 1 : 0
            color: root.selected ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant
        }

        RowLayout {
            id: leadingSlot
            visible: children.length > 0
            spacing: Style.buttonGap
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                visible: root.overline !== ""
                text: root.overline
                role: "labelSmall"
                color: root.supportColor
            }

            Label {
                Layout.fillWidth: true
                text: root.headline
                role: root.dense ? "bodyMedium" : "bodyLarge"
                color: root.contentColor
            }

            Label {
                Layout.fillWidth: true
                visible: root.supporting !== ""
                text: root.supporting
                role: root.dense ? "bodySmall" : "bodyMedium"
                color: root.supportColor
                maximumLineCount: root.supportingLines
                elide: root.supportingElide
                wrapMode: root.supportingLines > 1 ? Text.Wrap : Text.NoWrap
            }
        }

        RowLayout {
            id: trailingSlot
            visible: children.length > 0
            spacing: Style.spacing
        }
    }
}
