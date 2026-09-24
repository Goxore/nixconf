import QtQuick
import Quickshell.Widgets
import qs.Commons

ClippingRectangle {
    id: root

    property string source: ""
    property string fallback: Icons.album
    property int rounding: Style.radiusS

    radius: rounding
    color: Theme.surfaceContainerHighest

    MaterialIcon {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        text: root.fallback
        font.pixelSize: Math.max(Style.iconSize, root.height * 0.4)
        color: Theme.inkSurfaceVariant
    }

    Image {
        id: art

        anchors.fill: parent
        source: root.source
        sourceSize.width: root.width * 2
        sourceSize.height: root.height * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: status === Image.Ready
    }
}
