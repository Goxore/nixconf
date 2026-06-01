import QtQuick 2.15
import Quickshell
import Quickshell.Wayland
import "./services"

ShellRoot {
    Component.onCompleted: {
        MusicLyricsService.visible = true;
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            WlrLayershell.layer: WlrLayer.Overlay
            aboveWindows: true
            mask: Region {
                item: rect
            }

            Rectangle {
                id: rect

                anchors.centerIn: parent
                width: 0
                height: 0
            }

            width: 1200
            height: 200
            anchors.top: true
            exclusiveZone: 0
            color: "#00000000"

            Rectangle {
                anchors.fill: parent
                color: "#00000000"
                opacity: MusicLyricsService.shouldShowLyrics ? 1 : 0

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
                                return "white";
                            if (offset === 1)
                                return "#CCCCCC";
                            if (offset === 2)
                                return "#888888";
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
            }
        }
    }
}
