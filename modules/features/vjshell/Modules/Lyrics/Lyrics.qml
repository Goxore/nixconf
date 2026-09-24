import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    readonly property bool interactive: PanelService.isOpen("lyricsControl", modelData.name)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "vjshell-lyrics"
    aboveWindows: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"

    mask: root.interactive ? interactiveRegion : clickThrough

    Region {
        id: clickThrough
    }

    Region {
        id: interactiveRegion
        item: hitArea
    }

    Item {
        id: hitArea

        readonly property real reach: Math.hypot(content.width, content.height) / 2 * content.userScale + Style.iconBox

        x: content.x + content.width / 2 - reach
        y: content.y + content.height / 2 - reach
        width: reach * 2
        height: reach * 2
    }

    function resetLayout() {
        content.x = (root.modelData.width - content.width) / 2;
        content.y = Style.lyricsTop;
        content.userScale = 1;
        content.userRotation = 0;
    }

    Component.onCompleted: resetLayout()

    Connections {
        target: MusicLyricsService
        function onResetLayoutRequested() {
            root.resetLayout();
        }
    }

    Item {
        id: content

        property real userScale: 1
        property real userRotation: 0

        width: Math.min(Style.lyricsWidth, root.modelData.width - Style.panelPadding * 2)
        height: Style.lyricsHeight

        transform: [
            Scale {
                origin.x: content.width / 2
                origin.y: content.height / 2
                xScale: content.userScale
                yScale: content.userScale
            },
            Rotation {
                origin.x: content.width / 2
                origin.y: content.height / 2
                angle: content.userRotation
            }
        ]

        DragHandler {
            target: content
            enabled: root.interactive
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            opacity: MusicLyricsService.shouldShowLyrics || root.interactive ? 1 : 0

            Behavior on opacity {
                NumberMotion {
                    duration: Style.durMedium1
                }
            }

            ListView {
                id: lyricsView

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                spacing: Style.listGap

                model: MusicLyricsService.parsedSyncedLyrics
                clip: true
                currentIndex: MusicLyricsService.currentLyricIndex
                preferredHighlightBegin: Math.round(height * 0.3)
                preferredHighlightEnd: Math.round(height * 0.3)
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: Style.durMedium4

                delegate: Column {
                    id: lyricLine

                    required property int index

                    readonly property int offset: index - lyricsView.currentIndex
                    readonly property string translation: offset === 0 ? LyricsTextService.translationFor(index) : ""

                    width: lyricsView.width
                    spacing: Style.listGap
                    opacity: offset === 0 ? 1 : offset === 1 ? 0.7 : offset === 2 ? 0.4 : 0

                    Behavior on opacity {
                        NumberMotion {
                            duration: Style.durMedium4
                        }
                    }

                    Label {
                        width: lyricsView.width
                        text: LyricsTextService.displayLine(lyricLine.index)
                        role: "headlineSmall"
                        font.weight: lyricLine.offset === 0 ? Font.Bold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                        color: lyricLine.offset === 2 ? Theme.inkSurfaceVariant : Theme.inkSurface
                    }

                    Label {
                        width: lyricsView.width
                        visible: lyricLine.translation !== ""
                        text: lyricLine.translation
                        role: "titleMedium"
                        font.italic: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                        color: Theme.inkSurfaceVariant
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.interactive
                color: "transparent"
                radius: Style.radiusM
                border.width: Style.borderWidth
                border.color: Theme.primary
            }

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: -Style.iconBox
                visible: root.interactive
                text: Icons.dragIndicator
                color: Theme.primary
                font.pixelSize: Style.iconSizeXl
            }
        }

        Item {
            id: resizeHandle

            visible: root.interactive
            width: Style.iconBox
            height: Style.iconBox
            x: content.width - width / 2
            y: content.height - height / 2

            Surface {
                anchors.fill: parent
                level: 2
                radius: Style.radiusFull

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Icons.resize
                    color: Theme.primary
                    font.pixelSize: Style.iconSize
                }
            }

            DragHandler {
                id: resizeDrag
                target: null
                enabled: root.interactive

                property real startScale: 1

                onActiveChanged: if (active)
                    startScale = content.userScale

                onTranslationChanged: {
                    const delta = (translation.x + translation.y) / Style.lyricsHeight;
                    content.userScale = Math.max(Style.lyricsMinScale, Math.min(Style.lyricsMaxScale, startScale + delta));
                }
            }
        }

        Item {
            id: rotateHandle

            visible: root.interactive
            width: Style.iconBox
            height: Style.iconBox
            x: content.width - width / 2
            y: -height / 2

            Surface {
                anchors.fill: parent
                level: 2
                radius: Style.radiusFull

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Icons.rotate
                    color: Theme.primary
                    font.pixelSize: Style.iconSize
                }
            }

            DragHandler {
                id: rotateDrag
                target: null
                enabled: root.interactive

                property real startAngle: 0
                property real startRotation: 0

                function angleToCenter() {
                    const centre = content.mapToItem(null, content.width / 2, content.height / 2);
                    const pointer = centroid.scenePosition;
                    return Math.atan2(pointer.y - centre.y, pointer.x - centre.x) * 180 / Math.PI;
                }

                onActiveChanged: {
                    if (active) {
                        startRotation = content.userRotation;
                        startAngle = angleToCenter();
                    }
                }

                onTranslationChanged: {
                    content.userRotation = startRotation + (angleToCenter() - startAngle);
                }
            }
        }
    }
}
