import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

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

    implicitWidth: 1200
    implicitHeight: 200
    anchors.top: true
    exclusiveZone: 0
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        opacity: MusicLyricsService.shouldShowLyrics ? 1 : 0

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
    }
}
