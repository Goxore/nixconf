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

    readonly property bool interactive: PanelService.isOpen("lyricsControl")

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
        x: content.x - Style.iconBox
        y: content.y - Style.iconBox
        width: content.width + Style.iconBox * 2
        height: content.height + Style.iconBox * 2
    }

    function resetLayout() {
        content.x = (root.modelData.width - content.width) / 2;
        content.y = 24;
        content.userScale = 1.0;
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

        width: 1200
        height: 200

        property real userScale: 1.0
        property real userRotation: 0

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
                NumberAnimation {
                    duration: Style.durMedium1
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Style.standard
                }
            }

            ListView {
                id: lyricsView

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 200

                spacing: 2

                model: MusicLyricsService.parsedSyncedLyrics
                clip: true
                currentIndex: MusicLyricsService.currentLyricIndex
                preferredHighlightBegin: height / 2
                preferredHighlightEnd: height / 2
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 400

                delegate: Text {
                    text: modelData.text
                    font.pixelSize: 26
                    height: 29
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: lyricsView.width

                    property int offset: index - lyricsView.currentIndex

                    color: {
                        if (offset === 0)
                            return Theme.textBright;
                        if (offset === 1)
                            return Theme.text;
                        if (offset === 2)
                            return Theme.textDim;
                        return "transparent";
                    }

                    font.bold: offset === 0

                    opacity: {
                        if (offset === 0)
                            return 1.0;
                        if (offset === 1)
                            return 0.7;
                        if (offset === 2)
                            return 0.4;
                        return 0.0;
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                        }
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        lyricsView.positionViewAtIndex(currentIndex, ListView.Center);
                    }
                }

                Behavior on contentY {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.interactive
                color: "transparent"
                radius: Style.radiusM
                border.width: Style.borderWidth
                border.color: Theme.accent
            }

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: -Style.iconBox
                visible: root.interactive
                text: Icons.dragIndicator
                color: Theme.accent
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
                    color: Theme.accent
                    font.pixelSize: Style.iconSize
                }
            }

            DragHandler {
                id: resizeDrag
                target: null
                enabled: root.interactive

                property real startScale: 1.0

                onActiveChanged: if (active)
                    startScale = content.userScale

                onTranslationChanged: {
                    const delta = (translation.x + translation.y) / 200;
                    content.userScale = Math.max(0.4, Math.min(3.0, startScale + delta));
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
                    color: Theme.accent
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
                    const px = rotateHandle.x + centroid.position.x;
                    const py = rotateHandle.y + centroid.position.y;
                    return Math.atan2(py - content.height / 2, px - content.width / 2) * 180 / Math.PI;
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
